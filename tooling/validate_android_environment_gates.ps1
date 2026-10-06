[CmdletBinding()]
param(
    [string]$WorkspaceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = Split-Path -Parent $PSScriptRoot
}

$androidRoot = Join-Path $WorkspaceRoot 'cartilhas_app\android'
$gradleWrapper = Join-Path $androidRoot 'gradlew.bat'
if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    throw "Gradle wrapper nao encontrado em: $gradleWrapper"
}

function ConvertTo-DartDefines {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Values)

    $encoded = foreach ($entry in $Values.GetEnumerator()) {
        $plain = '{0}={1}' -f $entry.Key, $entry.Value
        [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($plain))
    }
    return $encoded -join ','
}

function Invoke-GateCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Task,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Defines,
        [Parameter(Mandatory)][bool]$ShouldPass
    )

    $dartDefines = ConvertTo-DartDefines -Values $Defines
    Push-Location $androidRoot
    try {
        # stderr do JVM/Gradle (warnings) nao pode virar NativeCommandError
        # em Windows PowerShell 5.1; o gate e avaliado somente pelo exit code.
        $ErrorActionPreference = 'Continue'
        $output = & $gradleWrapper $Task --no-daemon --console=plain -q `
            "-Pdart-defines=$dartDefines" 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    $passed = $exitCode -eq 0
    if ($passed -ne $ShouldPass) {
        $result = if ($passed) { 'passou' } else { 'falhou' }
        $expected = if ($ShouldPass) { 'passar' } else { 'falhar' }
        throw "Caso '$Name' $result, mas deveria $expected.`n$($output -join "`n")"
    }
    Write-Output ("OK {0}: {1}" -f $Name, $(if ($passed) { 'aceito' } else { 'bloqueado' }))
}

$staging = [ordered]@{
    TUTOR_ENVIRONMENT = 'staging'
    TUTOR_STAGING_API_URL = 'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api'
    TUTOR_API_URL = 'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api'
    TUTOR_STAGING_GATEWAY_URL = ''
    TUTOR_GATEWAY_URL = ''
    PRIVACY_POLICY_URL = 'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html'
    ACCOUNT_DELETION_URL = 'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html'
}
$production = [ordered]@{
    TUTOR_ENVIRONMENT = 'production'
    TUTOR_API_URL = 'https://ead.ipexdesenvolvimento.cloud/tutor-api'
    TUTOR_GATEWAY_URL = 'https://tutor-tds-gateway.tdsipex.workers.dev'
    PRIVACY_POLICY_URL = 'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html'
    ACCOUNT_DELETION_URL = 'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html'
    REMOTE_CATALOG_ENABLED = 'false'
    LEARNING_CONTEXT_ENABLED = 'false'
    DURABLE_LEARNING_OUTBOX_ENABLED = 'false'
    JOURNEY_TRACEABILITY_ENABLED = 'false'
    SIGNED_SUPPORT_IDENTITY = 'false'
    PUSH_NOTIFICATIONS_ENABLED = 'false'
}

Invoke-GateCase -Name 'debug aceita staging aprovado' `
    -Task ':app:preDebugBuild' -Defines $staging -ShouldPass $true
$cloudStaging = [ordered]@{}
foreach ($entry in $staging.GetEnumerator()) {
    $cloudStaging[$entry.Key] = $entry.Value
}
$cloudStaging.TUTOR_API_URL = 'https://tutor-tds-staging.fastapicloud.dev'
$cloudStaging.TUTOR_STAGING_API_URL = $cloudStaging.TUTOR_API_URL
Invoke-GateCase -Name 'debug aceita app Cloud staging aprovado' `
    -Task ':app:preDebugBuild' -Defines $cloudStaging -ShouldPass $true

$isolated = [ordered]@{}
foreach ($entry in $cloudStaging.GetEnumerator()) { $isolated[$entry.Key] = $entry.Value }
$isolated.DYNAMIC_QA_ISOLATED_PACKAGE = 'true'
$isolated.DYNAMIC_QA_RUN_ID = '11111111111111111111111111111111'
Invoke-GateCase -Name 'debug aceita QA fisico isolado' `
    -Task ':app:preDebugBuild' -Defines $isolated -ShouldPass $true
$isolated.DYNAMIC_QA_RUN_ID = 'invalid'
Invoke-GateCase -Name 'debug rejeita QA isolado sem run valido' `
    -Task ':app:preDebugBuild' -Defines $isolated -ShouldPass $false
$isolated.DYNAMIC_QA_RUN_ID = '11111111111111111111111111111111'
$isolated.TUTOR_API_URL = $staging.TUTOR_API_URL
$isolated.TUTOR_STAGING_API_URL = $staging.TUTOR_API_URL
Invoke-GateCase -Name 'debug rejeita QA isolado fora do Cloud autorizado' `
    -Task ':app:preDebugBuild' -Defines $isolated -ShouldPass $false

$unapproved = [ordered]@{}
foreach ($entry in $cloudStaging.GetEnumerator()) {
    $unapproved[$entry.Key] = $entry.Value
}
$unapproved.TUTOR_API_URL = 'https://other-staging.fastapicloud.dev'
$unapproved.TUTOR_STAGING_API_URL = $unapproved.TUTOR_API_URL
Invoke-GateCase -Name 'debug rejeita outro app no mesmo provedor' `
    -Task ':app:preDebugBuild' -Defines $unapproved -ShouldPass $false
$unapproved.TUTOR_API_URL = 'http://tutor-tds-staging.fastapicloud.dev'
$unapproved.TUTOR_STAGING_API_URL = $unapproved.TUTOR_API_URL
Invoke-GateCase -Name 'debug rejeita Cloud sem HTTPS' `
    -Task ':app:preDebugBuild' -Defines $unapproved -ShouldPass $false
$unapproved.TUTOR_API_URL = $cloudStaging.TUTOR_API_URL
$unapproved.TUTOR_STAGING_API_URL = $staging.TUTOR_API_URL
Invoke-GateCase -Name 'debug rejeita bases staging divergentes' `
    -Task ':app:preDebugBuild' -Defines $unapproved -ShouldPass $false
Invoke-GateCase -Name 'debug rejeita producao' `
    -Task ':app:preDebugBuild' -Defines $production -ShouldPass $false
$releaseStatusPath = Join-Path $WorkspaceRoot 'cartilhas_app\release\release_status.json'
$releaseStatus = Get-Content -LiteralPath $releaseStatusPath -Raw | ConvertFrom-Json
Invoke-GateCase -Name 'release respeita congelamento com configuracao produtiva' `
    -Task ':app:preReleaseBuild' -Defines $production `
    -ShouldPass ($releaseStatus.release_build_allowed -eq $true)
Invoke-GateCase -Name 'release rejeita staging' `
    -Task ':app:preReleaseBuild' -Defines $staging -ShouldPass $false
Invoke-GateCase -Name 'release rejeita Cloud staging' `
    -Task ':app:preReleaseBuild' -Defines $cloudStaging -ShouldPass $false
Invoke-GateCase -Name 'release rejeita configuracao vazia' `
    -Task ':app:preReleaseBuild' -Defines ([ordered]@{}) -ShouldPass $false

$wrongGateway = [ordered]@{}
foreach ($entry in $production.GetEnumerator()) {
    $wrongGateway[$entry.Key] = $entry.Value
}
$wrongGateway.TUTOR_GATEWAY_URL = 'https://staging.example.invalid/gateway'
Invoke-GateCase -Name 'release rejeita gateway nao aprovado' `
    -Task ':app:preReleaseBuild' -Defines $wrongGateway -ShouldPass $false

$withFlutterMeta = [ordered]@{}
foreach ($entry in $production.GetEnumerator()) {
    $withFlutterMeta[$entry.Key] = $entry.Value
}
$withFlutterMeta.FLUTTER_VERSION = '3.44.9'
$withFlutterMeta.FLUTTER_CHANNEL = '[user-branch]'
$withFlutterMeta.FLUTTER_GIT_URL = 'unknown source'
$withFlutterMeta.FLUTTER_FRAMEWORK_REVISION = '6b182d2c75'
$withFlutterMeta.FLUTTER_ENGINE_REVISION = '5a2a6a42cc'
$withFlutterMeta.FLUTTER_DART_VERSION = '3.12.2'
Invoke-GateCase -Name 'release aceita metadata do toolchain Flutter' `
    -Task ':app:preReleaseBuild' -Defines $withFlutterMeta `
    -ShouldPass ($releaseStatus.release_build_allowed -eq $true)

$unknownDefine = [ordered]@{}
foreach ($entry in $withFlutterMeta.GetEnumerator()) {
    $unknownDefine[$entry.Key] = $entry.Value
}
$unknownDefine.UNAPPROVED_RELEASE_FLAG = 'true'
Invoke-GateCase -Name 'release rejeita define desconhecido mesmo com metadata Flutter' `
    -Task ':app:preReleaseBuild' -Defines $unknownDefine -ShouldPass $false

$enabledInactiveFlag = [ordered]@{}
foreach ($entry in $withFlutterMeta.GetEnumerator()) {
    $enabledInactiveFlag[$entry.Key] = $entry.Value
}
$enabledInactiveFlag.PUSH_NOTIFICATIONS_ENABLED = 'true'
Invoke-GateCase -Name 'release rejeita flag inativa habilitada' `
    -Task ':app:preReleaseBuild' -Defines $enabledInactiveFlag -ShouldPass $false

Write-Output 'Matriz de ambiente Android aprovada; nenhum APK ou AAB foi gerado.'
# The last case intentionally fails Gradle. Do not leak that expected rejection
# as the validation script's status to its caller.
$global:LASTEXITCODE = 0
