param(
    [switch]$Execute,
    [ValidateSet('emulator-5556')][string]$Device = 'emulator-5556',
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RunId = ([guid]::NewGuid().ToString('N')),
    [string]$Flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat',
    [string]$Adb = 'C:/Users/Usuario/AppData/Local/Android/sdk/platform-tools/adb.exe',
    [string]$AppRoot = 'C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa'
)
# Explicitly authorized QA emulator/package only. One build and one install -r;
# never uninstall, clear app data/logs, change connectivity, or start production.
# Does not import CartilhasApp: no HTTP, credentials, outbox, or product changes.
$ErrorActionPreference = 'Stop'
$package = 'com.tutortds_cartilhas.dev'
$apiBase = 'https://tutor-tds-staging.fastapicloud.dev'
$target = 'integration_test/prebuilt_apk_smoke_test.dart'
$driver = 'test_driver/prebuilt_apk_smoke_driver.dart'
$workspace = Split-Path $PSScriptRoot -Parent
$runDirectory = Join-Path $workspace "tmp/prebuilt-apk-smoke-$RunId"
$buildArguments = @('build', 'apk', '--debug', '--no-pub', '--target', $target,
    '--dart-define=TUTOR_ENVIRONMENT=staging',
    "--dart-define=TUTOR_API_URL=$apiBase",
    "--dart-define=TUTOR_STAGING_API_URL=$apiBase",
    "--dart-define=PREBUILT_QA_RUN_ID=$RunId",
    '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false')
if (-not $Execute) {
    [ordered]@{
        mode = 'PLAN_ONLY_NO_SDK_OR_DEVICE_COMMANDS'
        run_id = $RunId
        device = $Device
        package = $package
        build_count = 1
        install_count = 1
        phases = @('seed', 'verify')
        attach = 'flutter drive --use-existing-app=<forwarded VM URI> --keep-app-running --no-dds --no-pub'
        output = $runDirectory
        note = 'Run with -Execute only after review and SDK/device exclusivity is granted.'
    } | ConvertTo-Json -Depth 4
    return
}

function Invoke-AdbChecked {
    param([string[]]$CommandArgs, [switch]$AllowMissingProcess)
    $lines = & $Adb -s $Device @CommandArgs 2>&1
    $exitCode = $LASTEXITCODE
    $result = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
    if ($exitCode -ne 0 -and -not ($AllowMissingProcess -and $exitCode -eq 1 -and -not $result.Trim())) {
        throw "ADB command failed: $($CommandArgs[0]); exit $exitCode."
    }
    return $result.Trim()
}

function Get-QaPid {
    $value = Invoke-AdbChecked @('shell', 'pidof', '-s', $package) -AllowMissingProcess
    if (-not $value) { return $null }
    if ($value -notmatch '^\d+$') { throw 'Unexpected QA process identity.' }
    return [int]$value
}

function Stop-QaProcess {
    $null = Invoke-AdbChecked @('shell', 'am', 'force-stop', $package)
    if ($null -ne (Get-QaPid)) { throw 'QA process survived force-stop.' }
}

function Get-InstalledIdentity {
    $location = Invoke-AdbChecked @('shell', 'pm', 'path', $package)
    $pathMatch = [regex]::Match($location, '^package:(/data/app/[A-Za-z0-9_./=+~\-]+/base\.apk)$')
    if (-not $pathMatch.Success) { throw 'Expected one installed QA APK; no split or missing package accepted.' }
    $remoteApk = $pathMatch.Groups[1].Value
    $hashLine = Invoke-AdbChecked @('shell', 'sha256sum', $remoteApk)
    $hashMatch = [regex]::Match($hashLine, '^([a-fA-F0-9]{64})\s')
    if (-not $hashMatch.Success) { throw 'Could not hash installed QA APK.' }
    $details = Invoke-AdbChecked @('shell', 'dumpsys', 'package', $package)
    $firstTimes = [regex]::Matches($details, '(?m)^\s*firstInstallTime=(.+)$')
    $updateTimes = [regex]::Matches($details, '(?m)^\s*lastUpdateTime=(.+)$')
    if ($firstTimes.Count -ne 1 -or $updateTimes.Count -ne 1) { throw 'Ambiguous installed package timestamps.' }
    return [ordered]@{
        sha256 = $hashMatch.Groups[1].Value.ToLowerInvariant()
        first_install_time = $firstTimes[0].Groups[1].Value.Trim()
        last_update_time = $updateTimes[0].Groups[1].Value.Trim()
    }
}

function Assert-InstalledIdentity {
    param($Expected)
    $actual = Get-InstalledIdentity
    foreach ($field in @('sha256', 'first_install_time', 'last_update_time')) {
        if ($actual[$field] -ne $Expected[$field]) { throw "Installed QA APK changed: $field." }
    }
    return $actual
}

function Wait-VmService {
    param([int]$AndroidPid, [long]$StartedAt)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while ($watch.Elapsed.TotalSeconds -lt 45) {
            if ((Get-QaPid) -ne $AndroidPid) { throw 'QA process exited or changed before driver attachment.' }
            # Read only this PID; never clear system logs. Epoch rejects stale PID reuse.
            $logs = Invoke-AdbChecked @('logcat', "--pid=$AndroidPid", '-d', '-v', 'epoch', '-t', '2000')
            $uriMatches = [regex]::Matches($logs,
                '(?m)^\s*(?<epoch>\d+\.\d+)\s+[^\r\n]*?(?:Dart VM service|VM Service) is listening on (?<uri>http://[^\s]+)')
            foreach ($uriMatch in @($uriMatches | Select-Object -Last 10)) {
                $timestamp = [double]::Parse($uriMatch.Groups['epoch'].Value, [Globalization.CultureInfo]::InvariantCulture)
                if ($timestamp -lt $StartedAt) { continue }
                $uri = [uri]$uriMatch.Groups['uri'].Value.TrimEnd('.')
                if ($uri.Scheme -ne 'http' -or -not $uri.IsLoopback -or $uri.Port -lt 1) {
                    throw 'VM Service must be a loopback HTTP endpoint.'
                }
                return $uri
            }
            Start-Sleep -Milliseconds 400
        }
        throw 'Timed out finding this QA process VM Service; no retry/reinstall performed.'
    } finally {
        $watch.Stop()
    }
}

foreach ($executable in @($Flutter, $Adb)) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Configured SDK tool missing.' }
}
$AppRoot = (Resolve-Path -LiteralPath $AppRoot).Path
foreach ($file in @($target, $driver)) {
    if (-not (Test-Path -LiteralPath (Join-Path $AppRoot $file) -PathType Leaf)) { throw 'Smoke source missing.' }
}
if (Test-Path -LiteralPath $runDirectory) { throw 'Run ID already exists; never overwrite a smoke run.' }
if ((Invoke-AdbChecked @('get-state')) -ne 'device' -or
    (Invoke-AdbChecked @('shell', 'getprop', 'ro.kernel.qemu')) -ne '1') {
    throw 'Only the approved running QA emulator is allowed.'
}
$beforeInstall = Get-InstalledIdentity
$initialPid = Get-QaPid
$sdkRoot = Split-Path (Split-Path $Adb -Parent) -Parent
$buildTools = @(Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
    Where-Object Name -Match '^\d+\.\d+\.\d+$' | Sort-Object { [version]$_.Name } -Descending)
if ($buildTools.Count -eq 0) { throw 'Android manifest inspection tool missing.' }
$aapt = Join-Path $buildTools[0].FullName 'aapt.exe'
if (-not (Test-Path -LiteralPath $aapt)) { throw 'Android manifest inspection tool missing.' }
$null = New-Item -ItemType Directory -Path $runDirectory
$oldLocation = Get-Location
$ownedForwards = [System.Collections.Generic.List[string]]::new()
$reports = [System.Collections.Generic.List[object]]::new()
$environmentNames = @('TDS_QA_SMOKE_REPORT_PATH', 'TDS_QA_SMOKE_RUN_ID', 'TDS_QA_SMOKE_EXPECTED_PHASE')
$oldEnvironment = @{}
foreach ($name in $environmentNames) { $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    Set-Location -LiteralPath $AppRoot
    & $Flutter @buildArguments 2>&1 | Tee-Object -FilePath (Join-Path $runDirectory 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Single QA APK build failed; device not installed.' }
    $apk = Join-Path $AppRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    $apkHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    $badging = (& $aapt dump badging $apk 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect built QA APK.' }
    $packageMatch = [regex]::Match($badging, "(?m)^package: name='([^']+)'")
    $activityMatch = [regex]::Match($badging, "(?m)^launchable-activity: name='([^']+)'")
    if ($packageMatch.Groups[1].Value -ne $package -or
        $activityMatch.Groups[1].Value -ne 'com.tutortds_cartilhas.MainActivity' -or
        $badging -notmatch '(?m)^application-debuggable') {
        throw 'Refusing any APK except the approved debuggable .dev application.'
    }
    Stop-QaProcess
    # Explicit single install -r; unlike flutter drive's installer, no uninstall fallback.
    $installResult = Invoke-AdbChecked @('install', '-t', '-r', $apk)
    if ($installResult -notmatch '(?m)^Success\s*$' -or $installResult -match 'Failure') { throw 'QA APK install failed.' }
    $installed = Get-InstalledIdentity
    if ($installed.sha256 -ne $apkHash -or $installed.first_install_time -ne $beforeInstall.first_install_time) {
        throw 'Installed APK hash differs or original installation/data continuity was lost.'
    }
    $seenPids = [System.Collections.Generic.HashSet[int]]::new()
    if ($null -ne $initialPid) { $null = $seenPids.Add($initialPid) }
    foreach ($phase in @('seed', 'verify')) {
        Stop-QaProcess
        $null = Assert-InstalledIdentity $installed
        $startedAt = [long](Invoke-AdbChecked @('shell', 'date', '+%s'))
        $started = Invoke-AdbChecked @('shell', 'am', 'start', '-W', '-n',
            "$package/$($activityMatch.Groups[1].Value)", '-a', 'android.intent.action.MAIN',
            '-c', 'android.intent.category.LAUNCHER', '--ez', 'enable-checked-mode', 'true',
            '--ez', 'verify-entry-points', 'true')
        if ($started -match 'Error:|Exception') { throw 'QA activity did not start.' }
        $androidPid = Get-QaPid
        if ($null -eq $androidPid -or -not $seenPids.Add($androidPid)) { throw 'Expected a distinct new QA process.' }
        $remoteVm = Wait-VmService -AndroidPid $androidPid -StartedAt $startedAt
        $hostPort = Invoke-AdbChecked @('forward', 'tcp:0', "tcp:$($remoteVm.Port)")
        if ($hostPort -notmatch '^\d+$') { throw 'ADB did not allocate an owned local forward.' }
        $forward = "tcp:$hostPort"
        $ownedForwards.Add($forward)
        $localVm = [System.UriBuilder]::new($remoteVm)
        $localVm.Host = '127.0.0.1'
        $localVm.Port = [int]$hostPort
        $reportPath = Join-Path $runDirectory "$phase.json"
        [Environment]::SetEnvironmentVariable('TDS_QA_SMOKE_REPORT_PATH', $reportPath, 'Process')
        [Environment]::SetEnvironmentVariable('TDS_QA_SMOKE_RUN_ID', $RunId, 'Process')
        [Environment]::SetEnvironmentVariable('TDS_QA_SMOKE_EXPECTED_PHASE', $phase, 'Process')
        & $Flutter drive '--debug' '--no-pub' '--no-dds' '-d' $Device '--driver' $driver '--target' $target `
            "--use-existing-app=$($localVm.Uri.AbsoluteUri)" '--keep-app-running' 2>&1 |
            Tee-Object -FilePath (Join-Path $runDirectory "$phase.log")
        if ($LASTEXITCODE -ne 0) { throw "Smoke phase $phase failed; no phase retry performed." }
        $phaseReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        if ($phaseReport.status -ne 'passed' -or $phaseReport.report.phase -ne $phase -or
            $phaseReport.report.run_id -ne $RunId -or $phaseReport.report.pid -ne $androidPid -or
            $phaseReport.report.other_preferences_unchanged -ne $true) {
            throw 'Driver report does not match the actual phase/process.'
        }
        if ($phase -eq 'verify' -and ($phaseReport.report.first_pid -ne $reports[0].report.pid -or
            $phaseReport.report.nonce -ne $reports[0].report.nonce -or
            $phaseReport.report.created_at -ne $reports[0].report.created_at)) {
            throw 'Cross-process QA checkpoint was not preserved exactly.'
        }
        $null = Assert-InstalledIdentity $installed
        $reports.Add($phaseReport)
        $null = Invoke-AdbChecked @('forward', '--remove', $forward)
        $null = $ownedForwards.Remove($forward)
    }
    [ordered]@{
        status = 'PREBUILT_APK_TWO_PROCESS_SMOKE_PASSED'
        verified_at = (Get-Date).ToUniversalTime().ToString('o')
        run_id = $RunId
        device = $Device
        package = $package
        build_count = 1
        install_count = 1
        apk_sha256 = $apkHash
        before_install = $beforeInstall
        installed = $installed
        phases = $reports.ToArray()
        source_sha256 = [ordered]@{
            target = (Get-FileHash -LiteralPath (Join-Path $AppRoot $target) -Algorithm SHA256).Hash.ToLowerInvariant()
            driver = (Get-FileHash -LiteralPath (Join-Path $AppRoot $driver) -Algorithm SHA256).Hash.ToLowerInvariant()
            runner = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        limits = @('Harness smoke only; no course publication or production acceptance.',
            'QA instrumented APK remains installed and is stopped; app/user/outbox data is not cleared.')
    } | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $runDirectory 'evidence.json') -Encoding utf8
    Write-Host "Prebuilt smoke evidence: $runDirectory/evidence.json"
} finally {
    foreach ($forward in @($ownedForwards)) {
        try { $null = Invoke-AdbChecked @('forward', '--remove', $forward) }
        catch { Write-Warning "Could not remove this runner's forward $forward." }
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process')
    }
    try { Stop-QaProcess } catch { Write-Warning 'Could not stop QA process during cleanup.' }
    Set-Location -LiteralPath $oldLocation.Path
}
