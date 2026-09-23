[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$StagingConfigPath,
    [string]$Serial,
    [string]$FlutterPath = 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat',
    [string]$AndroidSdkPath,
    [switch]$BuildOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HttpsUri {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw "$Name deve ser uma URL HTTPS valida."
    }
    if ($uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host)) {
        throw "$Name deve ser uma URL HTTPS valida."
    }
    if (-not [string]::IsNullOrWhiteSpace($uri.UserInfo) -or $uri.Query -or $uri.Fragment) {
        throw "$Name nao pode conter credencial, query ou fragmento."
    }
    return $uri
}

function Assert-StagingConfig {
    param([Parameter(Mandatory)]$Config)

    if ($Config.TUTOR_ENVIRONMENT -ne 'staging') {
        throw 'TUTOR_ENVIRONMENT deve ser staging.'
    }

    $apiUri = Get-HttpsUri -Name 'TUTOR_API_URL' -Value ([string]$Config.TUTOR_API_URL)
    $allowedApiUri = Get-HttpsUri `
        -Name 'TUTOR_STAGING_API_URL' `
        -Value ([string]$Config.TUTOR_STAGING_API_URL)
    $approvedApiUrls = @(
        'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api',
        'https://tutor-tds-staging.fastapicloud.dev'
    )
    if (
        $apiUri.AbsoluteUri.TrimEnd('/') -ne $allowedApiUri.AbsoluteUri.TrimEnd('/') -or
        $apiUri.AbsoluteUri.TrimEnd('/') -notin $approvedApiUrls
    ) {
        throw 'TUTOR_API_URL deve ser uma rota de staging aprovada.'
    }

    $gatewayUrl = [string]$Config.TUTOR_GATEWAY_URL
    if (-not [string]::IsNullOrWhiteSpace($gatewayUrl)) {
        $gatewayUri = Get-HttpsUri -Name 'TUTOR_GATEWAY_URL' -Value $gatewayUrl
        $allowedGatewayUri = Get-HttpsUri `
            -Name 'TUTOR_STAGING_GATEWAY_URL' `
            -Value ([string]$Config.TUTOR_STAGING_GATEWAY_URL)
        if (
            $gatewayUri.AbsoluteUri.TrimEnd('/') -ne $allowedGatewayUri.AbsoluteUri.TrimEnd('/') -or
            $gatewayUri.AbsolutePath.ToLowerInvariant() -notmatch 'staging'
        ) {
            throw 'TUTOR_GATEWAY_URL deve usar staging aprovado ou ficar vazio.'
        }
    }
}

$resolvedConfig = Resolve-Path -LiteralPath $StagingConfigPath
if ($resolvedConfig.Path.EndsWith('.example.json', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Nao use o arquivo example. Crie uma copia temporaria com o host de staging aprovado.'
}
$config = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
Assert-StagingConfig -Config $config

if (-not (Test-Path -LiteralPath $FlutterPath)) {
    throw "Flutter nao encontrado em: $FlutterPath"
}
if (-not $AndroidSdkPath) {
    $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android\sdk'
}
$adbPath = Join-Path $AndroidSdkPath 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "ADB nao encontrado em: $adbPath"
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $workspaceRoot 'cartilhas_app'
$configArgumentPath = [IO.Path]::GetRelativePath($appRoot, $resolvedConfig.Path)
if ($configArgumentPath.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)) {
    $configArgumentPath = $resolvedConfig.Path
}

Push-Location $appRoot
try {
    # Flutter/Gradle on Windows can misparse an absolute path when a parent
    # directory contains parentheses. Prefer a path relative to the app root.
    & $FlutterPath build apk --debug "--dart-define-from-file=$configArgumentPath"
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao gerar o APK debug.'
    }
} finally {
    Pop-Location
}

$apkPath = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK nao encontrado em: $apkPath"
}

$buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
$aapt2Path = Join-Path $buildTools.FullName 'aapt2.exe'
$apksignerPath = Join-Path $buildTools.FullName 'apksigner.bat'
if (-not (Test-Path -LiteralPath $aapt2Path) -or -not (Test-Path -LiteralPath $apksignerPath)) {
    throw 'aapt2/apksigner nao encontrados no Android SDK.'
}

$badging = & $aapt2Path dump badging $apkPath
if ($LASTEXITCODE -ne 0) {
    throw 'Nao foi possivel inspecionar o APK.'
}
$badgingText = $badging -join "`n"
if ($badgingText -notmatch "package: name='com\.tutortds_cartilhas\.dev'") {
    throw 'Instalacao bloqueada: applicationId nao e com.tutortds_cartilhas.dev.'
}
if ($badgingText -notmatch "application-label:'Tutor TDS DEV'") {
    throw 'Instalacao bloqueada: rotulo DEV nao foi encontrado.'
}

& $apksignerPath verify --verbose $apkPath
if ($LASTEXITCODE -ne 0) {
    throw 'Instalacao bloqueada: assinatura APK invalida.'
}

$hash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
Write-Output "APK validado: $apkPath"
Write-Output 'Pacote: com.tutortds_cartilhas.dev'
Write-Output 'Rotulo: Tutor TDS DEV'
Write-Output "SHA256: $hash"

if ($BuildOnly) {
    Write-Output 'BuildOnly ativo; nenhuma instalacao foi executada.'
    exit 0
}

$stagingApiUri = Get-HttpsUri `
    -Name 'TUTOR_API_URL' `
    -Value ([string]$config.TUTOR_API_URL)
$healthUri = $stagingApiUri.AbsoluteUri.TrimEnd('/') + '/health'
try {
    $health = Invoke-RestMethod -Method Get -Uri $healthUri -TimeoutSec 15
} catch {
    throw "Instalacao bloqueada: health HTTPS de staging indisponivel em $healthUri"
}
if (
    $health.PSObject.Properties.Name -notcontains 'status' -or
    $health.status -notin @('ok', 'healthy')
) {
    throw "Instalacao bloqueada: staging retornou status de health inesperado."
}
if (
    $health.PSObject.Properties.Name -contains 'database' -and
    $health.database -notin @('ok', 'healthy', 'available')
) {
    throw 'Instalacao bloqueada: banco de staging nao esta saudavel.'
}
Write-Output "Health de staging aprovado: $healthUri"

$deviceLines = @(
    & $adbPath devices -l |
        Where-Object { $_ -match '^\S+\s+device(?:\s|$)' }
)
if (-not $Serial) {
    if ($deviceLines.Count -ne 1) {
        throw 'Informe -Serial quando nao houver exatamente um dispositivo ADB autorizado.'
    }
    $Serial = (($deviceLines[0] -split '\s+')[0]).Trim()
}
if (-not ($deviceLines | Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+device(?:\s|$)" })) {
    throw "Dispositivo autorizado nao encontrado: $Serial"
}

$playBefore = & $adbPath -s $Serial shell dumpsys package com.tutortds_cartilhas |
    Select-String -Pattern 'versionName=|versionCode=|lastUpdateTime='
& $adbPath -s $Serial install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao instalar o pacote DEV.'
}
$devAfter = & $adbPath -s $Serial shell dumpsys package com.tutortds_cartilhas.dev |
    Select-String -Pattern 'versionName=|versionCode=|lastUpdateTime='
$playAfter = & $adbPath -s $Serial shell dumpsys package com.tutortds_cartilhas |
    Select-String -Pattern 'versionName=|versionCode=|lastUpdateTime='

if (($playBefore -join "`n") -ne ($playAfter -join "`n")) {
    throw 'O pacote Play mudou inesperadamente; interrompa o QA e investigue.'
}

Write-Output 'Pacote DEV instalado sem iniciar o aplicativo.'
Write-Output $devAfter
Write-Output 'Pacote Play preservado:'
Write-Output $playAfter
