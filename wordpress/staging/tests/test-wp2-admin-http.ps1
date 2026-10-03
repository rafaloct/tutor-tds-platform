param([Parameter(Mandatory)][string]$Php, [Parameter(Mandatory)][string]$QaRoot)
$ErrorActionPreference = 'Stop'
$qaPath = (Resolve-Path -LiteralPath $QaRoot).Path
if ((Get-Content -LiteralPath (Join-Path $qaPath '.tds-disposable-qa') -Raw).Trim() -ne 'tds-wp2-local-synthetic-only') { throw 'Not disposable QA' }
$ext = Join-Path (Split-Path $Php) 'ext'
$argsPhp = @('-n','-d',"extension_dir=$ext",'-d','extension=pdo_sqlite','-d','extension=sqlite3','-d','extension=openssl','-d','extension=mbstring','-S','127.0.0.1:18742','-t',$qaPath)
$server = Start-Process -FilePath $Php -ArgumentList $argsPhp -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path (Split-Path $qaPath) 'http-out.log') -RedirectStandardError (Join-Path (Split-Path $qaPath) 'http-error.log')
$base = 'http://127.0.0.1:18742'
$checks = 0
function Assert-QA($Condition, $Message) { if (!$Condition) { throw $Message }; $script:checks++ }
function Login-QA($Name) {
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-WebRequest "$base/wp-login.php" -WebSession $session
    $null = Invoke-WebRequest "$base/wp-login.php" -Method Post -WebSession $session -Body @{log=$Name; pwd='Synthetic-QA-Only-20261003!'; 'wp-submit'='Log In'; redirect_to="$base/wp-admin/"; testcookie='1'} -SkipHttpErrorCheck
    return $session
}
try {
    Start-Sleep -Milliseconds 500
    if ($server.HasExited) { throw 'QA server failed to start; not testing another listener' }
    $admin = Login-QA 'qa_admin'
    $page = Invoke-WebRequest "$base/wp-admin/options-general.php" -WebSession $admin -SkipHttpErrorCheck
    Assert-QA ($page.StatusCode -eq 200 -and $page.Content.Contains('tds_app_access_url')) 'Admin settings render'
    $nonce = [regex]::Match($page.Content, 'name="_wpnonce" value="([^"]+)"').Groups[1].Value
    Assert-QA ($nonce.Length -gt 0) 'General options nonce rendered'
    $body = @{option_page='general'; action='update'; _wpnonce=$nonce; _wp_http_referer='/wp-admin/options-general.php'; blogname='Synthetic WP2 QA'; blogdescription='Synthetic only'; admin_email='qa@example.invalid'; timezone_string='UTC'; date_format='F j, Y'; time_format='g:i a'; start_of_week='1'; tds_app_access_url='https://example.org/app'; tds_ga4_measurement_id='G-ABCDEFGHIJ'; tds_public_api_base_url='https://api.example.org'; tds_support_base_url='https://support.example.org'}
    $saved = Invoke-WebRequest "$base/wp-admin/options.php" -WebSession $admin -Method Post -Body $body -SkipHttpErrorCheck
    Assert-QA ($saved.StatusCode -eq 200 -and $saved.Content.Contains('value="https://example.org/app"')) 'Authenticated nonce POST persists through core options.php'
    $body._wpnonce = 'invalid'
    $body.tds_app_access_url = 'https://example.org/should-not-save'
    $denied = Invoke-WebRequest "$base/wp-admin/options.php" -WebSession $admin -Method Post -Body $body -SkipHttpErrorCheck
    Assert-QA ($denied.StatusCode -eq 403) 'Core rejects invalid nonce'
    $subscriber = Login-QA 'qa_subscriber'
    $body._wpnonce = $nonce
    $denied = Invoke-WebRequest "$base/wp-admin/options.php" -WebSession $subscriber -Method Post -Body $body -SkipHttpErrorCheck
    Assert-QA ($denied.StatusCode -eq 403) 'Core rejects subscriber settings POST'
    $page = Invoke-WebRequest "$base/wp-admin/options-general.php" -WebSession $admin
    Assert-QA ($page.Content.Contains('value="https://example.org/app"') -and !$page.Content.Contains('value="https://example.org/should-not-save"')) 'Denied writes leave persisted option unchanged'
    $body._wpnonce = [regex]::Match($page.Content, 'name="_wpnonce" value="([^"]+)"').Groups[1].Value
    $body.tds_app_access_url = 'javascript:alert(1)'
    $saved = Invoke-WebRequest "$base/wp-admin/options.php" -WebSession $admin -Method Post -Body $body -SkipHttpErrorCheck
    Assert-QA ($saved.StatusCode -eq 200 -and $saved.Content -match 'name="tds_app_access_url" value=""') 'Real settings save invokes sanitizer'
    "PASS $checks real WordPress HTTP admin assertions"
} finally {
    if (!$server.HasExited) { Stop-Process -Id $server.Id; $server.WaitForExit() }
}
