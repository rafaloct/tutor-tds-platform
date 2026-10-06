param(
    [Parameter(Mandatory = $true)][string]$Flutter,
    [Parameter(Mandatory = $true)][int]$PublishedVersionCode,
    [switch]$PreflightOnly
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$appRoot = Join-Path $workspace 'cartilhas_app'
$apiRoot = Join-Path $workspace 'api'
$expectedApi = 'https://ead.ipexdesenvolvimento.cloud/tutor-api'
. (Join-Path $PSScriptRoot 'Test-ProductionBackendIdentity.ps1')
. (Join-Path $PSScriptRoot 'Test-ProductionRecoveryEvidence.ps1')

function Require([bool]$Condition, [string]$Reason) {
    if (-not $Condition) { throw "PRODUCTION_RELEASE_READY=false: $Reason" }
}
function Run([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "PRODUCTION_RELEASE_READY=false: gate $Program falhou ($LASTEXITCODE)." }
}

Push-Location $workspace
try {
    Require (Test-Path -LiteralPath (Join-Path $appRoot 'config/production.json')) 'configuração de produção ausente.'
    Require (Test-Path -LiteralPath $Flutter) 'Flutter SDK explícito não encontrado.'
    $dart = Join-Path (Split-Path $Flutter) 'dart.bat'
    Require (Test-Path -LiteralPath $dart) 'Dart do mesmo SDK não encontrado.'
    Push-Location $appRoot
    try {
        Run $dart @('tool/validate_production_config.dart', 'config/production.json')
        Run $dart @('tool/verify_release_readiness.dart', '--intent=build')
        $config = Get-Content -LiteralPath 'config/production.json' -Raw | ConvertFrom-Json
        $status = Get-Content -LiteralPath 'release/release_status.json' -Raw | ConvertFrom-Json
    } finally { Pop-Location }
    Require ($PublishedVersionCode -gt 0 -and $status.release.version_code -gt $PublishedVersionCode) 'versionCode não excede versão publicada comprovada.'
    $forbiddenLiteral = '(?i)(https?://(?:localhost|127\.0\.0\.1|10\.0\.2\.2|[a-z0-9.-]+\.local)(?:[:/]|$)|tutor-tds-staging\.fastapicloud\.dev|lgtphbbpgqnzduhtyate|/tutor-staging-api)'
    $unsafeSources = @(Get-ChildItem -Path (Join-Path $appRoot 'lib'), (Join-Path $appRoot 'assets/data') -Recurse -File |
        Where-Object { Select-String -LiteralPath $_.FullName -Pattern $forbiddenLiteral -Quiet })
    Require ($unsafeSources.Count -eq 0) 'fonte/asset compilável contém endpoint local ou staging.'
    $commit = (& git rev-parse HEAD).Trim()
    Require ($LASTEXITCODE -eq 0 -and $commit -match '^[a-f0-9]{40}$') 'commit não identificado.'
    $branch = (& git branch --show-current).Trim()
    Require ($LASTEXITCODE -eq 0 -and $branch) 'branch não identificada.'
    $dirty = @(& git status --porcelain=v1 -uall)
    Require ($LASTEXITCODE -eq 0 -and $dirty.Count -eq 0) 'working tree de release não está limpa.'
    $tags = @(& git tag --points-at HEAD)
    Require ($LASTEXITCODE -eq 0 -and $tags.Count -eq 1) 'exatamente uma tag de release deve apontar ao HEAD.'
    $origin = (& git remote get-url origin).Trim()
    Require ($LASTEXITCODE -eq 0 -and ($origin -match '^https://github\.com/[^@]+$' -or $origin -match '^git@github\.com:[^@]+$')) 'origin GitHub autenticável e sem credenciais na URL é obrigatório.'
    $remote = @(& git ls-remote --heads origin $branch)
    Require ($LASTEXITCODE -eq 0 -and $remote.Count -eq 1 -and ($remote[0] -split '\s+')[0] -eq $commit) 'branch remota diverge do commit local.'
    $remoteTags = @(& git ls-remote --tags origin "refs/tags/$($tags[0])" "refs/tags/$($tags[0])^{}")
    Require ($LASTEXITCODE -eq 0 -and @($remoteTags | Where-Object { ($_ -split '\s+')[0] -eq $commit }).Count -ge 1) 'tag de release ainda não está no GitHub.'
    $restorePath = Join-Path $workspace 'docs/production/evidence/production-restore-acceptance.json'
    Require (Test-Path -LiteralPath $restorePath) 'backup/restauração de produção não comprovados.'
    $proof = Get-Content -LiteralPath $restorePath -Raw | ConvertFrom-Json
    try { Assert-ProductionRecoveryEvidence $proof | Out-Null }
    catch { throw 'PRODUCTION_RELEASE_READY=false: prova de recuperação/compatibilidade incompleta.' }
    $health = Invoke-RestMethod -Uri "$expectedApi/health" -TimeoutSec 15
    Require ($health.status -eq 'ok' -and $health.database -eq 'available') 'health de produção sem banco disponível.'
    $version = Invoke-RestMethod -Uri "$expectedApi/version" -TimeoutSec 15
    Require ($version.environment -eq 'production' -and $version.schema_version -and
        $version.minimum_supported_app_version -and $version.compatibility_verified -eq $true) 'versão/schema/compatibilidade da API de produção não comprovados.'
    Require ($version.api_version -and $config.TUTOR_API_URL -eq $expectedApi) 'proveniência da API de produção divergente.'
    $localSchema = Get-CanonicalAlembicHead
    Require ($version.schema_version -eq $localSchema) 'revision de produção diverge do HEAD Alembic.'
    try {
        Assert-ProductionBackendIdentity -VersionResponse $version -ExpectedSchemaVersion $localSchema `
            -CandidateVersionName $status.release.version_name -CandidateVersionCode $status.release.version_code | Out-Null
    } catch {
        throw ('PRODUCTION_RELEASE_READY=false: ' + $_.Exception.Message)
    }
    $flutterVersion = & $Flutter --version --machine | ConvertFrom-Json
    Require ($LASTEXITCODE -eq 0 -and $flutterVersion.frameworkVersion -eq '3.44.9') 'Flutter SDK diferente do validado.'
    if ($PreflightOnly) {
        Write-Output 'Preflight de produção PASS; nenhum AAB foi criado.'
        return
    }
    Push-Location $apiRoot
    try { Run 'uv' @('run', '--locked', 'pytest', '-q') } finally { Pop-Location }
    Push-Location $appRoot
    try {
        Run $Flutter @('analyze', '--no-pub')
        Run $Flutter @('test', '--no-pub')
        Run $Flutter @('build', 'appbundle', '--release', '--no-pub', '--dart-define-from-file=config/production.json')
        $artifact = Join-Path $appRoot 'build/app/outputs/bundle/release/app-release.aab'
        Require (Test-Path -LiteralPath $artifact) 'AAB não encontrado após build.'
        $manifest = [ordered]@{
            versionName = $status.release.version_name
            versionCode = $status.release.version_code
            git_commit = $commit
            git_tag = $tags[0]
            build_timestamp = (Get-Date).ToUniversalTime().ToString('o')
            environment = 'production'
            api_base_url = $expectedApi
            remote_catalog_enabled = $config.REMOTE_CATALOG_ENABLED
            learning_context_enabled = $config.LEARNING_CONTEXT_ENABLED
            journey_enabled = $config.JOURNEY_TRACEABILITY_ENABLED
            backend_api_version = $version.api_version
            backend_schema_version = $version.schema_version
            aab_sha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
        }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath 'release/build-manifest.json' -Encoding UTF8
        Write-Output 'AAB e manifesto gerados localmente; nenhum upload/deploy foi efetuado.'
    } finally { Pop-Location }
} finally { Pop-Location }
