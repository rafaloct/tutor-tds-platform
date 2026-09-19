[CmdletBinding()]
param(
    [string]$Serial = 'ZT6HPRHQHATSEQPR',
    [string]$Package = 'com.tutortds_cartilhas.dev',
    [string]$Activity = 'com.tutortds_cartilhas.MainActivity',
    [string]$Output = (Join-Path $PSScriptRoot '..\release\pitch\app_pitch_presentation_raw.mp4')
)

$ErrorActionPreference = 'Stop'
$adb = 'D:\DevTools\AndroidSDK\platform-tools\adb.exe'
$remoteVideo = '/sdcard/app_pitch_presentation.mp4'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "ADB nao encontrado: $adb"
}

$deviceState = (& $adb -s $Serial get-state 2>$null).Trim()
if ($deviceState -ne 'device') {
    throw "Dispositivo $Serial indisponivel: $deviceState"
}

$size = (& $adb -s $Serial shell wm size) -join ' '
if ($size -notmatch '1220x2712') {
    throw "Resolucao nao mapeada para este roteiro: $size"
}

$installed = (& $adb -s $Serial shell pm path $Package) -join ''
if ($installed -notmatch '^package:') {
    throw "Pacote nao instalado: $Package"
}

$outputFull = [IO.Path]::GetFullPath($Output)
$outputDirectory = Split-Path -Parent $outputFull
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$rotationWasEnabled = ((& $adb -s $Serial shell settings get system accelerometer_rotation) -join '').Trim()
$userRotation = ((& $adb -s $Serial shell settings get system user_rotation) -join '').Trim()

function Invoke-AdbShell {
    param([Parameter(Mandatory)][string[]]$Command)
    & $adb -s $Serial shell @Command | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "ADB falhou: $($Command -join ' ')"
    }
}

function Wait-Pitch {
    param([Parameter(Mandatory)][double]$Seconds)
    Start-Sleep -Milliseconds ([int]($Seconds * 1000))
}

try {
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_WAKEUP')
    Invoke-AdbShell @('wm', 'dismiss-keyguard')
    Invoke-AdbShell @('settings', 'put', 'system', 'accelerometer_rotation', '0')
    Invoke-AdbShell @('settings', 'put', 'system', 'user_rotation', '0')
    Invoke-AdbShell @('am', 'force-stop', $Package)
    Invoke-AdbShell @('rm', '-f', $remoteVideo)

    $recordArguments = @(
        '-s', $Serial,
        'shell', 'screenrecord',
        '--time-limit', '108',
        '--bit-rate', '6000000',
        $remoteVideo
    )
    $recordProcess = Start-Process `
        -FilePath $adb `
        -ArgumentList $recordArguments `
        -PassThru `
        -WindowStyle Hidden

    Wait-Pitch 1
    Invoke-AdbShell @('am', 'start', '-n', "$Package/$Activity")
    Wait-Pitch 9

    # Catálogo: apresenta mais trilhas e retorna ao início.
    Invoke-AdbShell @('input', 'swipe', '600', '2200', '600', '1100', '600')
    Wait-Pitch 4
    Invoke-AdbShell @('input', 'swipe', '600', '900', '600', '2100', '600')
    Wait-Pitch 3

    # Agricultura Sustentável: leitura acessível e avanço passo a passo.
    Invoke-AdbShell @('input', 'tap', '500', '1090')
    Wait-Pitch 5
    Invoke-AdbShell @('input', 'tap', '600', '2450')
    Wait-Pitch 7
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_BACK')
    Wait-Pitch 3

    # Central de IA: visão geral, recursos completos e chat contextual.
    Invoke-AdbShell @('input', 'tap', '300', '606')
    Wait-Pitch 5
    Invoke-AdbShell @('input', 'swipe', '600', '2200', '600', '700', '700')
    Wait-Pitch 6
    Invoke-AdbShell @('input', 'swipe', '600', '700', '600', '2200', '700')
    Wait-Pitch 3
    Invoke-AdbShell @('input', 'tap', '600', '1500')
    Wait-Pitch 9
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_BACK')
    Wait-Pitch 2

    # Cartões de estudo: demonstra a preparação de material personalizado.
    Invoke-AdbShell @('input', 'tap', '600', '2050')
    Wait-Pitch 7
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_BACK')
    Wait-Pitch 2
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_BACK')
    Wait-Pitch 3

    # Carteira de certificados verificáveis.
    Invoke-AdbShell @('input', 'tap', '760', '780')
    Wait-Pitch 7
    Invoke-AdbShell @('input', 'keyevent', 'KEYCODE_BACK')
    Wait-Pitch 3

    # Encerramento no catálogo e nas marcas institucionais.
    Invoke-AdbShell @('input', 'swipe', '600', '2200', '600', '1200', '600')
    Wait-Pitch 6
    Invoke-AdbShell @('input', 'swipe', '600', '900', '600', '2100', '600')

    Wait-Process -Id $recordProcess.Id -Timeout 20
    if ($recordProcess.ExitCode -ne 0) {
        throw "screenrecord terminou com codigo $($recordProcess.ExitCode)"
    }

    & $adb -s $Serial pull $remoteVideo $outputFull | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputFull)) {
        throw 'Nao foi possivel transferir o video gravado.'
    }
    Get-Item -LiteralPath $outputFull
} finally {
    if ($rotationWasEnabled -match '^[01]$') {
        & $adb -s $Serial shell settings put system accelerometer_rotation $rotationWasEnabled | Out-Null
    }
    if ($userRotation -match '^[0-3]$') {
        & $adb -s $Serial shell settings put system user_rotation $userRotation | Out-Null
    }
}
