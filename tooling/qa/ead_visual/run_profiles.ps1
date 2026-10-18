# Execute one isolated Android profile and record real media evidence.
# Never wipes AVD, touches Play package, stops unrelated jobs, or uses QA credentials.
[CmdletBinding()]
param(
    [ValidateSet('android35-compact', 'android35-offline', 'android36-large-text')]
    [string]$Profile = 'android35-compact',
    [string]$ApkPath,
    [string]$Package,
    [ValidateRange(15, 180)]
    [int]$Seconds = 60,
    [string]$OutputRoot = 'D:\AI-Shared\android-qa\results',
    [double]$MinimumFreeGiB = 3.4,
    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$adb = 'D:\DevTools\AndroidSDK\platform-tools\adb.exe'
$emulator = 'D:\DevTools\AndroidSDK\emulator\emulator.exe'
$aapt = 'D:\DevTools\AndroidSDK\build-tools\35.0.1\aapt.exe'
$python = 'C:\Users\Rafael\AppData\Local\Programs\Python\Python313\python.exe'
$serial = 'emulator-5554'
$profileAvd = if ($Profile -like 'android36-*') { 'tdsAab' } else { 'Pixel_8_Pro' }
$expectedSdk = if ($Profile -like 'android36-*') { '36' } else { '35' }

foreach ($p in @($adb, $emulator, $aapt, $python)) {
    if (!(Test-Path -LiteralPath $p)) { throw "Dependência ausente: $p" }
}
$os = Get-CimInstance Win32_OperatingSystem
$freeGiB = [math]::Round($os.FreePhysicalMemory / 1048576, 2)
$accel = (& $emulator -accel-check 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $accel -notmatch 'WHPX.+installed and usable') {
    throw 'WHPX indisponível: não iniciar emulador por software.'
}
$avds = @(& $emulator -list-avds)
if ($profileAvd -notin $avds) { throw "AVD ausente: $profileAvd" }
$current = (& $adb devices | Out-String)
if ($current -match ('(?m)^\s*' + [regex]::Escape($serial) + '\s+')) {
    throw "O emulador $serial já está ocupado. Não interferir em sessão existente."
}
$report = [ordered]@{
    profile = $Profile
    avd = $profileAvd
    expected_api = $expectedSdk
    free_memory_GiB = $freeGiB
    whpx = $true
    active_emulator_at_preflight = $false
    camera_source = 'Android screencap/screenrecord, no simulated UI'
    cpu_cores_override = 2
    avd_ram_override_MB = 2048
    gpu_mode = 'host'
}
$report | ConvertTo-Json | Write-Output
if ($PreflightOnly) { return }
if ($freeGiB -lt $MinimumFreeGiB) {
    throw "RAM livre insuficiente ($freeGiB GiB). Preserve tarefas e repita com recursos livres."
}
if (!$ApkPath -or !(Test-Path -LiteralPath $ApkPath)) {
    throw 'Informe APK de QA construído nesta worktree.'
}
if ($Package -notmatch '^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$') {
    throw 'Pacote não é QA isolado: o app Play não pode ser substituído.'
}
$badging = & $aapt dump badging $ApkPath 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package: name='([^']+)'") {
    throw 'Não foi possível validar a identidade do APK.'
}
if ($Matches[1] -ne $Package) {
    throw "APK pertence a pacote diferente: $($Matches[1])"
}

$utc = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$run = Join-Path $OutputRoot "ead-first-$utc-$Profile"
if (Test-Path -LiteralPath $run) { throw 'Diretório de evidências já existe.' }
New-Item -ItemType Directory -Path $run -Force | Out-Null
$proc = $null
$started = $false
try {
    $params = @(
        '-avd', $profileAvd, '-port', '5554',
        '-memory', '2048', '-cores', '2',
        '-gpu', 'host', '-no-window',
        '-no-snapshot', '-no-boot-anim', '-noaudio', '-read-only'
    )
    $proc = Start-Process -FilePath $emulator -ArgumentList $params -PassThru -RedirectStandardOutput (Join-Path $run 'emulator.stdout.log') -RedirectStandardError (Join-Path $run 'emulator.stderr.log')
    $started = $true
    $booted = $false
    for ($i = 0; $i -lt 52; $i++) {
        Start-Sleep -Seconds 3
        if ($proc.HasExited) { throw "Emulador encerrado durante boot (exit $($proc.ExitCode))." }
        $device = (& $adb devices | Out-String)
        if ($device -match "emulator-5554\s+device") {
            $ready = (& $adb -s $serial shell getprop sys.boot_completed 2>&1 | Out-String).Trim()
            if ($ready -eq '1') { $booted = $true; break }
        }
    }
    if (!$booted) { throw 'AVD não finalizou inicialização dentro do limite do runner.' }
    $sdk = (& $adb -s $serial shell getprop ro.build.version.sdk | Out-String).Trim()
    if ($sdk -ne $expectedSdk) { throw "API inesperada: $sdk, esperado $expectedSdk" }
    # Install an explicitly validated QA package only on the ephemeral emulator.
    & $adb -s $serial install -r $ApkPath
    if ($LASTEXITCODE -ne 0) { throw 'Falhou instalação do APK QA.' }
    $gitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $gitSha = (& git -C $gitRoot rev-parse HEAD | Out-String).Trim()
    & $python (Join-Path $PSScriptRoot 'capture_story.py') --adb $adb --serial $serial --package $Package --profile $Profile --git-sha $gitSha --output (Join-Path $run 'capture') --seconds $Seconds
    $scriptExit = $LASTEXITCODE
    if ($scriptExit -ne 0) { throw "Captura bloqueada (exit $scriptExit); evidências parciais no diretório $run" }
    Write-Output "QA_PROFILE_CAPTURED=$Profile"
    Write-Output "QA_EVIDENCE_DIRECTORY=$run"
}
finally {
    if ($started) {
        # Kill only the emulator at the fixed port started by this runner.
        try { & $adb -s $serial emu kill | Out-Null } catch { }
    }
}
