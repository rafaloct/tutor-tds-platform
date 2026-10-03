param([Parameter(Mandatory)][string]$Php, [Parameter(Mandatory)][string]$MySqlArchive, [Parameter(Mandatory)][string]$WordPressArchive, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $Destination) { throw 'Use a new disposable destination' }
$qa = [IO.Path]::GetFullPath($Destination)
if ($qa -match '\s') { throw 'Use a QA path without spaces' }
if ((Get-FileHash -LiteralPath $MySqlArchive -Algorithm SHA256).Hash -ne 'a492371d687d2bab088b0062581144a0044b8964baefdf4faa579292b423d25c') { throw 'MySQL 8.4.11 archive mismatch' }
if ((Get-FileHash -LiteralPath $WordPressArchive -Algorithm SHA256).Hash -ne '8fc96c59a78b7219e4a130222b7fadb51b03e503e8b0123beaa7e28961c21ce2') { throw 'WordPress 7.1.2 archive mismatch' }
if (Get-NetTCPConnection -State Listen -LocalPort 13342 -ErrorAction SilentlyContinue) { throw 'QA MySQL port already in use' }
New-Item -ItemType Directory -Path $qa | Out-Null
Expand-Archive -LiteralPath $MySqlArchive -DestinationPath $qa
Expand-Archive -LiteralPath $WordPressArchive -DestinationPath $qa
$bin = Join-Path $qa 'mysql-8.4.11-winx64/bin'
$wp = Join-Path $qa 'wordpress'
$data = Join-Path $qa 'mysql-data'
$server = $null
$oldRoot = $env:TDS_WP_QA_ROOT
$oldDb = $env:TDS_WP_QA_RESTORED
$client = @('--no-defaults','--host=127.0.0.1','--port=13342','--user=root','--protocol=TCP')
function Run-Sql([string]$Sql) { & (Join-Path $bin 'mysql.exe') @client --execute=$Sql; if ($LASTEXITCODE -ne 0) { throw 'QA MySQL command failed' } }
try {
    & (Join-Path $bin 'mysqld.exe') --no-defaults --initialize-insecure "--basedir=$(Split-Path $bin)" "--datadir=$data" "--log-error=$(Join-Path $qa 'initialize.log')"
    if ($LASTEXITCODE -ne 0) { throw 'MySQL initialization failed' }
    $server = Start-Process -FilePath (Join-Path $bin 'mysqld.exe') -ArgumentList @('--no-defaults',"--basedir=$(Split-Path $bin)","--datadir=$data",'--port=13342','--bind-address=127.0.0.1','--mysqlx=0','--skip-log-bin',"--log-error=$(Join-Path $qa 'mysql.log')") -PassThru -WindowStyle Hidden
    $ready = $false
    for ($i=0; $i -lt 40; $i++) {
        if ($server.HasExited) { throw 'QA MySQL exited' }
        & (Join-Path $bin 'mysqladmin.exe') @client ping 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'QA MySQL startup timeout' }
    Run-Sql "CREATE DATABASE wp2_qa; CREATE DATABASE wp2_restore; CREATE USER 'wp2'@'127.0.0.1' IDENTIFIED BY 'Synthetic-QA-Only-20261003!'; GRANT ALL ON wp2_qa.* TO 'wp2'@'127.0.0.1'; GRANT ALL ON wp2_restore.* TO 'wp2'@'127.0.0.1';"
    Copy-Item (Join-Path $PSScriptRoot '../../tds-portal-core') (Join-Path $wp 'wp-content/plugins') -Recurse
    New-Item -ItemType Directory (Join-Path $wp 'wp-content/mu-plugins') | Out-Null
@'
<?php
define('DB_NAME', getenv('TDS_WP_QA_RESTORED') === '1' ? 'wp2_restore' : 'wp2_qa');
define('DB_USER', 'wp2'); define('DB_PASSWORD', 'Synthetic-QA-Only-20261003!'); define('DB_HOST', '127.0.0.1:13342');
define('DB_CHARSET', 'utf8mb4'); define('DB_COLLATE', '');
define('WP_HOME', 'http://127.0.0.1:18743'); define('WP_SITEURL', WP_HOME);
define('WP_HTTP_BLOCK_EXTERNAL', true); define('DISABLE_WP_CRON', true);
define('AUTOMATIC_UPDATER_DISABLED', true); define('DISALLOW_FILE_MODS', true);
define('WP_ENVIRONMENT_TYPE', 'local'); define('WP_DEBUG', true); define('WP_DEBUG_DISPLAY', false);
define('AUTH_KEY', 'synthetic-local-mysql-qa-only');
foreach (['SECURE_AUTH_KEY','LOGGED_IN_KEY','NONCE_KEY','AUTH_SALT','SECURE_AUTH_SALT','LOGGED_IN_SALT','NONCE_SALT'] as $key) { define($key, AUTH_KEY); }
$table_prefix = 'qa_';
if (!defined('ABSPATH')) { define('ABSPATH', __DIR__ . '/'); }
require_once ABSPATH . 'wp-settings.php';
'@ | Set-Content -LiteralPath (Join-Path $wp 'wp-config.php') -Encoding utf8NoBOM
@'
<?php
add_filter('pre_http_request', static function () { return new WP_Error('qa_egress_blocked', 'Local QA'); }, PHP_INT_MAX);
add_filter('pre_wp_mail', static function () { return true; }, PHP_INT_MAX);
'@ | Set-Content -LiteralPath (Join-Path $wp 'wp-content/mu-plugins/qa-isolation.php') -Encoding utf8NoBOM
    'tds-wp2-local-mysql-synthetic-only' | Set-Content (Join-Path $wp '.tds-mysql-qa') -Encoding utf8NoBOM
    $phpArgs = @('-n','-d',"extension_dir=$(Join-Path (Split-Path $Php) 'ext')",'-d','extension=mysqli','-d','extension=openssl','-d','extension=mbstring','-d','log_errors=1','-d',"error_log=$(Join-Path $qa 'php.log')")
    $env:TDS_WP_QA_ROOT = $wp
    $env:TDS_WP_QA_RESTORED = '0'
    function Run-Core([string]$Mode) { & $Php @phpArgs (Join-Path $PSScriptRoot 'test-wp2-mysql.php') $Mode; if ($LASTEXITCODE -ne 0) { throw "MySQL WordPress $Mode failed" } }
    Run-Core 'install'
    Run-Core 'seed'
    $uploads = Join-Path $wp 'wp-content/uploads'
    New-Item -ItemType Directory -Force $uploads | Out-Null
    'Synthetic upload recovery marker' | Set-Content (Join-Path $uploads 'qa-marker.txt') -Encoding utf8NoBOM
    $uploadHash = (Get-FileHash (Join-Path $uploads 'qa-marker.txt') -Algorithm SHA256).Hash
    $backup = Join-Path $qa 'backup'
    New-Item -ItemType Directory $backup | Out-Null
    Copy-Item $uploads (Join-Path $backup 'uploads') -Recurse
    $dump = Join-Path $backup 'wordpress.sql'
    & (Join-Path $bin 'mysqldump.exe') @client --single-transaction --no-tablespaces --set-gtid-purged=OFF --result-file=$dump wp2_qa
    if ($LASTEXITCODE -ne 0 -or (Get-Item $dump).Length -eq 0) { throw 'MySQL backup failed' }
    Run-Sql ("USE wp2_restore; SOURCE " + $dump.Replace('\','/') + ';')
    $restoreUploads = Join-Path $qa 'restored-uploads'
    Copy-Item (Join-Path $backup 'uploads') $restoreUploads -Recurse
    if ((Get-FileHash (Join-Path $restoreUploads 'qa-marker.txt') -Algorithm SHA256).Hash -ne $uploadHash) { throw 'Upload restore hash mismatch' }
    $env:TDS_WP_QA_RESTORED = '1'
    Run-Core 'restored'
    Run-Core 'deactivate'
    Run-Core 'inactive'
    Run-Core 'reactivated'
    "PASS MySQL dump restored to separate database; upload hash $uploadHash; deactivate/reactivate verified across processes"
} finally {
    $env:TDS_WP_QA_ROOT = $oldRoot
    $env:TDS_WP_QA_RESTORED = $oldDb
    if ($server -and !$server.HasExited) {
        & (Join-Path $bin 'mysqladmin.exe') @client shutdown 2>$null | Out-Null
        if (!$server.WaitForExit(10000)) { Stop-Process -Id $server.Id; $server.WaitForExit() }
    }
}
