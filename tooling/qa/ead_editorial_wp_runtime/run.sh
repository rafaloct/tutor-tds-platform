#!/usr/bin/env bash
# QA ONLY: clone of synthetic WordPress+LearnPress+MariaDB with reversible teardown.
# No production network, no student data and no changes to the original sandbox.
set -Eeuo pipefail
umask 077
ORIG=/workspace/tds-wp-sandbox-20261017
WPCLI="$ORIG/wp-cli.phar"
WPO="$ORIG/wordpress-mysql"
BASE=http://127.0.0.1:18736
EXPECTED_PLUGIN_SHA=064c350c544f60c02526b774c96b56d4e3a77e28cf1e279346999d9d489b632c
wpo() { php "$WPCLI" --allow-root --path="$WPO" "$@"; }
fail() { echo "BLOCKED $1" >&2; exit 4; }
[ "$(wpo option get siteurl)" = 'http://127.0.0.1:18732' ] || fail "source not isolated"
[ "$(wpo option get home)" = 'http://127.0.0.1:18732' ] || fail "source home not isolated"
[ "$(wpo config get DB_NAME)" = 'tdsqam' ] || fail "source DB mismatched"
[ "$(wpo config get DB_USER)" = 'tdsqa' ] || fail "source DB user mismatched"
counts=$(wpo eval 'global $wpdb; $a=$wpdb->get_col("SELECT user_email FROM {$wpdb->users}"); $non=0; foreach($a as $e) if(!str_ends_with($e,"@qa-synthetic.test")) $non++; echo count($a).":".$non;')
[ "$counts" = '5:0' ] || fail "non-synthetic user or changed fixture"
PR_HEAD=3856566e97a585c5d30dd8a1b72ca369f1704127
REPO=/workspace/tds-issue236-wp-editorial-bridge
git -C "$REPO" cat-file -e "${PR_HEAD}^{commit}" || fail "PR #238 exact HEAD unavailable"
sha=$(git -C "$REPO" show "$PR_HEAD:wordpress/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php" | sha256sum | awk '{print $1}')
[ "$sha" = "$EXPECTED_PLUGIN_SHA" ] || fail "PR #238 source fingerprint diverged"
[ "$(wpo plugin is-active tds-learnpress-editorial >/dev/null 2>&1; echo $?)" = 0 ] || fail "editorial plugin inactive"
! ss -ltn | grep -Fq '127.0.0.1:18736' || fail "port already occupied"
WORK=$(mktemp -d /workspace/tds-editorial236-XXXXXXXX)
DB_NAME="tdsqa236_$(basename "$WORK" | awk -F- '{print $NF}' | tr -cd 'A-Za-z0-9')"
DB_CREATED=0
GRANT_CREATED=0
HTTP_PID=''
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  if [ -n "$HTTP_PID" ]; then
    kill "$HTTP_PID" >/dev/null 2>&1 || true
    wait "$HTTP_PID" 2>/dev/null || true
  fi
  if [ "$GRANT_CREATED" = 1 ]; then
    mariadb -e "REVOKE ALL PRIVILEGES ON \`$DB_NAME\`.* FROM 'tdsqa'@'localhost'" >/dev/null 2>&1 || rc=6
  fi
  if [ "$DB_CREATED" = 1 ]; then
    mariadb -e "DROP DATABASE IF EXISTS \`$DB_NAME\`" >/dev/null 2>&1 || rc=6
  fi
  rm -rf -- "$WORK" || rc=6
  if [ -e "$WORK" ]; then
    echo "ROLLBACK_DIR=FAIL"
    rc=6
  else
    echo "ROLLBACK_DIR=PASS"
  fi
  if [ "$DB_CREATED" = 1 ] && [ "$(mariadb -N -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME'")" = 0 ]; then
    echo "ROLLBACK_DB=PASS"
  elif [ "$DB_CREATED" = 1 ]; then
    echo "ROLLBACK_DB=FAIL"; rc=6
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "ISOLATION=PASS source_DB=tdsqam users=synthetic-only PR238_source_verified=PASS"
mariadb -N -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME'" | grep -q . && fail "QA database collision"
mariadb -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
DB_CREATED=1
mariadb -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO 'tdsqa'@'localhost'"
GRANT_CREATED=1
mariadb-dump --single-transaction --skip-lock-tables --no-tablespaces tdsqam > "$WORK/synthetic.sql"
mariadb "$DB_NAME" < "$WORK/synthetic.sql"
rm -f -- "$WORK/synthetic.sql"
cp -a -- "$WPO" "$WORK/site"
# Replace ONLY the private clone plugin with the exact PR #238 Git tree.
# The original WordPress installation and working source branch are untouched.
mkdir "$WORK/checkout"
git -C "$REPO" archive "$PR_HEAD" wordpress/tds-learnpress-editorial | tar -x -C "$WORK/checkout"
rm -rf -- "$WORK/site/wp-content/plugins/tds-learnpress-editorial"
cp -a -- "$WORK/checkout/wordpress/tds-learnpress-editorial" "$WORK/site/wp-content/plugins/"
clone_sha=$(sha256sum "$WORK/site/wp-content/plugins/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php" | awk '{print $1}')
[ "$clone_sha" = "$EXPECTED_PLUGIN_SHA" ] || fail "clone PR exact hash mismatch"
echo "CLONE_PLUGIN_PR238=PASS sha256=$clone_sha"
php "$WPCLI" --allow-root --path="$WORK/site" config set DB_NAME "$DB_NAME" --type=constant >/dev/null
wpc() { php "$WPCLI" --allow-root --path="$WORK/site" "$@"; }
[ "$(wpc config get DB_NAME)" = "$DB_NAME" ] || fail "clone DB selection wrong"
wpc option update siteurl "$BASE" >/dev/null
wpc option update home "$BASE" >/dev/null
[ "$(wpo option get siteurl)" = 'http://127.0.0.1:18732' ] || fail "original changed"
cat > "$WORK/router.php" <<'PHP'
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = $_SERVER['DOCUMENT_ROOT'] . $path;
if (is_file($file) && !str_contains($path, '..')) return false;
require $_SERVER['DOCUMENT_ROOT'] . '/index.php';
PHP
php -S 127.0.0.1:18736 -t "$WORK/site" "$WORK/router.php" > "$WORK/http.log" 2>&1 &
HTTP_PID=$!
for n in 1 2 3 4 5 6 7 8 9 10; do
 if curl --noproxy '*' -fsS --max-time 2 -o /dev/null "$BASE/"; then break; fi
 sleep 0.4
done
[ "$(curl --noproxy '*' --max-time 3 -s -o /dev/null -w '%{http_code}' "$BASE/")" = 200 ] || fail "cloned WP unavailable"
echo "WP_REAL_RUNTIME=PASS isolated_mysql_clone=PASS"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/probe_rights.py" "$BASE" "$WPCLI" "$WORK/site"
# Recover the missing LearnPress editor capabilities only in the disposable
# MariaDB fixture. Do not grant permissions in the original or institutional WP.
python3 "$SCRIPT_DIR/probe_edit_rbac.py" "$WPCLI" "$WORK/site" "$BASE"
echo "QA_RUN=PASS public_source_untouched=PASS rbac_editor_fixture=PASS"
