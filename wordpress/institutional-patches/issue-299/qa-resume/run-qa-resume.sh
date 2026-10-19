#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(hostname)" = srv1533541 ] || exit 90
umask 077
BASE=/opt/tds-learning-qa-20261017
ORIG_WP=tds-learning-qa-wp-20261017
DB=tds-learning-qa-db-20261017
NET=tds-learning-qa-20261017
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
TMP=tds-registration-299r-$STAMP
CLONE_DB=tds_registration_299r_$STAMP
CLONE_USER=q299r_$STAMP
EVIDENCE="$BASE/backups/$STAMP-registration-299-resume"
CLONE_DIR="$BASE/registration-299-resume-$STAMP"
HOST=tds-registration-299
URL="http://$HOST"
LESSON=13
OTHER_LESSON=14
COURSE=614
CREATED_DB=0
CREATED_USER=0
CREATED_CONTAINER=0
CREATED_DIR=0
PACKAGE=$(cd "$(dirname "$0")/.." && pwd)
RESUME="$PACKAGE/qa-resume"
mkdir -m 700 "$EVIDENCE"
exec > >(tee "$EVIDENCE/run.log") 2>&1
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; exit 1; }
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  if [ "$CREATED_CONTAINER" = 1 ]; then
    docker logs "$TMP" > "$EVIDENCE/clone-container.log" 2>&1 || true
    docker cp "$TMP":/tmp/qa299-php.log "$EVIDENCE/php-restricted.log" >/dev/null 2>&1 || true
    if [ -f "$EVIDENCE/php-restricted.log" ]; then
      grep -E "QA299_|Fatal error|Uncaught" "$EVIDENCE/php-restricted.log" > "$EVIDENCE/php-diagnostics.log" || true
    fi
    docker rm -f "$TMP" >/dev/null 2>&1 || rc=6
  fi
  if [ "$CREATED_DB" = 1 ]; then
    docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$CLONE_DB\`"' >/dev/null 2>&1 || rc=6
  fi
  if [ "$CREATED_USER" = 1 ]; then
    docker exec -e CLONE_USER="$CLONE_USER" "$DB" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP USER IF EXISTS \`$CLONE_USER\`@\"%\""' >/dev/null 2>&1 || rc=6
  fi
  if [ "$CREATED_DIR" = 1 ]; then
    case "$CLONE_DIR" in
      "$BASE"/registration-299-*) rm -rf -- "$CLONE_DIR" || rc=6 ;;
      *) printf 'FAIL unsafe clone cleanup path\n'; rc=6 ;;
    esac
  fi
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$TMP"; then
    printf 'ROLLBACK_CONTAINER=FAIL\n'; rc=6
  else
    printf 'ROLLBACK_CONTAINER=PASS\n'
  fi
  if docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"$CLONE_DB\""' 2>/dev/null | grep -Fxq 0; then
    printf 'ROLLBACK_DB=PASS\n'
  else
    printf 'ROLLBACK_DB=FAIL\n'; rc=6
  fi
  if docker exec -e CLONE_USER="$CLONE_USER" "$DB" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM mysql.user WHERE User=\"$CLONE_USER\""' 2>/dev/null | grep -Fxq 0; then
    printf 'ROLLBACK_DB_USER=PASS\n'
  else
    printf 'ROLLBACK_DB_USER=FAIL\n'; rc=6
  fi
  if [ ! -e "$CLONE_DIR" ]; then
    printf 'ROLLBACK_FILESYSTEM=PASS\n'
  else
    printf 'ROLLBACK_FILESYSTEM=FAIL\n'; rc=6
  fi
  if [ -f "$EVIDENCE/source-before.sql" ]; then
    docker exec "$DB" sh -lc 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --skip-lock-tables --skip-comments --hex-blob tds_learning_qa_synthetic' > "$EVIDENCE/source-after.sql" 2>/dev/null
    cmp -s "$EVIDENCE/source-before.sql" "$EVIDENCE/source-after.sql" && printf 'BASE_DATABASE_UNCHANGED=PASS\n' || rc=7
    sha256sum "$EVIDENCE/source-before.sql" "$EVIDENCE/source-after.sql" | sed 's|/.*|database|'
    # Keep restricted recoverable dumps, especially on divergence; never publish them.
  fi
  printf 'EVIDENCE_DIR=%s\n' "$EVIDENCE"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[ "$(docker inspect -f '{{.State.Running}}' "$ORIG_WP")" = true ] || fail "source WordPress not running"
[ "$(docker inspect -f '{{.State.Running}}' "$DB")" = true ] || fail "source MySQL not running"
[ "$(docker network inspect "$NET" | jq -r '.[0].Internal')" = true ] || fail "network is not internal"
docker ps -a --format '{{.Names}}' | grep -Fxq "$TMP" && fail "temporary container collision"
[ ! -e "$CLONE_DIR" ] || fail "temporary directory collision"
if docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"$CLONE_DB\""' 2>/dev/null | grep -Fxq 0; then :; else fail "temporary database collision"; fi
if docker exec -e CLONE_USER="$CLONE_USER" "$DB" sh -lc 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM mysql.user WHERE User=\"$CLONE_USER\""' 2>/dev/null | grep -Fxq 0; then :; else fail "temporary database user collision"; fi
SOURCE_STARTED=$(docker inspect -f '{{.State.StartedAt}}' "$ORIG_WP")
SOURCE_PLUGIN_SHA=$(sha256sum "$BASE/wp-data/wp-content/plugins/tds-learnpress-editorial/includes/class-tds-learnpress-editorial-admin.php" | awk '{print $1}')
[ "$SOURCE_PLUGIN_SHA" = eedf01c063ea3cd1718f92cc3e621b50b79705d374449d083701e1a7458be4da ] || fail "installed plugin source mismatch"
docker exec "$DB" sh -lc 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --skip-lock-tables --skip-comments --hex-blob tds_learning_qa_synthetic' > "$EVIDENCE/source-before.sql" 2>/dev/null
SOURCE_DB_BEFORE=$(sha256sum "$EVIDENCE/source-before.sql" | awk '{print $1}')
[ "$SOURCE_DB_BEFORE" = 4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16 ] || fail "new baseline divergence STOP"
pass "source staging identity, internal network and candidate hash"

docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE \`$CLONE_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"' >/dev/null 2>&1
CREATED_DB=1
CLONE_PASSWORD=$(openssl rand -hex 24)
docker exec -e CLONE_DB="$CLONE_DB" -e CLONE_USER="$CLONE_USER" -e CLONE_PASSWORD="$CLONE_PASSWORD" "$DB" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER \`$CLONE_USER\`@\"%\" IDENTIFIED BY \"$CLONE_PASSWORD\"; GRANT ALL PRIVILEGES ON \`$CLONE_DB\`.* TO \`$CLONE_USER\`@\"%\""' >/dev/null 2>&1
CREATED_USER=1
docker exec -i -e CLONE_DB="$CLONE_DB" "$DB" sh -lc 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$CLONE_DB"' < "$EVIDENCE/source-before.sql" 2>/dev/null
mkdir -m 700 "$CLONE_DIR"
CREATED_DIR=1
cp -a "$BASE/wp-data/." "$CLONE_DIR/"
mkdir -p "$CLONE_DIR/wp-content/mu-plugins"
cp "$RESUME/qa-isolation.php" "$CLONE_DIR/wp-content/mu-plugins/qa-isolation.php"
python3 "$PACKAGE/acquire_theme.py" "$CLONE_DIR/wp-content/themes/tds-child-theme" "$EVIDENCE"
docker cp compose-program-open-source-monitor-szkpni-wordpress-1:/var/www/html/wp-content/themes/astra "$CLONE_DIR/wp-content/themes/astra" >/dev/null
tar -czf "$EVIDENCE/sanitized-institutional-theme-before.tgz" -C "$CLONE_DIR/wp-content/themes" tds-child-theme astra
cp "$PACKAGE/fixture.php" "$CLONE_DIR/.registration-fixture.php"

WP_DB_HOST=$(docker inspect "$ORIG_WP" | jq -r '.[0].Config.Env[] | select(startswith("WORDPRESS_DB_HOST=")) | sub("^WORDPRESS_DB_HOST=";"")')
WP_DB_USER="$CLONE_USER"
WP_DB_PASSWORD="$CLONE_PASSWORD"
WP_TABLE_PREFIX=$(docker inspect "$ORIG_WP" | jq -r '.[0].Config.Env[] | select(startswith("WORDPRESS_TABLE_PREFIX=")) | sub("^WORDPRESS_TABLE_PREFIX=";"")')
WP_DEBUG=$(docker inspect "$ORIG_WP" | jq -r '.[0].Config.Env[] | select(startswith("WORDPRESS_DEBUG=")) | sub("^WORDPRESS_DEBUG=";"")')
[ -n "$WP_DB_HOST" ] && [ -n "$WP_DB_USER" ] && [ -n "$WP_DB_PASSWORD" ] && [ -n "$WP_TABLE_PREFIX" ] || fail "source WordPress DB environment incomplete"
cat > "$CLONE_DIR/.acceptance-caps.php" <<'PHP'
<?php
$admin = get_role('administrator');
if (!$admin) { throw new Exception('administrator role missing'); }
foreach (array('edit_lp_lessons','edit_others_lp_lessons','edit_published_lp_lessons','edit_lp_courses','edit_others_lp_courses','edit_published_lp_courses') as $cap) {
    $admin->add_cap($cap);
}
$caps = array_fill_keys(array(
    'delete_lp_courses','delete_lp_lessons','delete_published_lp_courses',
    'delete_published_lp_lessons','edit_lp_courses','edit_lp_lessons',
    'edit_posts','edit_published_lp_courses','edit_published_lp_lessons',
    'publish_lp_lessons','read','read_private_lp_courses',
    'read_private_lp_lessons','upload_files'
), true);
$teacher = get_role('lp_teacher');
if (!$teacher) { $teacher = add_role('lp_teacher', 'LP Instructor', $caps); }
else { foreach ($caps as $cap => $grant) { $teacher->add_cap($cap, $grant); } }
if (!$teacher) { throw new Exception('lp_teacher role unavailable'); }
PHP

docker run -d --name "$TMP" --network "$NET" --restart=no \
  -e WORDPRESS_DB_HOST="$WP_DB_HOST" \
  -e WORDPRESS_DB_USER="$WP_DB_USER" \
  -e WORDPRESS_DB_PASSWORD="$WP_DB_PASSWORD" \
  -e WORDPRESS_DB_NAME="$CLONE_DB" \
  -e WORDPRESS_TABLE_PREFIX="$WP_TABLE_PREFIX" \
  -e WORDPRESS_DEBUG="$WP_DEBUG" \
  -v "$CLONE_DIR:/var/www/html" wordpress:6.7-php8.2-apache >/dev/null
CREATED_CONTAINER=1
docker cp "$BASE/wp-cli" "$TMP":/tmp/wp-cli.phar >/dev/null
wp() { docker exec "$TMP" php /tmp/wp-cli.phar --allow-root --path=/var/www/html "$@"; }
wp config set DISABLE_WP_CRON true --raw >/dev/null
wp config set WP_DEBUG true --raw >/dev/null
wp config set WP_DEBUG_LOG /tmp/qa299-php.log >/dev/null
wp config set WP_DEBUG_DISPLAY false --raw >/dev/null
# Only copied code is changed. Evidence, dumps and all credential material stay private.
readable_code() {
  local path="$1"
  case "$path" in "$CLONE_DIR"/wp-content/themes/tds-child-theme|"$CLONE_DIR"/wp-content/themes/astra|"$CLONE_DIR"/wp-content/mu-plugins) ;; *) fail "unsafe permission target";; esac
  [ -z "$(find "$path" -type l -print -quit)" ] || fail "code symlink rejected"
  find "$path" -type d -exec chgrp 33 {} + -exec chmod 0750 {} +
  find "$path" -type f -exec chgrp 33 {} + -exec chmod 0640 {} +
}
chgrp 33 "$CLONE_DIR"
chmod 0710 "$CLONE_DIR"
readable_code "$CLONE_DIR/wp-content/themes/tds-child-theme"
readable_code "$CLONE_DIR/wp-content/themes/astra"
readable_code "$CLONE_DIR/wp-content/mu-plugins"
# Intermediate directories inside the bind mount, not parents of the host source.
for path in "$CLONE_DIR/wp-content" "$CLONE_DIR/wp-content/themes"; do
  chgrp 33 "$path"; chmod 0750 "$path"
done
docker exec "$TMP" sh -c 'id www-data; namei -l /var/www/html/wp-content/themes/tds-child-theme/pages/cadastro.php; namei -l /var/www/html/wp-content/mu-plugins/qa-isolation.php' > "$EVIDENCE/permissions.txt"
for path in wp-content/themes/tds-child-theme/functions.php wp-content/themes/tds-child-theme/pages/cadastro.php wp-content/themes/tds-child-theme/includes/admin-cadastro-aluno.php wp-content/themes/tds-child-theme/style.css wp-content/themes/astra/functions.php wp-content/themes/astra/style.css wp-content/mu-plugins/qa-isolation.php; do
  docker exec -u www-data "$TMP" test -r "/var/www/html/$path" || fail "Apache cannot read copied code"
done
[ -z "$(docker port "$TMP")" ] || fail "unexpected published port"
pass "Apache UID33 can traverse and read theme/Astra/MU; code group permissions only"

wp option update home "$URL" >/dev/null
wp option update siteurl "$URL" >/dev/null
for n in $(seq 1 30); do
  IP=$(docker inspect "$TMP" | jq -r '.[0].NetworkSettings.Networks[] | .IPAddress')
  code=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -o /dev/null -w '%{http_code}' "$URL/" || true)
  [ "$code" = 200 ] && break
  sleep 1
done
[ "${code:-}" = 200 ] || fail "cloned WordPress unavailable"
[ "$(wp config get DB_NAME)" = "$CLONE_DB" ] || fail "clone did not select cloned database"
[ "$(wp option get home)" = "$URL" ] || fail "clone home mismatch"
wp eval-file /var/www/html/.acceptance-caps.php >/dev/null
pass "isolated WordPress and MySQL clone started with mirrored institutional capabilities"


wp theme activate tds-child-theme >/dev/null
wp option update permalink_structure '/%postname%/' >/dev/null
wp eval-file /var/www/html/.registration-fixture.php > "$EVIDENCE/fixture.json"
wp rewrite flush --hard >/dev/null
python3 "$RESUME/preflight.py" "$IP" "$EVIDENCE"
python3 "$PACKAGE/test_http.py" "$IP" "$TMP" "$EVIDENCE" before
python3 "$PACKAGE/prepare_patch.py" "$CLONE_DIR/wp-content/themes/tds-child-theme" --diff "$EVIDENCE/theme.patch"
readable_code "$CLONE_DIR/wp-content/themes/tds-child-theme"
docker exec -u www-data "$TMP" test -r /var/www/html/wp-content/themes/tds-child-theme/includes/tds-registration-course.php
docker exec "$TMP" php -l /var/www/html/wp-content/themes/tds-child-theme/functions.php
docker exec "$TMP" php -l /var/www/html/wp-content/themes/tds-child-theme/pages/cadastro.php
docker exec "$TMP" php -l /var/www/html/wp-content/themes/tds-child-theme/includes/tds-registration-course.php
# Probe again after patch, still without POST.
python3 "$RESUME/preflight.py" "$IP" "$EVIDENCE"
docker exec "$TMP" touch /tmp/qa299-posts-enabled
docker exec "$TMP" chmod 0644 /tmp/qa299-posts-enabled
python3 "$PACKAGE/test_http.py" "$IP" "$TMP" "$EVIDENCE" after
[ "$(docker inspect -f '{{.State.StartedAt}}' "$ORIG_WP")" = "$SOURCE_STARTED" ] || fail "base container restart"
sha256sum "$EVIDENCE/theme.patch" "$EVIDENCE/theme-provenance.json" "$EVIDENCE/http-after.json"
printf 'RESULT=PASS\n'
