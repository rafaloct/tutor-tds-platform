param(
    [switch]$Execute,
    [switch]$ResumeInstall,
    [ValidatePattern('^install-resume(?:-[a-z0-9-]+)?$')][string]$InstallAttempt = 'install-resume',
    [ValidatePattern('^[a-f0-9]{32}$')][Parameter(Mandatory)][string]$RunId,
    [ValidateSet('ZT6HPRHQHATSEQPR')][string]$Device = 'ZT6HPRHQHATSEQPR'
)
# Fresh isolated package only. Preserve failed checkpoints and all other apps.
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$appRoot = 'C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa'
$flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat'
$adb = 'C:/Users/Usuario/AppData/Local/Android/Sdk/platform-tools/adb.exe'
$python = Join-Path $workspace 'tmp/context-cloud-locked-env/Scripts/python.exe'
$package = "com.tutortds_cartilhas.dev.dynamicqa.r$RunId"
$fixtureDir = Join-Path $workspace "tmp/classroom-access-$RunId"
$out = Join-Path $fixtureDir 'android'
$priorOut = $out
$evidenceName = "classroom-access-$RunId-android.json"
if ($ResumeInstall) {
    $out = Join-Path $fixtureDir "android-$InstallAttempt"
    $evidenceName = "classroom-access-$RunId-android-$InstallAttempt.json"
}
$target = 'integration_test/classroom_access_path_test.dart'
$driver = 'test_driver/classroom_access_driver.dart'
$phases = @('online','cold_offline','offline_restart','reconnect','wrong_account','revoked_online','revoked_offline','pdf')
if (-not $Execute) { [ordered]@{run_id=$RunId;device=$Device;package=$package;phases=$phases;remote_access=$false}|ConvertTo-Json; return }
function Adb([string[]]$Arguments) {
    $result = (& $adb -s $Device @Arguments 2>&1 | ForEach-Object ToString) -join "`n"
    $code = $LASTEXITCODE
    if ($Arguments[0] -eq 'install') { $result | Set-Content -LiteralPath (Join-Path $out 'install.log') -Encoding utf8 }
    if ($code -ne 0) { throw "ADB operation failed: $($Arguments[0])" }
    return $result.Trim()
}
function Identity([string]$Id) {
    $paths = Adb @('shell','pm','path',$Id)
    $hashes = @()
    foreach ($line in $paths -split "`n") {
        if ($line -notmatch '^package:(/data/app/[A-Za-z0-9_./=+~\-]+\.apk)$') { throw 'Unexpected APK path' }
        $hash = Adb @('shell','sha256sum',$Matches[1])
        if ($hash -notmatch '^([a-f0-9]{64})\s') { throw 'APK hash unavailable' }
        $hashes += $Matches[1]
    }
    $details = Adb @('shell','dumpsys','package',$Id)
    return [ordered]@{hashes=$hashes;metadata=@($details -split "`n"|Where-Object {$_ -match 'versionCode=|versionName=|firstInstallTime=|lastUpdateTime='}|ForEach-Object {$_.Trim()})}
}
function Network([string]$Wifi,[string]$Mobile) {
    $null=Adb @('shell','svc','wifi',$(if($Wifi -eq '1'){'enable'}else{'disable'}))
    $null=Adb @('shell','svc','data',$(if($Mobile -eq '1'){'enable'}else{'disable'}))
    Start-Sleep -Milliseconds 800
    if ((Adb @('shell','settings','get','global','wifi_on')) -ne $Wifi -or (Adb @('shell','settings','get','global','mobile_data')) -ne $Mobile) { throw 'Network state mismatch' }
}
function Bounded([string]$Executable,[string[]]$Arguments,[string]$Directory,[string]$Name,[int]$Seconds) {
    $inputPath=Join-Path $out "$Name.invocation.json"
    @{executable=$Executable;arguments=$Arguments;directory=$Directory}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $inputPath -Encoding utf8
    $psi=[Diagnostics.ProcessStartInfo]::new('pwsh')
    foreach($arg in @('-NoLogo','-NoProfile','-File',(Join-Path $out 'invoke.ps1'),$inputPath)){ $psi.ArgumentList.Add($arg) }
    $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($psi)
    $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
    try {
        if(-not $process.WaitForExit($Seconds*1000)){ $process.Kill($true); $process.WaitForExit(); throw "Timeout in $Name" }
        $code=$process.ExitCode
    } finally {
        ($stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult())|Set-Content -LiteralPath (Join-Path $out "$Name.log") -Encoding utf8
        $process.Dispose()
    }
    if($code -ne 0){throw "Failed: $Name; preserve run/logs"}
}
function Sources {
    $hashes=[ordered]@{}
    $files=@(Get-ChildItem -LiteralPath (Join-Path $appRoot 'lib') -Recurse -File -Filter '*.dart')
    foreach($relative in @($target,$driver,'android/app/build.gradle.kts','android/app/src/debug/AndroidManifest.xml','pubspec.lock')) { $files+=Get-Item -LiteralPath (Join-Path $appRoot $relative) }
    foreach($file in $files|Sort-Object FullName){$relative=[IO.Path]::GetRelativePath($appRoot,$file.FullName).Replace('\','/');$hashes["cartilhas_app/$relative"]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    foreach($relative in @('api/ops/qa_classroom_access.py','tooling/test_classroom_access_android.ps1')){$hashes[$relative]=(Get-FileHash -LiteralPath (Join-Path $workspace $relative) -Algorithm SHA256).Hash.ToLowerInvariant()}
    return $hashes
}
function State([string]$Status){@{status=$Status;run_id=$RunId;phase=$phase;verified_phases=@($reports|ForEach-Object {$_.report.phase});cleanup_errors=$cleanup.ToArray();updated_at=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'run-state.json') -Encoding utf8}
$config=Get-Content -LiteralPath (Join-Path $fixtureDir 'defines.json') -Raw|ConvertFrom-Json
$fixture=Get-Content -LiteralPath (Join-Path $fixtureDir 'fixture.json') -Raw|ConvertFrom-Json
if($fixture.status -ne 'prepared' -or $fixture.run_id -ne $RunId -or $config.QA_ACCESS_RUN_ID -ne $RunId -or $config.DYNAMIC_QA_RUN_ID -ne $RunId -or $config.TUTOR_API_URL -ne 'https://tutor-tds-staging.fastapicloud.dev' -or $config.TUTOR_API_URL -ne $config.TUTOR_STAGING_API_URL -or $config.TUTOR_GATEWAY_URL){throw 'Invalid isolated staging configuration'}
if(Test-Path -LiteralPath $out){throw 'Existing Android run; no automatic retry'}
if((Adb @('get-state')) -ne 'device' -or (Adb @('shell','getprop','ro.product.model')) -ne '2311DRK48G'){throw 'Approved physical phone required'}
if(Adb @('shell','pm','list','packages',$package)){throw 'QA package must be absent'}
$before=[ordered]@{play=(Identity 'com.tutortds_cartilhas');dev=(Identity 'com.tutortds_cartilhas.dev')}
$parentEvidence = $null
$parentHash = $null
if ($ResumeInstall) {
    $parentPath = Join-Path $workspace "docs/production/evidence/classroom-access-$RunId-android.json"
    $parentEvidence = Get-Content -LiteralPath $parentPath -Raw | ConvertFrom-Json
    $parentState = Get-Content -LiteralPath (Join-Path $priorOut 'run-state.json') -Raw | ConvertFrom-Json
    if ($parentEvidence.run_id -ne $RunId -or $parentEvidence.app_package -ne $package -or $parentEvidence.apk_sha256 -notmatch '^[a-f0-9]{64}$' -or $parentEvidence.status -ne 'failed_preserved' -or $parentEvidence.failure -ne 'ADB operation failed: install' -or $parentState.phase -ne 'install' -or $parentEvidence.reports.Count -ne 0 -or -not $parentEvidence.protected_apps_unchanged -or $parentEvidence.cleanup_errors.Count -ne 0) { throw 'Resume is restricted to an uninstalled, unstarted APK' }
    if (($before | ConvertTo-Json -Compress) -cne ($parentEvidence.protected_after | ConvertTo-Json -Compress)) { throw 'Protected apps changed since installation attempt' }
    $currentSources = Sources
    foreach ($entry in $parentEvidence.source_sha256.PSObject.Properties) {
        if ($entry.Name -ne 'tooling/test_classroom_access_android.ps1' -and $currentSources[$entry.Name] -cne $entry.Value) { throw "Source changed since build: $($entry.Name)" }
    }
    if ((Get-FileHash -LiteralPath (Join-Path $priorOut 'qa.apk') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $parentEvidence.apk_sha256) { throw 'Preserved APK changed' }
    $parentHash = (Get-FileHash -LiteralPath $parentPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$wifi=Adb @('shell','settings','get','global','wifi_on');$mobile=Adb @('shell','settings','get','global','mobile_data')
if($wifi -notin @('0','1') -or $mobile -notin @('0','1') -or ($wifi -eq '0' -and $mobile -eq '0')){throw 'Readable online network required'}
$null=New-Item -ItemType Directory -Path $out
@'
param([string]$InputPath)
$ErrorActionPreference='Stop'
$i=Get-Content -LiteralPath $InputPath -Raw|ConvertFrom-Json
Set-Location -LiteralPath $i.directory
& $i.executable @($i.arguments)
exit $LASTEXITCODE
'@|Set-Content -LiteralPath (Join-Path $out 'invoke.ps1') -Encoding utf8
$sources=Sources;$sourceJson=$sources|ConvertTo-Json -Compress
$definesHash=(Get-FileHash -LiteralPath (Join-Path $fixtureDir 'defines.json') -Algorithm SHA256).Hash
$reports=[Collections.Generic.List[object]]::new();$cleanup=[Collections.Generic.List[string]]::new();$forwards=[Collections.Generic.List[string]]::new();$pids=[Collections.Generic.HashSet[int]]::new()
$phase='build';$failure=$null;$apkHash=$null;$protected=$false;$installed=$null
$envNames=@('TDS_ACCESS_REPORT','TDS_ACCESS_PHASE','TDS_ACCESS_RUN');$oldEnv=@{};foreach($name in $envNames){$oldEnv[$name]=[Environment]::GetEnvironmentVariable($name)}
try {
    State 'RUNNING'
    if ($ResumeInstall) {
        $apk=Join-Path $priorOut 'qa.apk'
    } else {
        Bounded $flutter @('build','apk','--debug','--no-pub',"--target=$target","--dart-define-from-file=$(Join-Path $fixtureDir 'defines.json')",'--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false') $appRoot 'build' 600
        $apk=Join-Path $appRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    }
    if (-not $ResumeInstall) {
        $manifest=(& 'C:/Users/Usuario/AppData/Local/Android/Sdk/build-tools/36.1.0/aapt.exe' dump badging $apk 2>&1)-join "`n"
        if($LASTEXITCODE -ne 0 -or $manifest -notmatch "package: name='$([regex]::Escape($package))'" -or $manifest -notmatch '(?m)^application-debuggable'){throw 'Refuse unexpected APK'}
    }
    $apkHash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $apk -Destination (Join-Path $out 'qa.apk')
    $phase='install';State 'RUNNING';Write-Host 'Confirme a instalação de Tutor TDS QA no POCO.';Start-Sleep -Seconds 12
    if((Adb @('install','-t',$apk)) -notmatch '(?m)^Success\s*$'){throw 'Android did not confirm installation'}
    $installed=Identity $package
    if($installed.hashes.Count -ne 1 -or $installed.hashes[0] -ne $apkHash){throw 'Installed APK mismatch'}
    foreach($phase in $phases){
        State 'RUNNING'
        if((Sources|ConvertTo-Json -Compress) -cne $sourceJson -or (Get-FileHash -LiteralPath (Join-Path $fixtureDir 'defines.json') -Algorithm SHA256).Hash -ne $definesHash){throw 'Sources/configuration changed during gate'}
        if($phase -eq 'revoked_online'){Bounded $python @('-m','ops.qa_classroom_access','--phase','revoke','--run-id',$RunId,'--execute') (Join-Path $workspace 'api') 'host-revoke' 180}
        $null=Adb @('shell','am','force-stop',$package)
        if($phase -in @('cold_offline','offline_restart','revoked_offline')){Network '0' '0'}else{Network $wifi $mobile}
        $started=[long](Adb @('shell','date','+%s'))
        $null=Adb @('shell','am','start','-W','-n',"$package/com.tutortds_cartilhas.MainActivity",'--ez','enable-checked-mode','true','--ez','verify-entry-points','true')
        $androidPid=[int](Adb @('shell','pidof','-s',$package));if(-not $pids.Add($androidPid)){throw 'Expected new process'}
        $vm=$null;$deadline=(Get-Date).AddSeconds(40)
        while((Get-Date) -lt $deadline){
            $logs=Adb @('logcat','-d','--pid',"$androidPid",'-v','epoch','-t','200')
            foreach($line in $logs -split "`n"){if($line -match '^\s*(\d+\.\d+).*Dart VM service is listening on (http://127\.0\.0\.1:\d+/[A-Za-z0-9_=\-]+/)'){if([double]$Matches[1] -ge $started){$vm=[Uri]$Matches[2]}}}
            if($vm){break};Start-Sleep -Milliseconds 400
        }
        if(-not $vm){throw 'No QA VM service'}
        $port=Adb @('forward','tcp:0',"tcp:$($vm.Port)");$forward="tcp:$port";$forwards.Add($forward);$local=[UriBuilder]::new($vm);$local.Port=[int]$port
        $env:TDS_ACCESS_REPORT=Join-Path $out "$phase.json";$env:TDS_ACCESS_PHASE=$phase;$env:TDS_ACCESS_RUN=$RunId
        Write-Host "Validando acesso/PDF no POCO: $phase"
        Bounded $flutter @('drive','--debug','--no-pub','--no-dds','-d',$Device,"--driver=$driver","--target=$target","--use-existing-app=$($local.Uri.AbsoluteUri)",'--keep-app-running') $appRoot $phase 720
        $report=Get-Content -LiteralPath $env:TDS_ACCESS_REPORT -Raw|ConvertFrom-Json
        if($report.status -ne 'passed' -or $report.report.pid -ne $androidPid -or $report.report.cohort_id -ne $fixture.class_id -or $report.report.course_version_id -ne $fixture.version_id){throw 'Report identity mismatch'}
        if((Identity $package|ConvertTo-Json -Compress) -cne ($installed|ConvertTo-Json -Compress)){throw 'Installed app changed'}
        $reports.Add($report);$null=Adb @('forward','--remove',$forward);$null=$forwards.Remove($forward)
    }
    Bounded $python @('-m','ops.qa_classroom_access','--phase','verify','--run-id',$RunId,'--execute') (Join-Path $workspace 'api') 'host-verify' 180
    if((Sources|ConvertTo-Json -Compress) -cne $sourceJson){throw 'Sources changed'}
} catch {$failure=$_.Exception.Message} finally {
    try {Network $wifi $mobile}catch{$cleanup.Add('network')}
    try {$null=Adb @('shell','am','force-stop',$package)}catch{$cleanup.Add('stop_qa')}
    foreach($forward in $forwards){try{$null=Adb @('forward','--remove',$forward)}catch{$cleanup.Add('forward')}}
    try {$after=[ordered]@{play=(Identity 'com.tutortds_cartilhas');dev=(Identity 'com.tutortds_cartilhas.dev')};if(($before|ConvertTo-Json -Compress) -cne ($after|ConvertTo-Json -Compress)){throw 'Protected apps changed'};$protected=$true}catch{$cleanup.Add('protected_apps')}
    foreach($name in $envNames){[Environment]::SetEnvironmentVariable($name,$oldEnv[$name],'Process')}
}
$passed=(-not $failure -and $cleanup.Count -eq 0 -and $reports.Count -eq $phases.Count)
State $(if($passed){'PASSED'}else{'FAILED_PRESERVED_FOR_DIAGNOSIS'})
$evidence=[ordered]@{status=$(if($passed){'passed'}else{'failed_preserved'});run_id=$RunId;device=$Device;app_package=$package;apk_sha256=$apkHash;reports=$reports.ToArray();source_sha256=$sources;defines_sha256=$definesHash.ToLowerInvariant();installation_resume=$ResumeInstall.IsPresent;parent_evidence_sha256=$parentHash;protected_apps_unchanged=$protected;protected_before=$before;protected_after=$after;cleanup_errors=$cleanup.ToArray();failure=$failure;production_ready=$false;verified_at=(Get-Date).ToUniversalTime().ToString('o')}
$evidence|ConvertTo-Json -Depth 50|Set-Content -LiteralPath (Join-Path $workspace "docs/production/evidence/$evidenceName") -Encoding utf8
if(-not $passed){throw 'Physical access gate stopped; inspect preserved run, never retry blindly'}
Write-Host 'Physical access and PDF request phases passed; PDF rendering still needs observation.'
