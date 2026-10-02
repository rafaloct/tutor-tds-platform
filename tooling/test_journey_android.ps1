param(
    [switch]$Execute,
    [ValidateSet('journey','baseline')][string]$Slice = 'journey',
    [ValidatePattern('^[A-Za-z0-9-]+$')][string]$Device = 'ZT6HPRHQHATSEQPR',
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RunId = ([guid]::NewGuid().ToString('N')),
    [string]$DefinesFile,
    [string]$Flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat',
    [string]$Adb = 'C:/Users/Usuario/AppData/Local/Android/Sdk/platform-tools/adb.exe',
    [string]$AppRoot = 'C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa'
)
# Only .dev is updated. Original DEV APK is restored in finally without clearing
# data. The test protects prior session/preferences in secure storage, and never
# deletes queue/history. A failed checkpoint is retained, never auto-replayed.
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$package = 'com.tutortds_cartilhas.dev'
$phases = if ($Slice -eq 'baseline') { @('baseline') } else { @('online', 'offline', 'reconnect') }
$target = if ($Slice -eq 'baseline') { 'integration_test/journey_baseline_control_test.dart' } else { 'integration_test/journey_traceability_test.dart' }
$output = Join-Path $AppRoot "build/journey-android-$RunId"
if (-not $DefinesFile) { $DefinesFile = Join-Path $workspace 'tmp/journey-android-defines.json' }
if (-not $Execute) {
    [ordered]@{mode='PLAN_ONLY';device=$Device;package=$package;phases=$phases;run_id=$RunId;output=$output} | ConvertTo-Json
    return
}
function Adb-Checked([string[]]$CommandArgs) {
    $result = (& $Adb -s $Device @CommandArgs 2>&1 | ForEach-Object ToString) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "ADB failed at $($CommandArgs[0])" }
    return $result.Trim()
}
function Network-Set([string]$Wifi,[string]$Mobile) {
    $null = Adb-Checked @('shell','svc','wifi', $(if($Wifi -eq '1'){'enable'}else{'disable'}))
    $null = Adb-Checked @('shell','svc','data', $(if($Mobile -eq '1'){'enable'}else{'disable'}))
    Start-Sleep -Milliseconds 800
    if ((Adb-Checked @('shell','settings','get','global','wifi_on')) -ne $Wifi -or
        (Adb-Checked @('shell','settings','get','global','mobile_data')) -ne $Mobile) {
        throw 'Phone network state did not match requested phase'
    }
}
function Manifest-Check([string]$Apk, [bool]$RequireDebug = $true) {
    $sdk = Split-Path (Split-Path $Adb -Parent) -Parent
    $tools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory |
        Where-Object Name -Match '^\d+\.\d+\.\d+$' | Sort-Object { [version]$_.Name } -Descending
    $aapt = Join-Path @($tools)[0].FullName 'aapt.exe'
    $text = (& $aapt dump badging $Apk 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $text -notmatch "package: name='com.tutortds_cartilhas.dev'" -or
        ($RequireDebug -and $text -notmatch '(?m)^application-debuggable')) { throw 'Refusing non-DEV APK' }
}
$config = Get-Content -LiteralPath $DefinesFile -Raw | ConvertFrom-Json -AsHashtable
if ($config.TUTOR_ENVIRONMENT -ne 'staging' -or
    $config.TUTOR_API_URL -ne 'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api' -or
    $config.JOURNEY_TRACEABILITY_ENABLED -ne 'true' -or
    $config.DURABLE_LEARNING_OUTBOX_ENABLED -ne 'true' -or $config.TUTOR_GATEWAY_URL) {
    throw 'Only isolated journey staging with no gateway is allowed'
}
if (Test-Path -LiteralPath $output) { throw 'Run directory exists; inspect checkpoint, never auto-resume' }
$null = New-Item -ItemType Directory -Path $output
$config['JOURNEY_QA_RUN_ID'] = $RunId
$appDefines = Join-Path $output 'defines.json'
$config | ConvertTo-Json | Set-Content -LiteralPath $appDefines -Encoding utf8
$originalPath = Adb-Checked @('shell','pm','path',$package)
if ($originalPath -notmatch '^package:(/data/app/[A-Za-z0-9_./=+~\-]+/base\.apk)$') { throw 'Existing DEV APK must be identifiable' }
$remoteOriginal = $Matches[1]
$originalApk = Join-Path $output 'original-dev.apk'
$null = Adb-Checked @('pull',$remoteOriginal,$originalApk)
$originalHash = (Get-FileHash -LiteralPath $originalApk -Algorithm SHA256).Hash.ToLowerInvariant()
Manifest-Check $originalApk $false
$productionBefore = Adb-Checked @('shell','dumpsys','package','com.tutortds_cartilhas')
$productionIdentity = ($productionBefore -split "`n" | Where-Object {$_ -match 'versionCode=|versionName=|firstInstallTime=|lastUpdateTime='}) -join "`n"
$wifi = Adb-Checked @('shell','settings','get','global','wifi_on')
$mobile = Adb-Checked @('shell','settings','get','global','mobile_data')
if ($wifi -notin @('0','1') -or $mobile -notin @('0','1') -or ($wifi -eq '0' -and $mobile -eq '0')) { throw 'Phone must start online' }
$reports = [Collections.Generic.List[object]]::new()
$forwards = [Collections.Generic.List[string]]::new()
$seenPids = [Collections.Generic.HashSet[string]]::new()
$installed = $false
$failure = $null
$phase = 'build'
$hash = $null
try {
    Push-Location $AppRoot
    try {
        & $Flutter build apk --debug --no-pub "--target=$target" "--dart-define-from-file=$appDefines" --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false *> (Join-Path $output 'build.log')
        if ($LASTEXITCODE -ne 0) { throw 'Journey QA build failed' }
    } finally { Pop-Location }
    $apk = Join-Path $AppRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    Manifest-Check $apk
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host 'Instalando Tutor TDS DEV. Autorize a instalação USB no POCO, se aparecer.'
    $phase = 'install'
    $install = Adb-Checked @('install','-r','-t',$apk)
    if ($install -notmatch '(?m)^Success\s*$') { throw 'DEV installation failed; no uninstall fallback' }
    $installed = $true
    foreach ($phase in $phases) {
        $null = Adb-Checked @('shell','am','force-stop',$package)
        if ($phase -eq 'offline') { Network-Set '0' '0' } else { Network-Set $wifi $mobile }
        $started = [long](Adb-Checked @('shell','date','+%s'))
        $null = Adb-Checked @('shell','am','start','-W','-n',"$package/com.tutortds_cartilhas.MainActivity",
            '--ez','enable-checked-mode','true','--ez','verify-entry-points','true')
        $androidPid = Adb-Checked @('shell','pidof','-s',$package)
        if ($androidPid -notmatch '^\d+$' -or -not $seenPids.Add($androidPid)) { throw 'Expected distinct QA process' }
        $vm = $null
        $deadline = (Get-Date).AddSeconds(40)
        while ((Get-Date) -lt $deadline) {
            $logs = Adb-Checked @('logcat','-d','--pid',$androidPid,'-v','epoch','-t','150')
            foreach ($line in $logs -split "`n") {
                if ($line -match '^\s*(\d+\.\d+).*Dart VM service is listening on (http://127\.0\.0\.1:\d+/[A-Za-z0-9_=\-]+/)') {
                    if ([double]$Matches[1] -ge $started) { $vm = [Uri]$Matches[2] }
                }
            }
            if ($vm) { break }
            Start-Sleep -Milliseconds 400
        }
        if (-not $vm) { throw 'QA VM service unavailable' }
        $port = Adb-Checked @('forward','tcp:0',"tcp:$($vm.Port)")
        $forwards.Add("tcp:$port")
        $localVm = [UriBuilder]::new($vm); $localVm.Port = [int]$port
        $env:TDS_JOURNEY_REPORT = Join-Path $output "$phase.json"
        $env:TDS_JOURNEY_PHASE = $phase
        $env:TDS_JOURNEY_RUN = $RunId
        Write-Host "Validando POCO: $phase"
        Push-Location $AppRoot
        try {
            & $Flutter drive --debug --no-pub --no-dds -d $Device --driver=test_driver/journey_traceability_driver.dart "--target=$target" "--use-existing-app=$($localVm.Uri.AbsoluteUri)" --keep-app-running *> (Join-Path $output "$phase.log")
            if ($LASTEXITCODE -ne 0) { throw "Android phase failed: $phase; retain logs/checkpoint" }
        } finally { Pop-Location }
        $report = Get-Content -LiteralPath $env:TDS_JOURNEY_REPORT -Raw | ConvertFrom-Json
        if ($report.status -ne 'passed' -or $report.report.pid -ne [int]$androidPid) { throw 'Phase evidence does not match installed process' }
        $reports.Add($report)
    }
} catch { $failure = $_.Exception.Message
} finally {
    Network-Set $wifi $mobile
    $null = Adb-Checked @('shell','am','force-stop',$package)
    foreach ($forward in $forwards) { $null = Adb-Checked @('forward','--remove',$forward) }
    if ($installed) {
        $restore = Adb-Checked @('install','-r','-t',$originalApk)
        if ($restore -notmatch '(?m)^Success\s*$') { throw 'Original DEV APK restore failed; human support required' }
    }
    $productionAfter = Adb-Checked @('shell','dumpsys','package','com.tutortds_cartilhas')
    $afterIdentity = ($productionAfter -split "`n" | Where-Object {$_ -match 'versionCode=|versionName=|firstInstallTime=|lastUpdateTime='}) -join "`n"
    if ($afterIdentity -cne $productionIdentity) { throw 'Production identity changed unexpectedly' }
    [ordered]@{status=$(if($failure){'failed'}else{'passed'});run_id=$RunId;device=$Device;
        apk_sha256=$hash;original_dev_apk_sha256=$originalHash;phase=$phase;
        production_unchanged=$true;network_restored=$true;dev_binary_restored=$installed;
        reports=$reports.ToArray();failure=$failure} | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath (Join-Path $workspace $(if($Slice -eq 'baseline'){'docs/production/evidence/journey-baseline-android-2026-10-01.json'}else{'docs/production/evidence/journey-android-2026-10-01.json'})) -Encoding utf8
    foreach ($name in @('TDS_JOURNEY_REPORT','TDS_JOURNEY_PHASE','TDS_JOURNEY_RUN')) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
}
if ($failure) { throw $failure }
Write-Host 'Gate de rastreio Android concluído; produção preservada.'
