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
}

Invoke-GateCase -Name 'debug aceita staging aprovado' `
    -Task ':app:preDebugBuild' -Defines $staging -ShouldPass $true
Invoke-GateCase -Name 'debug rejeita producao' `
    -Task ':app:preDebugBuild' -Defines $production -ShouldPass $false
Invoke-GateCase -Name 'release aceita producao aprovada' `
    -Task ':app:preReleaseBuild' -Defines $production -ShouldPass $true
Invoke-GateCase -Name 'release rejeita staging' `
    -Task ':app:preReleaseBuild' -Defines $staging -ShouldPass $false
Invoke-GateCase -Name 'release rejeita configuracao vazia' `
    -Task ':app:preReleaseBuild' -Defines ([ordered]@{}) -ShouldPass $false

$wrongGateway = [ordered]@{}
foreach ($entry in $production.GetEnumerator()) {
    $wrongGateway[$entry.Key] = $entry.Value
}
$wrongGateway.TUTOR_GATEWAY_URL = 'https://staging.example.invalid/gateway'
Invoke-GateCase -Name 'release rejeita gateway nao aprovado' `
    -Task ':app:preReleaseBuild' -Defines $wrongGateway -ShouldPass $false

Write-Output 'Matriz de ambiente Android aprovada; nenhum APK ou AAB foi gerado.'
