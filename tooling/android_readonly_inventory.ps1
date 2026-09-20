[CmdletBinding()]
param(
    [string]$Serial,
    [string]$AndroidSdkPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $AndroidSdkPath) {
    $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android\sdk'
}

$adbPath = Join-Path $AndroidSdkPath 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "ADB nao encontrado em: $adbPath"
}

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

$selectedLine = $deviceLines |
    Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+device(?:\s|$)" }
if (-not $selectedLine) {
    throw "Dispositivo autorizado nao encontrado: $Serial"
}

function Invoke-AdbReadOnly {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & $adbPath -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "ADB falhou: $($Arguments -join ' ')"
    }
}

Write-Output '=== DEVICE ==='
Write-Output $selectedLine

Write-Output '=== PLATFORM ==='
foreach ($property in @(
    'ro.product.manufacturer',
    'ro.product.model',
    'ro.product.device',
    'ro.build.version.release',
    'ro.build.version.sdk',
    'ro.product.cpu.abilist',
    'ro.build.version.security_patch'
)) {
    $value = Invoke-AdbReadOnly -Arguments @('shell', 'getprop', $property)
    Write-Output ("{0}={1}" -f $property, $value)
}

Write-Output '=== DISPLAY ==='
Invoke-AdbReadOnly -Arguments @('shell', 'wm', 'size')
Invoke-AdbReadOnly -Arguments @('shell', 'wm', 'density')

Write-Output '=== POWER AND STORAGE ==='
Invoke-AdbReadOnly -Arguments @('shell', 'dumpsys', 'battery') |
    Select-String -Pattern 'status:|level:|temperature:'
Invoke-AdbReadOnly -Arguments @('shell', 'df', '-h', '/data') |
    Select-Object -First 2

Write-Output '=== TUTOR TDS PACKAGES ==='
foreach ($packageName in @(
    'com.tutortds_cartilhas',
    'com.tutortds_cartilhas.dev',
    'br.org.ipex.cartilhas_app'
)) {
    Write-Output ("--- {0} ---" -f $packageName)
    Invoke-AdbReadOnly -Arguments @('shell', 'dumpsys', 'package', $packageName) |
        Select-String -Pattern 'versionName=|versionCode=|firstInstallTime=|lastUpdateTime=|pkgFlags='
}

Write-Output 'Inventario concluido. Nenhum comando mutavel foi executado no dispositivo.'
