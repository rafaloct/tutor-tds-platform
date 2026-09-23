param(
    [switch]$Execute,
    [ValidateSet('emulator-5556')][string]$Device = 'emulator-5556',
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RunId = ([guid]::NewGuid().ToString('N')),
    [string]$Flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat',
    [string]$Adb = 'C:/Users/Usuario/AppData/Local/Android/sdk/platform-tools/adb.exe',
    [string]$AppRoot = 'C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa',
    [string]$DefinesFile,
    [string]$RuntimeFile,
    [string]$EvidenceFile
)
# QA staging only. One APK build/install, then attach to eight distinct processes.
# No uninstall, data/log clearing, seed/reset, production credentials or retries.
# A failed phase can have committed remotely or advanced its checkpoint. Preserve
# the complete run. A diagnosed new run gets its own course; prior drafts/history
# are included in the baseline and must remain unchanged throughout the new gate.
$ErrorActionPreference = 'Stop'
$package = 'com.tutortds_cartilhas.dev'
$apiBase = 'https://tutor-tds-staging.fastapicloud.dev'
$courseId = "qa-dynamic-course-$RunId"
$workspace = Split-Path $PSScriptRoot -Parent
$python = Join-Path $workspace 'tmp/context-cloud-locked-env/Scripts/python.exe'
$target = 'integration_test/dynamic_learning_path_test.dart'
$driver = 'test_driver/dynamic_learning_path_driver.dart'
$phases = @('author_v1', 'publisher_v1', 'learner_v1', 'author_v2',
    'publisher_v2', 'learner_after_v2', 'learner_offline', 'learner_reconnect')
$runDirectory = Join-Path $workspace "tmp/dynamic-learning-android-$RunId"
if (-not $DefinesFile) { $DefinesFile = Join-Path $workspace 'tmp/cloud-dynamic-learning-defines.json' }
if (-not $RuntimeFile) { $RuntimeFile = Join-Path $workspace 'tmp/cloud-staging-runtime.json' }
if (-not $EvidenceFile) { $EvidenceFile = Join-Path $workspace 'docs/production/evidence/dynamic-learning-android.json' }
if (-not $Execute) {
    [ordered]@{
        mode = 'PLAN_ONLY_NO_SDK_DEVICE_NETWORK_OR_WRITES'
        run_id = $RunId
        course_id = $courseId
        device = $Device
        package = $package
        api_url = $apiBase
        build_count = 1
        install_count = 1
        phases = $phases
        host_hooks = @('before_android', 'after_v1', 'after_v2', 'after_android')
        credentials_in_apk = @('AUTHOR', 'PUBLISHER', 'LEARNER')
        automatic_resume = $false
        output = $runDirectory
        evidence = $EvidenceFile
    } | ConvertTo-Json -Depth 5
    return
}

function Invoke-AdbChecked {
    param([string[]]$CommandArgs, [switch]$AllowMissingProcess)
    $lines = & $Adb -s $Device @CommandArgs 2>&1
    $exitCode = $LASTEXITCODE
    $result = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
    if ($exitCode -ne 0 -and -not ($AllowMissingProcess -and $exitCode -eq 1 -and -not $result.Trim())) {
        throw "ADB command failed at $($CommandArgs[0]); exit $exitCode."
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
    if (-not $pathMatch.Success) { throw 'Expected one existing installed QA APK.' }
    $hashLine = Invoke-AdbChecked @('shell', 'sha256sum', $pathMatch.Groups[1].Value)
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

function Get-QaNetwork {
    return [ordered]@{
        wifi = Invoke-AdbChecked @('shell', 'settings', 'get', 'global', 'wifi_on')
        mobile = Invoke-AdbChecked @('shell', 'settings', 'get', 'global', 'mobile_data')
    }
}

function Wait-QaNetwork {
    param([string]$Wifi, [string]$Mobile)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($watch.Elapsed.TotalSeconds -lt 20) {
            $actual = Get-QaNetwork
            if ($actual.wifi -eq $Wifi -and $actual.mobile -eq $Mobile) { return $actual }
            Start-Sleep -Milliseconds 300
        }
        throw 'Emulator network settings did not reach the requested state.'
    } finally { $watch.Stop() }
}

function Set-QaNetwork {
    param([string]$Wifi, [string]$Mobile)
    $wifiAction = if ($Wifi -eq '1') { 'enable' } else { 'disable' }
    $dataAction = if ($Mobile -eq '1') { 'enable' } else { 'disable' }
    $null = Invoke-AdbChecked @('shell', 'svc', 'wifi', $wifiAction)
    $null = Invoke-AdbChecked @('shell', 'svc', 'data', $dataAction)
    return Wait-QaNetwork -Wifi $Wifi -Mobile $Mobile
}

function Convert-QaMarkers {
    param([string]$Logs, [int]$AndroidPid, [long]$StartedAt, [string]$Phase)
    $allowedActions = @('phase_start', 'account_access', 'course_create', 'editor_open',
        'draft_save', 'preview_open', 'preview_verified', 'submit_for_review', 'publish',
        'version_fork', 'catalog_refresh', 'contextual_reader_open',
        'offline_cached_read_and_queue', 'reconnect_persisted_queue', 'phase_passed')
    if ($Phase -notin $phases -or $AndroidPid -lt 1) { return }
    $pattern = '(?m)^\s*(?<epoch>\d+\.\d+)\s+(?<pid>\d+)\s+\d+\s+[VDIWEF]\s+flutter\s*:\s*DYNAMIC_QA phase=(?<phase>[a-z0-9_]+) action=(?<action>[a-z_]+)\s*$'
    foreach ($match in [regex]::Matches($Logs, $pattern)) {
        $epoch = [double]::Parse($match.Groups['epoch'].Value, [Globalization.CultureInfo]::InvariantCulture)
        if ($epoch -lt $StartedAt -or [int]$match.Groups['pid'].Value -ne $AndroidPid -or
            $match.Groups['phase'].Value -cne $Phase -or $match.Groups['action'].Value -cnotin $allowedActions) { continue }
        # Reconstruct only public diagnostic fields; never retain the source line.
        [ordered]@{ epoch = $match.Groups['epoch'].Value; pid = $AndroidPid;
            phase = $Phase; action = $match.Groups['action'].Value }
    }
}

function Register-QaDiagnosticError {
    param([string]$Phase, [string]$Operation)
    if ($diagnosticErrorKeys.Add("${Phase}:$Operation")) {
        $diagnosticErrors.Add([ordered]@{ phase = $Phase; operation = $Operation })
    }
}

function Save-QaMarkers {
    param([string]$Logs, [int]$AndroidPid, [long]$StartedAt, [string]$Phase)
    try {
        if ($Phase -notin $phases -or $AndroidPid -lt 1) { return }
        if (-not $markerRecords.ContainsKey($Phase)) {
            $markerRecords[$Phase] = [Collections.Generic.List[object]]::new()
            $markerKeys[$Phase] = [Collections.Generic.HashSet[string]]::new()
        }
        foreach ($record in @(Convert-QaMarkers -Logs $Logs -AndroidPid $AndroidPid -StartedAt $StartedAt -Phase $Phase)) {
            if ($markerKeys[$Phase].Add("$($record.epoch):$($record.pid):$($record.action)")) {
                $markerRecords[$Phase].Add($record)
            }
        }
        [ordered]@{ run_id = $RunId; phase = $Phase; pid = $AndroidPid; launch_epoch = $StartedAt;
            captured_at = (Get-Date).ToUniversalTime().ToString('o');
            markers = $markerRecords[$Phase].ToArray(); used_for_phase_approval = $false } |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDirectory "$Phase.markers.json") -Encoding utf8
    } catch { Register-QaDiagnosticError $Phase 'filter_or_write' }
}

function Capture-QaMarkers {
    param([int]$AndroidPid, [long]$StartedAt, [string]$Phase)
    if ($Phase -notin $phases -or $AndroidPid -lt 1) { return }
    try {
        # Buffered messages remain readable even if this known process exited.
        $logs = Invoke-AdbChecked @('logcat', "--pid=$AndroidPid", '-d', '-v', 'epoch', '-t', '2000')
    } catch {
        Register-QaDiagnosticError $Phase 'logcat_read'
        return
    }
    Save-QaMarkers -Logs $logs -AndroidPid $AndroidPid -StartedAt $StartedAt -Phase $Phase
}

function Get-QaDiagnosticSummary {
    $files = [ordered]@{}
    foreach ($phase in $phases) {
        if (-not $markerRecords.ContainsKey($phase)) { continue }
        $path = Join-Path $runDirectory "$phase.markers.json"
        $records = $markerRecords[$phase]
        $hash = $null
        try { $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
        catch { Register-QaDiagnosticError $phase 'marker_file_hash' }
        $files[$phase] = [ordered]@{ file = "$phase.markers.json"; sha256 = $hash;
            marker_count = $records.Count; last_marker = $(if ($records.Count) { $records[$records.Count - 1] } else { $null }) }
    }
    return [ordered]@{ used_for_phase_approval = $false; files = $files;
        capture_errors = $diagnosticErrors.ToArray();
        limitation = 'Only observed PID markers since launch; missing or rotated buffer entries are not inferred.' }
}

function Wait-VmService {
    param([int]$AndroidPid, [long]$StartedAt)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($watch.Elapsed.TotalSeconds -lt 45) {
            $logs = Invoke-AdbChecked @('logcat', "--pid=$AndroidPid", '-d', '-v', 'epoch', '-t', '2000')
            Save-QaMarkers -Logs $logs -AndroidPid $AndroidPid -StartedAt $StartedAt -Phase $attemptedPhase
            if ((Get-QaPid) -ne $AndroidPid) { throw 'QA process exited or changed before driver attachment.' }
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
    } finally { $watch.Stop() }
}

function Get-SourceHashes {
    $hashes = [ordered]@{}
    $sources = @(Get-ChildItem -LiteralPath (Join-Path $AppRoot 'lib') -Recurse -File -Filter '*.dart')
    foreach ($relative in @($target, $driver, 'pubspec.yaml', 'pubspec.lock',
            'android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml')) {
        $sources += Get-Item -LiteralPath (Join-Path $AppRoot $relative)
    }
    foreach ($file in @($sources | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($AppRoot, $file.FullName).Replace('\', '/')
        $hashes["cartilhas_app/$relative"] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    foreach ($relative in @('tooling/test_dynamic_learning_android.ps1', 'api/ops/bootstrap_dynamic_learning_qa.py',
            'api/ops/prepare_dynamic_learning_qa.py', 'api/ops/verify_cloud_context_isolation.py',
            'api/ops/seed_context_android.py', 'api/app/auth.py', 'api/app/config.py',
            'api/app/database.py', 'api/app/models.py', 'api/app/context_memberships.py',
            'api/app/learning_context.py', 'api/pyproject.toml', 'api/uv.lock')) {
        $hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $workspace $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return $hashes
}

function Assert-SourceHashes {
    if ((Get-SourceHashes | ConvertTo-Json -Depth 4 -Compress) -ne $sourceSnapshot) {
        throw 'Sources changed during the gate; preserve this run for diagnosis.'
    }
    if ((Get-FileHash -LiteralPath $DefinesFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceDefinesSha256) {
        throw 'Original operational configuration changed; preserve this run for diagnosis.'
    }
}

function ConvertTo-CanonicalValue {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($name in @($Value.Keys | Sort-Object)) { $result[$name] = ConvertTo-CanonicalValue $Value[$name] }
        return $result
    }
    if ($Value.GetType() -eq [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($name in @($Value.PSObject.Properties.Name | Sort-Object)) { $result[$name] = ConvertTo-CanonicalValue $Value.$name }
        return $result
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = [Collections.Generic.List[object]]::new()
        foreach ($item in $Value) { $items.Add((ConvertTo-CanonicalValue $item)) }
        return ,$items.ToArray()
    }
    return $Value
}

function Assert-JsonEqual {
    param($Expected, $Actual, [string]$Boundary)
    $expectedJson = ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $Expected) -Depth 60 -Compress
    $actualJson = ConvertTo-Json -InputObject (ConvertTo-CanonicalValue $Actual) -Depth 60 -Compress
    if ($expectedJson -cne $actualJson) { throw "Exact JSON mismatch at $Boundary." }
}

function Save-RunState {
    param([string]$Status)
    [ordered]@{
        run_id = $RunId
        course_id = $courseId
        status = $Status
        boundary = $script:boundary
        attempted_phase = $script:attemptedPhase
        last_verified_phase = $script:lastVerifiedPhase
        verified_phases = @($reports | ForEach-Object { $_.report.phase })
        verified_host_hooks = @($hostReports | ForEach-Object { $_.phase })
        apk_sha256 = $script:apkHash
        checkpoint_may_have_advanced = ($script:attemptedPhase -and $script:attemptedPhase -ne $script:lastVerifiedPhase)
        automatic_resume = $false
        next_phase_assumed = $false
        updated_at = (Get-Date).ToUniversalTime().ToString('o')
        cleanup_errors = $cleanupErrors.ToArray()
        diagnostic_capture_errors = $diagnosticErrors.ToArray()
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDirectory 'run-state.json') -Encoding utf8
}

function Invoke-NativeBounded {
    param([string]$Executable, [string[]]$CommandArgs, [string]$Name,
        [int]$TimeoutSeconds, [string]$WorkingDirectory)
    $invocation = Join-Path $runDirectory "$Name.invocation.json"
    [ordered]@{ executable = $Executable; arguments = $CommandArgs } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $invocation -Encoding utf8
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $PSHOME 'pwsh.exe'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.WorkingDirectory = $WorkingDirectory
    foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $nativeWrapper, '-InvocationPath', $invocation)) {
        $start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $startedProcess = $false
    try {
        if (-not $process.Start()) { throw 'Could not start the bounded QA tool.' }
        $startedProcess = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(1000)) {
            if ($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
                $timedOut = $true
                $process.Kill($true)
                if (-not $process.WaitForExit(10000)) { throw 'Timed out stopping the owned QA process tree.' }
                break
            }
        }
        $out = $stdout.GetAwaiter().GetResult()
        $err = $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $runDirectory "$Name.log"), $out + "`n" + $err)
        if ($timedOut) { throw "QA step $Name exceeded its deadline; no automatic retry." }
        if ($process.ExitCode -ne 0) { throw "QA step $Name failed (exit $($process.ExitCode)); inspect its retained log." }
        return [math]::Round($watch.Elapsed.TotalSeconds, 3)
    } finally {
        $watch.Stop()
        if ($startedProcess -and -not $process.HasExited) {
            $process.Kill($true)
            if (-not $process.WaitForExit(10000)) { throw 'Owned QA process tree did not stop during cleanup.' }
        }
        $process.Dispose()
    }
}

function Invoke-HostHook {
    param([string]$Phase)
    $script:boundary = "host_$Phase"
    Save-RunState 'RUNNING'
    Assert-SourceHashes
    $output = Join-Path $workspace "docs/production/evidence/dynamic-learning-$RunId-$($Phase.Replace('_', '-')).json"
    if (Test-Path -LiteralPath $output) { throw 'Host evidence already exists; never overwrite a hook.' }
    $arguments = @('-m', 'ops.bootstrap_dynamic_learning_qa', '--phase', $Phase, '--run-id', $RunId,
        '--defines', $operationalDefines, '--runtime-json', $RuntimeFile,
        '--output-state', $hostStatePath, '--output-evidence', $output, '--execute')
    $seconds = Invoke-NativeBounded -Executable $python -CommandArgs $arguments -Name "host-$Phase" `
        -TimeoutSeconds 180 -WorkingDirectory (Join-Path $workspace 'api')
    if (-not (Test-Path -LiteralPath $output)) { throw 'Host hook produced no evidence.' }
    $record = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $expectedStatus = switch ($Phase) {
        'before_android' { 'baseline_captured' }
        'after_android' { 'history_preservation_passed' }
        default { 'bootstrap_passed' }
    }
    if ($record.status -ne $expectedStatus -or $record.phase -ne $Phase -or
        $record.run_id -ne $RunId -or $record.api_base -ne $apiBase) {
        throw 'Host hook evidence does not match the approved phase/target.'
    }
    $state = Get-Content -LiteralPath $hostStatePath -Raw | ConvertFrom-Json
    if ($state.run_id -ne $RunId -or $state.api_base -ne $apiBase -or
        $state.course_id -ne $courseId -or $state.program_id -ne $configuration.QA_DYNAMIC_PROGRAM_ID -or
        $state.last_completed_phase -ne $Phase -or $state.baseline_sha256 -ne $record.baseline_sha256) {
        throw 'Host state must belong to this exact run/course before Android advances.'
    }
    $hostReports.Add([ordered]@{
        phase = $Phase
        duration_seconds = $seconds
        evidence_path = [IO.Path]::GetRelativePath($workspace, $output).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
        report = $record
    })
}

# Validate local intent/evidence before reading device state or writing any files.
foreach ($executable in @($Flutter, $Adb, $python, (Join-Path $PSHOME 'pwsh.exe'))) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Configured QA tool missing.' }
}
$AppRoot = (Resolve-Path -LiteralPath $AppRoot).Path
$DefinesFile = (Resolve-Path -LiteralPath $DefinesFile).Path
$RuntimeFile = (Resolve-Path -LiteralPath $RuntimeFile).Path
$temporaryRoot = [IO.Path]::GetFullPath((Join-Path $workspace 'tmp')) + [IO.Path]::DirectorySeparatorChar
foreach ($inputPath in @($DefinesFile, $RuntimeFile)) {
    if (-not $inputPath.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Operational configuration must remain under ignored repo/tmp.' }
    & git -C $workspace check-ignore -q -- $inputPath
    if ($LASTEXITCODE -ne 0) { throw 'Operational configuration must be ignored by Git.' }
}
$EvidenceFile = [IO.Path]::GetFullPath($EvidenceFile)
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $workspace 'docs/production/evidence')) + [IO.Path]::DirectorySeparatorChar
if (-not $EvidenceFile.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetExtension($EvidenceFile) -ne '.json' -or (Test-Path -LiteralPath $EvidenceFile)) {
    throw 'Use a new sanitized JSON evidence file under docs/production/evidence.'
}
if (Test-Path -LiteralPath $runDirectory) { throw 'Run ID already exists; no rerun/reset is supported.' }
$configuration = Get-Content -LiteralPath $DefinesFile -Raw | ConvertFrom-Json
$sourceConfiguration = $configuration
$sourceDefinesSha256 = (Get-FileHash -LiteralPath $DefinesFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($configuration.TUTOR_ENVIRONMENT -ne 'staging' -or $configuration.TUTOR_API_URL -ne $apiBase -or
    $configuration.TUTOR_STAGING_API_URL -ne $apiBase -or
    "$($configuration.LEARNING_CONTEXT_ENABLED)".ToLowerInvariant() -ne 'true' -or
    "$($configuration.DURABLE_LEARNING_OUTBOX_ENABLED)".ToLowerInvariant() -ne 'true' -or
    $configuration.QA_DYNAMIC_PROGRAM_ID -ne 'qa-dynamic-program' -or
    $configuration.QA_DYNAMIC_COURSE_ID -ne 'qa-dynamic-course' -or $configuration.TUTOR_GATEWAY_URL) {
    throw 'Expected the exact isolated cloud staging target, flags and synthetic dynamic fixture.'
}
# Derive only this run's course in a separate host-only configuration. The source
# actor fixture and its historical preparation evidence are never overwritten.
$operationalConfiguration = [ordered]@{}
foreach ($key in @('TUTOR_ENVIRONMENT', 'TUTOR_API_URL', 'TUTOR_STAGING_API_URL',
        'LEARNING_CONTEXT_ENABLED', 'DURABLE_LEARNING_OUTBOX_ENABLED', 'QA_DYNAMIC_PROGRAM_ID')) {
    $operationalConfiguration[$key] = $configuration.$key
}
$operationalConfiguration['QA_DYNAMIC_COURSE_ID'] = $courseId
foreach ($persona in @('AUTHOR', 'PUBLISHER', 'LEARNER', 'OPERATOR')) {
    foreach ($suffix in @('ID', 'CPF', 'PASSWORD')) {
        $key = "QA_DYNAMIC_${persona}_$suffix"
        $operationalConfiguration[$key] = $configuration.$key
    }
}
$configuration = [pscustomobject]$operationalConfiguration
$appConfiguration = [ordered]@{}
foreach ($key in @('TUTOR_ENVIRONMENT', 'TUTOR_API_URL', 'TUTOR_STAGING_API_URL',
        'LEARNING_CONTEXT_ENABLED', 'DURABLE_LEARNING_OUTBOX_ENABLED', 'QA_DYNAMIC_PROGRAM_ID', 'QA_DYNAMIC_COURSE_ID')) {
    $appConfiguration[$key] = $configuration.$key
}
$expectedCpfs = [ordered]@{ AUTHOR = '79000000114'; PUBLISHER = '79000000203'; LEARNER = '79000000386' }
$actorIds = [Collections.Generic.HashSet[string]]::new()
foreach ($persona in $expectedCpfs.Keys) {
    $id = $configuration.("QA_DYNAMIC_${persona}_ID")
    $cpf = $configuration.("QA_DYNAMIC_${persona}_CPF")
    $password = $configuration.("QA_DYNAMIC_${persona}_PASSWORD")
    if (-not $id -or -not $actorIds.Add($id) -or $cpf -ne $expectedCpfs[$persona] -or
        [string]::IsNullOrWhiteSpace($password) -or $password.Length -lt 12) { throw 'Synthetic Android identity configuration is invalid.' }
    foreach ($suffix in @('ID', 'CPF', 'PASSWORD')) {
        $key = "QA_DYNAMIC_${persona}_$suffix"
        $appConfiguration[$key] = $configuration.$key
    }
}
$appConfiguration['DYNAMIC_QA_RUN_ID'] = $RunId
if ($appConfiguration.Count -ne 17 -or @($appConfiguration.Keys | Where-Object { $_ -match 'OPERATOR' }).Count -ne 0) {
    throw 'APK configuration must contain only the explicit three-persona whitelist.'
}
$gatePath = Join-Path $workspace 'docs/production/evidence/wave1-acceptance.json'
$fixturePath = Join-Path $workspace 'docs/production/evidence/cloud-dynamic-learning-fixture.json'
$gate = Get-Content -LiteralPath $gatePath -Raw | ConvertFrom-Json
$fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
$gateHash = (Get-FileHash -LiteralPath $gatePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($gate.status -ne 'WAVE1_FUNCTIONAL_STAGING_PASSED' -or $gate.next_wave_allowed -ne 2 -or
    $gate.api_url -ne $apiBase -or $fixture.status -ne 'fixture_prepared' -or
    $fixture.api_base -ne $apiBase -or $fixture.course_absent -ne $true -or
    $fixture.program_id -ne $configuration.QA_DYNAMIC_PROGRAM_ID -or
    $fixture.course_id -ne $sourceConfiguration.QA_DYNAMIC_COURSE_ID -or $fixture.wave1_gate_sha256 -ne $gateHash) {
    throw 'Approved Wave 1 and the original prepared actor fixture are required.'
}
foreach ($property in $gate.evidence_sha256.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath (Join-Path $workspace $property.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) {
        throw 'An approved Wave 1 evidence file changed.'
    }
}
$sourceHashes = Get-SourceHashes
$sourceSnapshot = $sourceHashes | ConvertTo-Json -Depth 4 -Compress
$runtimeIdentity = [ordered]@{
    python = [IO.Path]::GetRelativePath($workspace, $python).Replace('\', '/')
    python_executable_sha256 = (Get-FileHash -LiteralPath $python -Algorithm SHA256).Hash.ToLowerInvariant()
    environment_metadata_sha256 = (Get-FileHash -LiteralPath (Join-Path $workspace 'tmp/context-cloud-locked-env/pyvenv.cfg') -Algorithm SHA256).Hash.ToLowerInvariant()
    uv_lock_sha256 = $sourceHashes['api/uv.lock']
    pyproject_sha256 = $sourceHashes['api/pyproject.toml']
}
if ((Invoke-AdbChecked @('get-state')) -ne 'device' -or
    (Invoke-AdbChecked @('shell', 'getprop', 'ro.kernel.qemu')) -ne '1') { throw 'Only the approved running QA emulator is allowed.' }
$beforeInstall = Get-InstalledIdentity
$initialPid = Get-QaPid
$initialNetwork = Get-QaNetwork
if ($initialNetwork.wifi -notin @('0', '1') -or $initialNetwork.mobile -notin @('0', '1') -or
    ($initialNetwork.wifi -ne '1' -and $initialNetwork.mobile -ne '1')) {
    throw 'The QA emulator must start online with readable network settings.'
}
$sdkRoot = Split-Path (Split-Path $Adb -Parent) -Parent
$buildTools = @(Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory |
    Where-Object Name -Match '^\d+\.\d+\.\d+$' | Sort-Object { [version]$_.Name } -Descending)
if ($buildTools.Count -eq 0) { throw 'Android manifest inspection tool missing.' }
$aapt = Join-Path $buildTools[0].FullName 'aapt.exe'
if (-not (Test-Path -LiteralPath $aapt)) { throw 'Android manifest inspection tool missing.' }
$null = New-Item -ItemType Directory -Path $runDirectory
$appDefines = Join-Path $runDirectory 'app-defines.json'
$operationalDefines = Join-Path $runDirectory 'host-defines.json'
foreach ($output in @($appDefines, $operationalDefines)) {
    & git -C $workspace check-ignore -q -- $output
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic configuration output must be ignored by Git.' }
}
$operationalConfiguration | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $operationalDefines -Encoding utf8
$appConfiguration | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $appDefines -Encoding utf8
Assert-SourceHashes
$hostStatePath = Join-Path $runDirectory 'host-state.json'
$nativeWrapper = Join-Path $runDirectory 'invoke-native.ps1'
@'
param([string]$InvocationPath)
$ErrorActionPreference = 'Stop'
$invocation = Get-Content -LiteralPath $InvocationPath -Raw | ConvertFrom-Json
$arguments = @($invocation.arguments)
try {
    $global:LASTEXITCODE = 0
    & $invocation.executable @arguments
    exit $LASTEXITCODE
} catch {
    Write-Error 'The bounded QA tool failed; configuration values are omitted.'
    exit 1
}
'@ | Set-Content -LiteralPath $nativeWrapper -Encoding utf8
$ownedForwards = [Collections.Generic.List[string]]::new()
$reports = [Collections.Generic.List[object]]::new()
$hostReports = [Collections.Generic.List[object]]::new()
$cleanupErrors = [Collections.Generic.List[string]]::new()
$diagnosticErrors = [Collections.Generic.List[object]]::new()
$diagnosticErrorKeys = [Collections.Generic.HashSet[string]]::new()
$markerRecords = @{}
$markerKeys = @{}
$diagnosticPid = $null
$diagnosticStartedAt = 0L
$diagnosticPhase = $null
$environmentNames = @('TDS_QA_DYNAMIC_REPORT_PATH', 'TDS_QA_DYNAMIC_RUN_ID', 'TDS_QA_DYNAMIC_EXPECTED_PHASE')
$oldEnvironment = @{}
foreach ($name in $environmentNames) { $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$boundary = 'before_android'
$attemptedPhase = $null
$lastVerifiedPhase = $null
$apkHash = $null
$failure = $null
$candidate = $null
$runWatch = [Diagnostics.Stopwatch]::StartNew()
try {
    Save-RunState 'RUNNING'
    Stop-QaProcess
    Invoke-HostHook 'before_android'
    $boundary = 'build'
    Save-RunState 'RUNNING'
    Assert-SourceHashes
    Write-Host 'Building the single approved QA APK.'
    $buildArguments = @('build', 'apk', '--debug', '--no-pub', '--target', $target,
        "--dart-define-from-file=$appDefines", '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false')
    $buildSeconds = Invoke-NativeBounded -Executable $Flutter -CommandArgs $buildArguments -Name 'build' `
        -TimeoutSeconds 600 -WorkingDirectory $AppRoot
    $apk = Join-Path $AppRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    $apkHash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    $badging = (& $aapt dump badging $apk 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect built QA APK.' }
    $packageMatch = [regex]::Match($badging, "(?m)^package: name='([^']+)'")
    $activityMatch = [regex]::Match($badging, "(?m)^launchable-activity: name='([^']+)'")
    if ($packageMatch.Groups[1].Value -ne $package -or
        $activityMatch.Groups[1].Value -ne 'com.tutortds_cartilhas.MainActivity' -or
        $badging -notmatch '(?m)^application-debuggable') { throw 'Refusing any APK except the approved debuggable .dev application.' }
    $boundary = 'single_install'
    Save-RunState 'RUNNING'
    Stop-QaProcess
    $installResult = Invoke-AdbChecked @('install', '-t', '-r', $apk)
    if ($installResult -notmatch '(?m)^Success\s*$' -or $installResult -match 'Failure') { throw 'QA APK installation failed; no uninstall fallback is allowed.' }
    $installed = Get-InstalledIdentity
    if ($installed.sha256 -ne $apkHash -or $installed.first_install_time -ne $beforeInstall.first_install_time) {
        throw 'Installed APK differs or original installation continuity was lost.'
    }
    $null = Set-QaNetwork -Wifi '1' -Mobile '1'
    $seenPids = [Collections.Generic.HashSet[int]]::new()
    if ($null -ne $initialPid) { $null = $seenPids.Add($initialPid) }
    foreach ($phase in $phases) {
        if ($runWatch.Elapsed.TotalMinutes -gt 150) { throw 'The complete gate exceeded its bounded execution window.' }
        $attemptedPhase = $phase
        $diagnosticPid = $null
        $diagnosticPhase = $phase
        $boundary = "android_$phase"
        Save-RunState 'RUNNING'
        Assert-SourceHashes
        Stop-QaProcess
        $null = Assert-InstalledIdentity $installed
        if ($phase -eq 'learner_offline') { $null = Set-QaNetwork -Wifi '0' -Mobile '0' }
        if ($phase -eq 'learner_reconnect') { $null = Set-QaNetwork -Wifi '1' -Mobile '1' }
        $requestedNetwork = if ($phase -eq 'learner_offline') { '0' } else { '1' }
        $phaseNetwork = Wait-QaNetwork -Wifi $requestedNetwork -Mobile $requestedNetwork
        $startedAt = [long](Invoke-AdbChecked @('shell', 'date', '+%s'))
        $started = Invoke-AdbChecked @('shell', 'am', 'start', '-W', '-n',
            "$package/$($activityMatch.Groups[1].Value)", '-a', 'android.intent.action.MAIN',
            '-c', 'android.intent.category.LAUNCHER', '--ez', 'enable-checked-mode', 'true',
            '--ez', 'verify-entry-points', 'true')
        if ($started -match 'Error:|Exception') { throw 'QA activity did not start.' }
        $androidPid = Get-QaPid
        if ($null -eq $androidPid -or -not $seenPids.Add($androidPid)) { throw 'Expected a distinct new QA process.' }
        $diagnosticPid = $androidPid
        $diagnosticStartedAt = $startedAt
        $remoteVm = Wait-VmService -AndroidPid $androidPid -StartedAt $startedAt
        $hostPort = Invoke-AdbChecked @('forward', 'tcp:0', "tcp:$($remoteVm.Port)")
        if ($hostPort -notmatch '^\d+$') { throw 'ADB did not allocate an owned local forward.' }
        $forward = "tcp:$hostPort"
        $ownedForwards.Add($forward)
        $localVm = [UriBuilder]::new($remoteVm)
        $localVm.Host = '127.0.0.1'
        $localVm.Port = [int]$hostPort
        $reportPath = Join-Path $runDirectory "$phase.json"
        [Environment]::SetEnvironmentVariable('TDS_QA_DYNAMIC_REPORT_PATH', $reportPath, 'Process')
        [Environment]::SetEnvironmentVariable('TDS_QA_DYNAMIC_RUN_ID', $RunId, 'Process')
        [Environment]::SetEnvironmentVariable('TDS_QA_DYNAMIC_EXPECTED_PHASE', $phase, 'Process')
        Write-Host "Validating installed APK: $phase"
        $driveArguments = @('drive', '--debug', '--no-pub', '--no-dds', '-d', $Device,
            '--driver', $driver, '--target', $target, "--use-existing-app=$($localVm.Uri.AbsoluteUri)", '--keep-app-running')
        try {
            $phaseSeconds = Invoke-NativeBounded -Executable $Flutter -CommandArgs $driveArguments -Name $phase `
                -TimeoutSeconds 1020 -WorkingDirectory $AppRoot
        } finally {
            Capture-QaMarkers -AndroidPid $androidPid -StartedAt $startedAt -Phase $phase
        }
        if (-not (Test-Path -LiteralPath $reportPath)) { throw 'Driver produced no phase report; checkpoint may already have advanced.' }
        $phaseReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        if ($phaseReport.status -ne 'passed' -or $phaseReport.report.phase -ne $phase -or
            $phaseReport.report.run_id -ne $RunId -or $phaseReport.report.pid -ne $androidPid -or
            $phaseReport.report.completed_phase -ne $phase -or
            $phaseReport.report.course_id -ne $configuration.QA_DYNAMIC_COURSE_ID -or
            $phaseReport.report.program_id -ne $configuration.QA_DYNAMIC_PROGRAM_ID -or
            $phaseReport.report.checkpoint.run_id -ne $RunId -or
            $phaseReport.report.checkpoint.completed_phase -ne $phase -or
            $phaseReport.report.checkpoint.course_id -ne $configuration.QA_DYNAMIC_COURSE_ID -or
            $phaseReport.report.checkpoint.program_id -ne $configuration.QA_DYNAMIC_PROGRAM_ID) {
            throw 'Driver report does not match the actual phase/process/checkpoint.'
        }
        if ($phase -eq 'learner_offline' -and ($phaseReport.report.network_unreachable -ne $true -or
            $phaseReport.report.pending_visible -ne $true -or @($phaseReport.report.checkpoint.offline_events).Count -eq 0)) {
            throw 'Offline phase must prove unavailable network, visible pending feedback and durable events.'
        }
        $expectedPids = @($reports | ForEach-Object { $_.report.pid }) + @($androidPid)
        Assert-JsonEqual $expectedPids $phaseReport.report.checkpoint.pids 'ordered checkpoint process lineage'
        $identity = Assert-InstalledIdentity $installed
        Assert-SourceHashes
        $reports.Add([ordered]@{
            status = $phaseReport.status
            report = $phaseReport.report
            duration_seconds = $phaseSeconds
            installed = $identity
            network_settings = $phaseNetwork
            driver_report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
            driver_log_sha256 = (Get-FileHash -LiteralPath (Join-Path $runDirectory "$phase.log") -Algorithm SHA256).Hash.ToLowerInvariant()
        })
        $lastVerifiedPhase = $phase
        Save-RunState 'RUNNING'
        $null = Invoke-AdbChecked @('forward', '--remove', $forward)
        $null = $ownedForwards.Remove($forward)
        Stop-QaProcess
        if ($phase -eq 'publisher_v1') { Invoke-HostHook 'after_v1' }
        if ($phase -eq 'publisher_v2') { Invoke-HostHook 'after_v2' }
    }
    Invoke-HostHook 'after_android'
    $boundary = 'final_android_host_parity'
    $finalHostState = Get-Content -LiteralPath $hostStatePath -Raw | ConvertFrom-Json
    $finalAndroid = $reports[$reports.Count - 1].report
    if ($reports.Count -ne 8 -or $hostReports.Count -ne 4 -or
        $finalHostState.run_id -ne $RunId -or $finalHostState.last_completed_phase -ne 'after_android' -or
        $finalHostState.api_base -ne $apiBase -or $finalHostState.course_id -ne $configuration.QA_DYNAMIC_COURSE_ID -or
        $finalHostState.program_id -ne $configuration.QA_DYNAMIC_PROGRAM_ID -or
        $null -eq $finalAndroid.v1_progress -or $null -eq $finalAndroid.v2_progress) {
        throw 'Complete Android/host reports and final progress are required.'
    }
    Assert-JsonEqual $finalHostState $hostReports[$hostReports.Count - 1].report.state 'host saved state/evidence'
    Assert-JsonEqual $finalHostState.v1.progress $finalAndroid.v1_progress 'final v1 progress host/Android'
    Assert-JsonEqual $finalHostState.v2.progress $finalAndroid.v2_progress 'final v2 progress host/Android'
    Assert-JsonEqual $finalAndroid.v1_progress $finalAndroid.checkpoint.final_progress 'v1 progress/checkpoint'
    Assert-JsonEqual $finalAndroid.v2_progress $finalAndroid.checkpoint.final_v2_progress 'v2 progress/checkpoint'
    Assert-JsonEqual $finalHostState.v1.context $finalAndroid.checkpoint.context_v1 'final v1 context host/Android'
    Assert-JsonEqual $finalHostState.v2.context $finalAndroid.checkpoint.context_v2 'final v2 context host/Android'
    foreach ($number in @(1, 2)) {
        $edition = "v$number"
        $hostEdition = $finalHostState.$edition
        $appEdition = $finalAndroid.checkpoint.$edition
        if ($null -eq $appEdition -or $appEdition.version_id -ne $hostEdition.version_id -or
            $appEdition.version_number -ne $hostEdition.version_number -or
            $appEdition.content_sha256 -ne $hostEdition.content_sha256 -or
            $finalAndroid.checkpoint.("cohort_v$number") -ne $hostEdition.class_id) {
            throw 'Final Android/host edition, immutable content or classroom lineage differs.'
        }
    }
    $initialHost = $hostReports[0].report
    $finalHost = $hostReports[$hostReports.Count - 1].report
    if ($initialHost.course_absent_in_database_and_catalog -ne $true -or
        $initialHost.baseline_sha256 -ne $finalHost.baseline_sha256 -or
        $initialHost.baseline_event_count -ne $finalHost.initial_events_preserved -or
        $initialHost.initial_core_record_count -ne $finalHost.initial_core_records_preserved -or
        $initialHost.original_context_sha256 -ne $finalHost.original_context_sha256 -or
        $initialHost.original_progress_percent -ne $finalHost.original_progress_percent) {
        throw 'Before/after host history and original Wave 1 evidence do not agree.'
    }
    Assert-SourceHashes
    $finalIdentity = Assert-InstalledIdentity $installed
    $candidate = [ordered]@{
        status = 'DYNAMIC_LEARNING_ANDROID_PATH_PASSED'
        verified_at = (Get-Date).ToUniversalTime().ToString('o')
        run_id = $RunId
        course_id = $courseId
        program_id = $configuration.QA_DYNAMIC_PROGRAM_ID
        device = $Device
        app_package = $package
        api_url = $apiBase
        golden_path = 'course_publication_path'
        wave = '2A'
        production_ready = $false
        build_count = 1
        install_count = 1
        build_seconds = $buildSeconds
        apk_sha256 = $apkHash
        before_install = $beforeInstall
        installed = $installed
        after_all_phases = $finalIdentity
        separate_processes = $true
        all_phases_in_this_run = ($reports.Count -eq 8)
        automatic_resume = $false
        original_operational_configuration_unchanged = $true
        source_sha256 = $sourceHashes
        source_hash_format = 'SHA256 of raw local file bytes'
        host_runtime = $runtimeIdentity
        wave1_gate_sha256 = $gateHash
        fixture_sha256 = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash.ToLowerInvariant()
        phases = $reports.ToArray()
        host_hooks = $hostReports.ToArray()
        exact_final_android_host_progress = $true
        exact_final_android_host_contexts = $true
        exact_final_android_host_editions = $true
        limits = @('Synthetic staging emulator and instrumented debug APK only; no release claim.',
            'Wave 2A publication/read/cache flow; contextual ActivityAttempt belongs to the subsequent slice.',
            'Existing app/user/outbox data and failed-run artifacts are preserved; no automatic resume.')
    }
} catch {
    $failure = $_
} finally {
    $runWatch.Stop()
    if ($null -ne $diagnosticPid) {
        Capture-QaMarkers -AndroidPid $diagnosticPid -StartedAt $diagnosticStartedAt -Phase $diagnosticPhase
    }
    foreach ($forward in @($ownedForwards)) {
        try { $null = Invoke-AdbChecked @('forward', '--remove', $forward) }
        catch { $cleanupErrors.Add("forward:$forward") }
    }
    try { Stop-QaProcess } catch { $cleanupErrors.Add('QA process could not be stopped') }
    try { $null = Set-QaNetwork -Wifi $initialNetwork.wifi -Mobile $initialNetwork.mobile }
    catch { $cleanupErrors.Add('Initial network settings could not be restored/verified') }
    foreach ($name in $environmentNames) {
        try { [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process') }
        catch { $cleanupErrors.Add("environment:$name") }
    }
    Save-RunState $(if ($null -eq $failure -and $cleanupErrors.Count -eq 0 -and $null -ne $candidate) { 'VERIFIED_AWAITING_EVIDENCE_WRITE' } else { 'FAILED_PRESERVED_FOR_DIAGNOSIS' })
}
if ($null -ne $failure) {
    throw "Gate failed at $boundary. No retry/reset performed; preserve $runDirectory. $($failure.Exception.Message)"
}
if ($cleanupErrors.Count -ne 0 -or $null -eq $candidate) { throw 'Gate cannot pass: cleanup or complete evidence is missing. Inspect run-state.json.' }
$candidate['cleanup'] = [ordered]@{ verified = $true; qa_process_stopped = $true; owned_forwards_removed = $true; network_restored_to = $initialNetwork }
$candidate['duration_seconds'] = [math]::Round($runWatch.Elapsed.TotalSeconds, 3)
$candidate['diagnostics'] = Get-QaDiagnosticSummary
$candidate | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $EvidenceFile -Encoding utf8
$candidate | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $runDirectory 'evidence.json') -Encoding utf8
Save-RunState 'PASSED'
Write-Host "Dynamic learning evidence: $EvidenceFile"
