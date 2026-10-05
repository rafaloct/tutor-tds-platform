function Get-CanonicalAlembicHead {
    [CmdletBinding()]
    param(
        [string]$MigrationRoot,
        [string[]]$MigrationDefinitions
    )
    if ($null -eq $MigrationDefinitions) {
        if ([string]::IsNullOrWhiteSpace($MigrationRoot)) {
            $workspace = Split-Path $PSScriptRoot -Parent
            $MigrationRoot = Join-Path $workspace 'api/migrations/versions'
        }
        if (-not (Test-Path -LiteralPath $MigrationRoot -PathType Container)) {
            throw 'diretório de migrations Alembic ausente.'
        }
        $MigrationDefinitions = @(Get-ChildItem -LiteralPath $MigrationRoot -Filter '*.py' -File |
            Sort-Object Name | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw })
    }
    if (@($MigrationDefinitions).Count -eq 0) { throw 'nenhuma migration Alembic encontrada.' }
    $revisions = @{}
    $parents = @{}
    foreach ($definition in @($MigrationDefinitions)) {
        if ($definition -notmatch '(?m)^revision\s*=\s*["'']([A-Za-z0-9][A-Za-z0-9_-]*)["'']\s*$') {
            throw 'migration sem revision Alembic simples e válida.'
        }
        $revision = $Matches[1]
        if ($revisions.ContainsKey($revision)) { throw 'revision Alembic duplicada.' }
        $revisions[$revision] = $true
        if ($definition -match '(?m)^down_revision\s*=\s*["'']([A-Za-z0-9][A-Za-z0-9_-]*)["'']\s*$') {
            $parents[$Matches[1]] = $true
        } elseif ($definition -notmatch '(?m)^down_revision\s*=\s*None\s*$') {
            throw 'down_revision Alembic não suportada; gate falha fechado.'
        }
    }
    foreach ($parent in $parents.Keys) {
        if (-not $revisions.ContainsKey($parent)) { throw 'down_revision Alembic inexistente.' }
    }
    $heads = @($revisions.Keys | Where-Object { -not $parents.ContainsKey($_) })
    if ($heads.Count -ne 1) { throw 'exatamente um HEAD Alembic local é obrigatório.' }
    return [string]$heads[0]
}

function Get-RequiredVersionProperty {
    param([Parameter(Mandatory = $true)][object]$Response, [Parameter(Mandatory = $true)][string]$Name)
    $property = $Response.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "identidade /version sem campo obrigatório '$Name'." }
    return ,$property.Value
}

function ConvertTo-FlutterVersion {
    param([Parameter(Mandatory = $true)][string]$Value, [Parameter(Mandatory = $true)][string]$Field)
    if ($Value -cnotmatch '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:\+(?<build>0|[1-9]\d*))?$') {
        throw "$Field deve usar a identidade Flutter MAJOR.MINOR.PATCH, com +BUILD numérico opcional."
    }
    $build = if ($Matches.ContainsKey('build')) { [long]$Matches.build } else { $null }
    return [pscustomobject]@{ Major = [long]$Matches.major; Minor = [long]$Matches.minor; Patch = [long]$Matches.patch; Build = $build }
}

function Assert-ProductionBackendIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$VersionResponse,
        [Parameter(Mandatory = $true)][string]$ExpectedSchemaVersion,
        [Parameter(Mandatory = $true)][string]$CandidateVersionName,
        [Parameter(Mandatory = $true)][long]$CandidateVersionCode
    )
    Set-StrictMode -Version Latest
    if ($null -eq $VersionResponse) { throw 'identidade /version ausente.' }
    if ($ExpectedSchemaVersion -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'HEAD Alembic local inválido.' }
    if ($CandidateVersionCode -lt 1) { throw 'versionCode candidato inválido.' }
    $environment = Get-RequiredVersionProperty $VersionResponse 'environment'
    if ($environment -isnot [string] -or $environment -cne 'production') { throw 'environment de /version deve ser a string production.' }
    $compatibility = Get-RequiredVersionProperty $VersionResponse 'compatibility_verified'
    if ($compatibility -isnot [bool] -or $compatibility -ne $true) { throw 'compatibility_verified de /version deve ser o booleano true.' }
    $apiVersion = Get-RequiredVersionProperty $VersionResponse 'api_version'
    if ($apiVersion -isnot [string] -or $apiVersion -cnotmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?(?:\+[0-9A-Za-z][0-9A-Za-z.-]*)?$') { throw 'api_version de /version é inválida.' }
    $schemaVersion = Get-RequiredVersionProperty $VersionResponse 'schema_version'
    if ($schemaVersion -isnot [string] -or $schemaVersion -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'schema_version de /version é inválida.' }
    if ($schemaVersion -cne $ExpectedSchemaVersion) { throw 'revision de produção diverge do HEAD Alembic.' }
    $minimum = Get-RequiredVersionProperty $VersionResponse 'minimum_supported_app_version'
    if ($minimum -isnot [string]) { throw 'minimum_supported_app_version de /version é inválida.' }
    $minimumVersion = ConvertTo-FlutterVersion $minimum 'minimum_supported_app_version'
    $candidateVersion = ConvertTo-FlutterVersion $CandidateVersionName 'versionName candidato'
    if ($null -ne $candidateVersion.Build -and $candidateVersion.Build -ne $CandidateVersionCode) { throw 'build em versionName diverge de versionCode.' }
    foreach ($part in 'Major', 'Minor', 'Patch') {
        if ($candidateVersion.$part -lt $minimumVersion.$part) { throw 'app candidata é anterior a minimum_supported_app_version.' }
        if ($candidateVersion.$part -gt $minimumVersion.$part) { break }
    }
    # Android build codes are monotonic, even across different semantic versions.
    if ($null -ne $minimumVersion.Build -and $CandidateVersionCode -lt $minimumVersion.Build) { throw 'versionCode candidato é anterior ao build mínimo declarado.' }
    return $true
}
