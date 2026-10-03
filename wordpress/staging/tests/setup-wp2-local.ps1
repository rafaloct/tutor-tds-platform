param([Parameter(Mandatory)][string]$Php, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $Destination) { throw 'Use a new disposable directory, never an existing WordPress installation' }
$qa = [IO.Path]::GetFullPath($Destination)
if ($qa -match '\s') { throw 'Use a path without spaces for the PHP process arguments' }
New-Item -ItemType Directory -Path $qa | Out-Null
$wp = Join-Path $qa 'wordpress'
Invoke-WebRequest 'https://wordpress.org/wordpress-7.1.2.zip' -OutFile (Join-Path $qa 'wordpress.zip')
Invoke-WebRequest 'https://downloads.wordpress.org/plugin/sqlite-database-integration.3.0.2.zip' -OutFile (Join-Path $qa 'sqlite.zip')
if ((Get-FileHash (Join-Path $qa 'wordpress.zip') -Algorithm SHA256).Hash -ne '8fc96c59a78b7219e4a130222b7fadb51b03e503e8b0123beaa7e28961c21ce2') { throw 'WordPress archive checksum mismatch' }
if ((Get-FileHash (Join-Path $qa 'sqlite.zip') -Algorithm SHA256).Hash -ne '1602e75577ad9b3a7e3e4a6a44a81b9541cdee2124d48928faf61c6fd3cd4f74') { throw 'SQLite archive checksum mismatch' }
Expand-Archive (Join-Path $qa 'wordpress.zip') -DestinationPath $qa
Expand-Archive (Join-Path $qa 'sqlite.zip') -DestinationPath (Join-Path $wp 'wp-content/plugins')
$core = Invoke-RestMethod 'https://api.wordpress.org/core/checksums/1.0/?version=7.1.2&locale=en_US'
foreach ($entry in $core.checksums.PSObject.Properties) {
    if ((Get-FileHash (Join-Path $wp $entry.Name) -Algorithm MD5).Hash -ne $entry.Value) { throw "Core file mismatch: $($entry.Name)" }
}
$sqlite = Invoke-RestMethod 'https://downloads.wordpress.org/plugin-checksums/sqlite-database-integration/3.0.2.json'
foreach ($entry in $sqlite.files.PSObject.Properties) {
    if ((Get-FileHash (Join-Path $wp "wp-content/plugins/sqlite-database-integration/$($entry.Name)") -Algorithm SHA256).Hash -ne $entry.Value.sha256) { throw "SQLite file mismatch: $($entry.Name)" }
}
Copy-Item (Join-Path $wp 'wp-content/plugins/sqlite-database-integration/db.copy') (Join-Path $wp 'wp-content/db.php')
Copy-Item (Join-Path $PSScriptRoot '../../tds-portal-core') (Join-Path $wp 'wp-content/plugins') -Recurse
New-Item -ItemType Directory (Join-Path $wp 'wp-content/mu-plugins') | Out-Null
@'
<?php
define('DB_NAME', 'qa'); define('DB_USER', 'qa'); define('DB_PASSWORD', ''); define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8'); define('DB_COLLATE', '');
define('WP_HOME', 'http://127.0.0.1:18742'); define('WP_SITEURL', WP_HOME);
define('WP_HTTP_BLOCK_EXTERNAL', true); define('DISABLE_WP_CRON', true);
define('AUTOMATIC_UPDATER_DISABLED', true); define('DISALLOW_FILE_MODS', true);
define('WP_ENVIRONMENT_TYPE', 'local'); define('WP_DEBUG', true); define('WP_DEBUG_DISPLAY', false);
define('AUTH_KEY', 'local-disposable-synthetic-qa-key-not-production');
foreach (['SECURE_AUTH_KEY','LOGGED_IN_KEY','NONCE_KEY','AUTH_SALT','SECURE_AUTH_SALT','LOGGED_IN_SALT','NONCE_SALT'] as $key) { define($key, AUTH_KEY); }
$table_prefix = 'qa_';
if (!defined('ABSPATH')) { define('ABSPATH', __DIR__ . '/'); }
require_once ABSPATH . 'wp-settings.php';
'@ | Set-Content -LiteralPath (Join-Path $wp 'wp-config.php') -Encoding utf8NoBOM
@'
<?php
add_filter('pre_http_request', static function () { return new WP_Error('qa_egress_blocked', 'QA blocks WordPress HTTP.'); }, PHP_INT_MAX);
add_filter('pre_wp_mail', static function () { return true; }, PHP_INT_MAX);
'@ | Set-Content -LiteralPath (Join-Path $wp 'wp-content/mu-plugins/qa-isolation.php') -Encoding utf8NoBOM
'tds-wp2-local-synthetic-only' | Set-Content -LiteralPath (Join-Path $wp '.tds-disposable-qa') -Encoding utf8NoBOM
@'
<?php
define('WP_INSTALLING', true);
require __DIR__ . '/wordpress/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
wp_install('Synthetic WP2 QA', 'qa_admin', 'qa@example.invalid', false, '', 'Synthetic-QA-Only-20261003!');
wp_create_user('qa_subscriber', 'Synthetic-QA-Only-20261003!', 'subscriber@example.invalid');
activate_plugin('tds-portal-core/tds-portal-core.php');
echo 'Disposable WordPress installed.';
'@ | Set-Content -LiteralPath (Join-Path $qa 'install.php') -Encoding utf8NoBOM
$ext = Join-Path (Split-Path $Php) 'ext'
$phpArgs = @('-n','-d',"extension_dir=$ext",'-d','extension=pdo_sqlite','-d','extension=sqlite3','-d','extension=openssl','-d','extension=mbstring')
& $Php @phpArgs (Join-Path $qa 'install.php')
if ($LASTEXITCODE -ne 0) { throw 'WordPress install failed' }
$previousQa = $env:TDS_WP_QA_ROOT
try {
    $env:TDS_WP_QA_ROOT = $wp
    & $Php @phpArgs (Join-Path $PSScriptRoot 'test-wp2-wordpress.php')
    if ($LASTEXITCODE -ne 0) { throw 'Core assertions failed' }
    & $Php @phpArgs (Join-Path $PSScriptRoot 'test-wp2-wordpress.php') reload
    if ($LASTEXITCODE -ne 0) { throw 'Reload assertions failed' }
    & (Join-Path $PSScriptRoot 'test-wp2-admin-http.ps1') -Php $Php -QaRoot $wp
} finally {
    $env:TDS_WP_QA_ROOT = $previousQa
}
