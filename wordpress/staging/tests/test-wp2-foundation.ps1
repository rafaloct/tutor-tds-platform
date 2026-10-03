$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$plugin = Join-Path $root 'tds-portal-core'
$config = Get-Content (Join-Path $plugin 'includes\class-tds-public-config.php') -Raw
$adapter = Get-Content (Join-Path $plugin 'includes\class-tds-fake-courses-adapter.php') -Raw
$controller = Get-Content (Join-Path $plugin 'includes\class-tds-public-courses-controller.php') -Raw
$bootstrap = Get-Content (Join-Path $plugin 'tds-portal-core.php') -Raw
$contract = Get-Content (Join-Path $root '..\docs\portal\WP2_FOUNDATION_CONTRACT.md') -Raw

if ($config -notmatch "const APP_URL_OPTION = 'tds_app_access_url'") { throw 'missing sole app URL option' }
if ($config -notmatch "'analytics'\s*=>\s*'disabled'" -or $config -notmatch "'support'\s*=>\s*'disabled'") { throw 'integrations are not disabled by default' }
if ($config -notmatch "scheme.*https") { throw 'HTTPS validation missing' }
if ($adapter -notmatch "implements TDS_Courses_Adapter_Interface" -or $adapter -notmatch "'state' => 'unavailable'") { throw 'offline adapter contract missing' }
if ($controller -notmatch "'/public/courses'") { throw 'public courses route missing' }
if ($bootstrap -notmatch 'register_setting' -or $bootstrap -notmatch 'TDS_Public_Config::APP_URL_OPTION') { throw 'central setting registration missing' }
$pluginText = (Get-ChildItem $plugin -Recurse -File | Get-Content -Raw) -join "`n"
if ($pluginText -match 'wpdb|wp_users|password|api_key|secret') { throw 'forbidden database/secret term in plugin' }
if ($contract -notmatch 'staging remains\s+`UNKNOWN`') { throw 'staging boundary not documented' }

Write-Output 'PASS: WP-2 foundation static contract checks (7 assertions)'
