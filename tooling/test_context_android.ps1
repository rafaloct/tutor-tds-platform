param(
    [ValidatePattern('^emulator-[0-9]+$')][string]$Device = 'emulator-5556',
    [string]$Flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat',
    [string]$Adb = 'C:/Users/Usuario/AppData/Local/Android/sdk/platform-tools/adb.exe',
    [string]$AppRoot = 'C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa',
    [string]$DefinesFile,
    [string]$EvidenceFile,
    [ValidateSet('student_online', 'student_restart', 'student_offline',
        'offline_restart', 'student_reconnect', 'instructor_observation')]
    [string]$StartPhase = 'student_online'
)
# The first phase requires a fresh synthetic client; server history is preserved.
# The script never clears app data or resets the server. Resume only after
# diagnosing a failure, using the persisted phase marker as the authority.
# Only the .dev app and the selected emulator are operated; no release build.
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
if (-not $DefinesFile) {
    $DefinesFile = Join-Path $workspace 'tmp/cloud-context-android-defines.json'
}
if (-not $EvidenceFile) {
    $EvidenceFile = Join-Path $workspace 'docs/production/evidence/context-android-gate.json'
}
$DefinesFile = (Resolve-Path -LiteralPath $DefinesFile).Path
$AppRoot = (Resolve-Path -LiteralPath $AppRoot).Path
$configuration = Get-Content -LiteralPath $DefinesFile -Raw | ConvertFrom-Json
if ($configuration.TUTOR_ENVIRONMENT -ne 'staging' -or
    $configuration.TUTOR_API_URL -ne $configuration.TUTOR_STAGING_API_URL -or
    -not $configuration.TUTOR_API_URL.StartsWith('https://') -or
    "$($configuration.LEARNING_CONTEXT_ENABLED)".ToLowerInvariant() -ne 'true' -or
    "$($configuration.DURABLE_LEARNING_OUTBOX_ENABLED)".ToLowerInvariant() -ne 'true' -or
    -not $configuration.QA_STUDENT_ID -or -not $configuration.QA_TEACHER_ID -or
    $configuration.QA_STUDENT_ID -eq $configuration.QA_TEACHER_ID -or
    $configuration.QA_STUDENT_CPF -ne '12345678909' -or
    $configuration.QA_TEACHER_CPF -ne '11144477735') {
    throw 'Expected isolated staging definitions and the synthetic Context QA accounts.'
}
foreach ($key in @('QA_STUDENT_PASSWORD', 'QA_TEACHER_PASSWORD')) {
    if ([string]::IsNullOrWhiteSpace($configuration.$key) -or
        $configuration.$key.Length -lt 12) {
        throw "Missing synthetic credential: $key. Its value must never appear in logs."
    }
}
if ($configuration.TUTOR_GATEWAY_URL) {
    throw 'This acceptance test requires the AI/certificate gateway to remain unset.'
}

function Invoke-AdbChecked {
    param([string[]]$Arguments)
    $result = & $Adb -s $Device @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Android operation failed: $($Arguments[0])" }
    return ($result -join "`n").Trim()
}

function Set-QaNetwork {
    param([bool]$Enabled)
    $operation = if ($Enabled) { 'enable' } else { 'disable' }
    $null = Invoke-AdbChecked @('shell', 'svc', 'wifi', $operation)
    $null = Invoke-AdbChecked @('shell', 'svc', 'data', $operation)
}

$deviceState = Invoke-AdbChecked @('get-state')
if ($deviceState -ne 'device') { throw 'Selected QA emulator is not ready.' }
$emulator = Invoke-AdbChecked @('shell', 'getprop', 'ro.kernel.qemu')
if ($emulator -ne '1') { throw 'This runner is restricted to an Android emulator.' }
$wifi = Invoke-AdbChecked @('shell', 'settings', 'get', 'global', 'wifi_on')
$mobile = Invoke-AdbChecked @('shell', 'settings', 'get', 'global', 'mobile_data')
if ($wifi -notin @('0', '1') -or $mobile -notin @('0', '1')) {
    throw 'Could not read the original emulator network state; no state was changed.'
}
$runDirectory = Join-Path $workspace ('tmp/context-android-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$null = New-Item -ItemType Directory -Path $runDirectory
$phases = @('student_online', 'student_restart', 'student_offline',
    'offline_restart', 'student_reconnect', 'instructor_observation')
$reports = [System.Collections.Generic.List[object]]::new()
$startIndex = [Array]::IndexOf($phases, $StartPhase)
$arguments = @('test', 'integration_test/context_learning_path_test.dart',
    '-d', $Device, '--no-pub', '--no-uninstall', '--reporter', 'expanded',
    "--dart-define-from-file=$DefinesFile")
$previousLocation = Get-Location
try {
    Set-Location -LiteralPath $AppRoot
    for ($index = $startIndex; $index -lt $phases.Count; $index++) {
        $phase = $phases[$index]
        # Stop before changing connectivity, so no unobserved foreground
        # interaction can create or send evidence between phases.
        $null = Invoke-AdbChecked @('shell', 'am', 'force-stop', 'com.tutortds_cartilhas.dev')
        $processes = Invoke-AdbChecked @('shell', 'ps', '-A')
        if ($processes -match '(?m)\scom\.tutortds_cartilhas\.dev\s*$') {
            throw 'QA app is still running after force-stop.'
        }
        Set-QaNetwork ($phase -notin @('student_offline', 'offline_restart'))
        $phaseLog = Join-Path $runDirectory "$phase.log"
        Write-Host "Validating Context Core: $phase"
        & $Flutter @arguments "--dart-define=CONTEXT_QA_PHASE=$phase" 2>&1 |
            Tee-Object -FilePath $phaseLog
        if ($LASTEXITCODE -ne 0) {
            throw "Phase $phase failed. Evidence: $phaseLog. Diagnose before retrying."
        }
        $prefix = 'TDS_CONTEXT_QA_EVIDENCE '
        $recordLine = @(Get-Content -LiteralPath $phaseLog | Where-Object { $_.Contains($prefix) })
        if ($recordLine.Count -ne 1) { throw "Missing or ambiguous evidence for $phase." }
        $record = $recordLine[0].Substring($recordLine[0].IndexOf($prefix) + $prefix.Length) |
            ConvertFrom-Json
        if ($record.phase -ne $phase) { throw 'Evidence does not match the executed phase.' }
        $reports.Add($record)
        # Kept locally per phase even if a later phase fails. It contains no
        # passwords/tokens and is useful for a bounded, diagnosed continuation.
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (
            Join-Path $runDirectory "$phase.evidence.json") -Encoding utf8
    }
    $allPhases = $StartPhase -eq 'student_online'
    $report = [ordered]@{
        verified_at = (Get-Date).ToUniversalTime().ToString('o')
        device = $Device
        android_version = (Invoke-AdbChecked @('shell', 'getprop', 'ro.build.version.release'))
        api_url = $configuration.TUTOR_API_URL
        app_package = 'com.tutortds_cartilhas.dev'
        all_phases_in_this_run = $allPhases
        status = if ($allPhases) { 'ANDROID_PATHS_PASSED' } else { 'PARTIAL_RESUMED_RUN' }
        tests = @('student_learning_path', 'instructor_observation_path', 'offline_sync_path')
        separate_processes = $true
        uninstall_between_phases = $false
        production_ready = $false
        test_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (
            Join-Path $AppRoot 'integration_test/context_learning_path_test.dart')).Hash.ToLowerInvariant()
        runner_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
        phases = $reports.ToArray()
    }
    # A resumed run cannot overwrite the canonical full-run evidence.
    $output = if ($allPhases) { $EvidenceFile } else {
        Join-Path $runDirectory 'resumed-gate.json'
    }
    $parent = Split-Path $output -Parent
    $null = New-Item -ItemType Directory -Force -Path $parent
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $output -Encoding utf8
    Write-Host "Android evidence saved: $output"
} finally {
    # Restore the exact initial connectivity even after a build/test failure.
    try {
        $null = Invoke-AdbChecked @('shell', 'am', 'force-stop', 'com.tutortds_cartilhas.dev')
        $wifiAction = if ($wifi -eq '1') { 'enable' } else { 'disable' }
        $dataAction = if ($mobile -eq '1') { 'enable' } else { 'disable' }
        $null = Invoke-AdbChecked @('shell', 'svc', 'wifi', $wifiAction)
        $null = Invoke-AdbChecked @('shell', 'svc', 'data', $dataAction)
    } finally {
        Set-Location -LiteralPath $previousLocation.Path
    }
}
