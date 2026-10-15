#!/usr/bin/env bash
# Installs ONLY a disposable Drupal copy against fixed database tds_lock_qa.
# The caller owns isolated DB/PHP containers; this script creates none.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
if [[ "${TDS_SESSION_MUTEX_QA:-}" != 1 || "${TDS_SESSION_MUTEX_FIXTURE_ROOT:-}" != "$root" || -z "${TDS_SESSION_MUTEX_SOCKET:-}" ]]; then
  echo 'Refusing: opt-in, exact disposable root and Unix socket are required.' >&2
  exit 2
fi
cd "$root"
web_bind="${TDS_SESSION_MUTEX_WEB_BIND:-127.0.0.1}"
[[ "$web_bind" == 127.0.0.1 || "$web_bind" == 0.0.0.0 ]] || exit 2
[[ "${TDS_SESSION_MUTEX_BROWSER_HOLD:-0}" == 0 || "${TDS_SESSION_MUTEX_BROWSER_HOLD:-0}" == 1 ]] || exit 2
export TDS_SESSION_MUTEX_WEB_BIND="$web_bind"
rm -f .tds-browser-ready .tds-browser-done
if [[ -e web/sites/default/settings.local.php ]]; then
  echo 'Refusing to overwrite existing local settings.' >&2
  exit 2
fi
for command in php curl setsid; do command -v "$command" >/dev/null; done
[[ -f vendor/autoload.php && -f vendor/bin/drush && -f web/.ht.router.php ]]
export DRUPAL_ENVIRONMENT=local
# Refuse to send synthetic credentials to an unrelated listener.
php -r '
$listeners = [];
foreach ([8871, 8872] as $port) {
  $listener = @stream_socket_server("tcp://" . ($port === 8871 ? getenv("TDS_SESSION_MUTEX_WEB_BIND") : "127.0.0.1") . ":" . $port, $code, $message);
  if (!$listener) { fwrite(STDERR, "Refusing: fixture loopback port occupied.\n"); exit(2); }
  $listeners[] = $listener;
}
foreach ($listeners as $listener) { fclose($listener); }
'
# The caller must first confirm the DB container's PID1 is final mariadbd/mysqld,
# not its initialization shell. A ping during temporary init-server is unsafe.
php -r '
$db = new PDO("mysql:unix_socket=" . getenv("TDS_SESSION_MUTEX_SOCKET") . ";dbname=tds_lock_qa", "root", "");
$db->query("SELECT 1");
if ((int) $db->query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\x27tds_lock_qa\x27")->fetchColumn() !== 0) {
  fwrite(STDERR, "Refusing: disposable QA database is not empty.\n"); exit(2);
}
'
scratch="$(mktemp -d /tmp/tds-session-http.XXXXXX)"
chmod 700 "$scratch"
cp -p web/sites/default/settings.php "$scratch/settings.php"
web_pid=''
api_pid=''
created_runtime=0
stage=prepare
cleanup() {
  result=$?
  if [[ -n "$web_pid" ]]; then kill -- "-$web_pid" 2>/dev/null || true; fi
  if [[ -n "$api_pid" ]]; then kill -- "-$api_pid" 2>/dev/null || true; fi
  cp -p "$scratch/settings.php" web/sites/default/settings.php
  rm -f web/sites/default/settings.local.php
  if [[ "$created_runtime" == 1 ]]; then rm -f web/autoload_runtime.php; fi
  if [[ "$result" != 0 ]]; then
    mkdir -p "$root/.tds-session-http-failure"
    chmod 700 "$root/.tds-session-http-failure"
    cp "$scratch"/*.log "$root/.tds-session-http-failure/" 2>/dev/null || true
    echo "Fixture failed at stage=$stage; synthetic logs retained in $root/.tds-session-http-failure" >&2
  fi
  rm -f .tds-browser-ready .tds-browser-done
  rm -rf "$scratch"
  return "$result"
}
trap cleanup EXIT
export TDS_SESSION_MUTEX_COOKIE_JAR="$scratch/cookies"
cat > web/sites/default/settings.local.php <<'PHP'
<?php
// Explicit opt-in fixture only; fixed disposable database, no network.
$databases['default']['default'] = [
  'driver' => 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
  'database' => 'tds_lock_qa',
  'username' => 'root',
  'password' => '',
  'host' => 'localhost',
  'unix_socket' => getenv('TDS_SESSION_MUTEX_SOCKET'),
  'prefix' => '',
];
$settings['config_sync_directory'] = '/tmp/tds-session-lock-config';
$settings['file_public_path'] = 'sites/default/files/tds-session-lock-fixture';
$settings['hash_salt'] = 'synthetic-session-lock-fixture';
$settings['tutor_api_base_url'] = 'http://127.0.0.1:8872';
PHP
if [[ ! -f web/autoload_runtime.php ]]; then
  printf '<?php\nrequire_once dirname(__DIR__) . "/vendor/autoload_runtime.php";\n' > web/autoload_runtime.php
  created_runtime=1
fi
stage=install
vendor/bin/drush site:install minimal --account-name=qa-session-lock --account-pass=qa-session-lock-not-a-secret --site-name=SessionLockQA -y > "$scratch/install.log" 2>&1
# Installer appends database config without socket; restore source, keep local.
cp -p "$scratch/settings.php" web/sites/default/settings.php
stage=enable-gateway
vendor/bin/drush en tds_tutor_gateway -y
if [[ "${TDS_SESSION_MUTEX_INTEGRATION:-}" == 1 ]]; then
  stage=enable-integrated-portals
  vendor/bin/drush en tds_participant_portal tds_operator_portal tds_support_certificates -y
fi
stage=start-listeners
(cd "$root/web" && exec env PHP_CLI_SERVER_WORKERS=4 setsid php -S "$web_bind:8871" .ht.router.php) > "$scratch/web.log" 2>&1 &
web_pid=$!
setsid php -S 127.0.0.1:8872 scripts/fixtures/session-lock-api.php > "$scratch/api.log" 2>&1 &
api_pid=$!
ready=0
for attempt in $(seq 1 40); do
  kill -0 "$web_pid" "$api_pid" 2>/dev/null || { echo "Fixture listener exited." >&2; exit 1; }
  if curl --max-time 2 -fsS http://127.0.0.1:8871/session/token > /dev/null 2>&1; then ready=1; break; fi
  sleep 0.2
done
[[ "$ready" == 1 ]]
kill -0 "$web_pid" "$api_pid"
stage=synthetic-login
curl --max-time 10 -fsS -c "$TDS_SESSION_MUTEX_COOKIE_JAR" -H 'Content-Type: application/json' --data '{"name":"qa-session-lock","pass":"qa-session-lock-not-a-secret"}' 'http://127.0.0.1:8871/user/login?_format=json' > "$scratch/login.json"
stage=concurrent-refresh
php scripts/fixtures/session-lock-api.php seed
php scripts/test-dr3-session-concurrency.php http
stage=core-cookie-rotation
php scripts/fixtures/session-lock-api.php seed-anonymous
php scripts/test-dr3-session-concurrency.php http-rotation
stage=tds-cookie-rotation
php scripts/test-dr3-session-concurrency.php http-tds
if [[ "${TDS_SESSION_MUTEX_BROWSER_HOLD:-0}" == 1 ]]; then
  stage=browser-proof
  touch .tds-browser-ready
  deadline=$((SECONDS + 120))
  while [[ ! -f .tds-browser-done && "$SECONDS" -lt "$deadline" ]]; do
    kill -0 "$web_pid" "$api_pid"
    sleep 1
  done
  [[ -f .tds-browser-done ]] || { echo 'Browser fixture deadline exceeded.' >&2; exit 1; }
fi
echo 'Disposable HTTP fixture passed. Remove its database/container and checkout.'
