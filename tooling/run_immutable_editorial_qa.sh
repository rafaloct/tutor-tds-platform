#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(hostname)" = srv1533541 ] || exit 90
umask 077
BASE=/opt/tds-learning-qa-20261017
SOURCE="$BASE/immutable-qa-4dc75881-20261019"
PIN=7c9d4b3771640e63a3df30799a8aebdb97b4bc8b02f96c568d0acb4fbfae2e51
DB=tds-learning-qa-db-20261017
NET=tds-learning-qa-20261017
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
TMP=tds-immutable-editorial-$STAMP
CLONE_DB=tds_registration_299r_immutable_$STAMP
CLONE_USER=qi_$STAMP
CLONE_DIR="$BASE/immutable-clone-$STAMP"
EVIDENCE="$BASE/backups/$STAMP-immutable-editorial"
PACKAGE=$(cd "$(dirname "$0")/.." && pwd)
CREATED_DB=0; CREATED_USER=0; CREATED_CONTAINER=0; CREATED_DIR=0
mkdir -m700 "$EVIDENCE"
exec > >(tee "$EVIDENCE/run.log") 2>&1
verify_source() {
  [ "$(sha256sum "$SOURCE/manifest.json" | awk '{print $1}')" = "$PIN" ] || return 1
  python3 - "$SOURCE" <<'PY'
import sys,json,hashlib,pathlib
p=pathlib.Path(sys.argv[1]); m=json.loads((p/'manifest.json').read_text())
assert all(hashlib.sha256((p/n).read_bytes()).hexdigest()==h for n,h in m['files'].items())
assert not (p/'files/wordpress/wp-config.php').exists()
print('PASS immutable source all hashes; no runtime DB config')
PY
}
cleanup() {
  rc=$?; trap - EXIT INT TERM
  if [ "$CREATED_CONTAINER" = 1 ]; then
    docker cp "$TMP":/tmp/qa299-php.log "$EVIDENCE/php-private.log" >/dev/null 2>&1 || true
    docker rm -f "$TMP" >/dev/null || rc=6
  fi
  if [ "$CREATED_DB" = 1 ]; then
    docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE \`$CLONE_DB\`"' >/dev/null 2>&1 || rc=6
  fi
  if [ "$CREATED_USER" = 1 ]; then
    docker exec -e CLONE_USER="$CLONE_USER" "$DB" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP USER \`$CLONE_USER\`@\"%\""' >/dev/null 2>&1 || rc=6
  fi
  if [ "$CREATED_DIR" = 1 ]; then
    case "$CLONE_DIR" in "$BASE"/immutable-clone-20*) rm -rf -- "$CLONE_DIR";; *) rc=6;; esac
  fi
  verify_source || rc=7
  [ ! -e "$CLONE_DIR" ] && echo ROLLBACK_FILESYSTEM=PASS || rc=6
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$TMP"; then rc=6; else echo ROLLBACK_CONTAINER=PASS; fi
  docker exec -e CLONE_DB="$CLONE_DB" -e CLONE_USER="$CLONE_USER" "$DB" sh -c 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"$CLONE_DB\"; SELECT COUNT(*) FROM mysql.user WHERE User=\"$CLONE_USER\""' 2>/dev/null > "$EVIDENCE/rollback-counts.txt"
  [ "$(tr '\n' ' ' < "$EVIDENCE/rollback-counts.txt")" = '0 0 ' ] && echo ROLLBACK_DB_USER=PASS || rc=6
  printf 'FINAL_EXIT=%s\nEVIDENCE=%s\n' "$rc" "$EVIDENCE"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
verify_source
[ "$(docker network inspect -f '{{.Internal}}' "$NET")" = true ]
[ ! -e "$CLONE_DIR" ]
! docker ps -a --format '{{.Names}}' | grep -Fxq "$TMP"
docker exec -e CLONE_DB="$CLONE_DB" -e CLONE_USER="$CLONE_USER" "$DB" sh -c 'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"$CLONE_DB\"; SELECT COUNT(*) FROM mysql.user WHERE User=\"$CLONE_USER\""' 2>/dev/null > "$EVIDENCE/collision-counts.txt"
[ "$(tr '\n' ' ' < "$EVIDENCE/collision-counts.txt")" = '0 0 ' ]
docker exec -e CLONE_DB="$CLONE_DB" "$DB" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE \`$CLONE_DB\` CHARACTER SET utf8mb4"' >/dev/null 2>&1
CREATED_DB=1
CLONE_PASSWORD=$(openssl rand -hex 24)
docker exec -e CLONE_DB="$CLONE_DB" -e CLONE_USER="$CLONE_USER" -e CLONE_PASSWORD="$CLONE_PASSWORD" "$DB" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER \`$CLONE_USER\`@\"%\" IDENTIFIED BY \"$CLONE_PASSWORD\"; GRANT ALL PRIVILEGES ON \`$CLONE_DB\`.* TO \`$CLONE_USER\`@\"%\""' >/dev/null 2>&1
CREATED_USER=1
docker exec -i -e CLONE_DB="$CLONE_DB" "$DB" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$CLONE_DB"' < "$SOURCE/database.sql" 2>/dev/null
mkdir -m700 "$CLONE_DIR"; CREATED_DIR=1
cp -a "$SOURCE/files/wordpress/." "$CLONE_DIR/"
mkdir -p "$CLONE_DIR/wp-content/mu-plugins"
cp "$PACKAGE/wordpress/institutional-patches/issue-299/qa-resume/qa-isolation.php" "$CLONE_DIR/wp-content/mu-plugins/qa-isolation.php"
find "$CLONE_DIR" -type d -exec chgrp 33 {} + -exec chmod 0750 {} +
find "$CLONE_DIR" -type f -exec chgrp 33 {} + -exec chmod 0640 {} +
chmod 0710 "$CLONE_DIR"
IMAGE=$(docker inspect -f '{{.Image}}' tds-learning-qa-wp-20261017)
echo "WORDPRESS_IMAGE=$IMAGE"
docker run -d --name "$TMP" --network "$NET" --restart=no \
  -e WORDPRESS_DB_HOST="$DB:3306" -e WORDPRESS_DB_NAME="$CLONE_DB" \
  -e WORDPRESS_DB_USER="$CLONE_USER" -e WORDPRESS_DB_PASSWORD="$CLONE_PASSWORD" \
  -e WORDPRESS_TABLE_PREFIX=tdsqa_ -v "$CLONE_DIR:/var/www/html" "$IMAGE" >/dev/null
CREATED_CONTAINER=1
docker cp "$SOURCE/wp-cli.phar" "$TMP":/tmp/wp-cli.phar >/dev/null
wp() { docker exec "$TMP" php /tmp/wp-cli.phar --allow-root "$@"; }
for tick in $(seq 1 20); do [ -f "$CLONE_DIR/wp-config.php" ] && break; sleep 1; done
wp config set DISABLE_WP_CRON true --raw >/dev/null
wp config set WP_DEBUG true --raw >/dev/null
wp config set WP_DEBUG_LOG /tmp/qa299-php.log >/dev/null
wp config set WP_DEBUG_DISPLAY false --raw >/dev/null
[ "$(wp config get DB_NAME)" = "$CLONE_DB" ]
[ "$(wp core version)" = 6.7.2 ]
[ "$(wp plugin get learnpress --field=version)" = 4.3.6 ]
wp option update home http://tds-registration-299 >/dev/null
wp option update siteurl http://tds-registration-299 >/dev/null
wp theme activate tds-child-theme >/dev/null
wp eval '$r=get_role("administrator"); foreach(["edit_lp_lessons","edit_others_lp_lessons","edit_published_lp_lessons","edit_lp_courses","edit_others_lp_courses","edit_published_lp_courses"] as $c) $r->add_cap($c);' >/dev/null
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$TMP")
[ -z "$(docker port "$TMP")" ]
for path in wp-content/mu-plugins/qa-isolation.php wp-content/themes/tds-child-theme/functions.php wp-content/plugins/tds-learnpress-editorial/tds-learnpress-editorial.php; do docker exec -u www-data "$TMP" test -r "/var/www/html/$path"; done
curl --noproxy '*' --resolve "tds-registration-299:80:$IP" -fsS 'http://tds-registration-299/?tds_qa_probe=1' > "$EVIDENCE/apache-probe.json"
jq -e '.sapi=="apache2handler" and .mu_loaded and .mail_short_circuit and .http_short_circuit and (.post_gate_open==false)' "$EVIDENCE/apache-probe.json" >/dev/null
echo 'PASS Apache UID33, MU loaded, native mail/HTTP blocked, POST gate closed, private network/no ports'
# Canonical media host is only a projection setting in the disposable database.
wp option update home https://ead.ipexdesenvolvimento.cloud >/dev/null
docker exec "$TMP" touch /tmp/qa299-posts-enabled
docker exec "$TMP" chmod 0644 /tmp/qa299-posts-enabled
python3 "$PACKAGE/wordpress/institutional-patches/issue-299/qa-adapter/test_editorial.py" "$IP" "$TMP" "$EVIDENCE"
printf 'ANDROID_READY IP=%s CONTAINER=%s EVIDENCE=%s\n' "$IP" "$TMP" "$EVIDENCE"
for tick in $(seq 1 300); do [ -f "$EVIDENCE/android-finished" ] && break; sleep 2; done
wp eval 'global $wpdb; if((int)$wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items")!==0)throw new Exception("academic mutation");' >/dev/null
echo 'PASS zero academic rows after Android'
echo RESULT=PASS
