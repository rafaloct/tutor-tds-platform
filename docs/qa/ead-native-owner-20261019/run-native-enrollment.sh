#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(hostname)" = srv1533541 ] || exit 90
umask 077
BASE=/opt/tds-learning-qa-20261017
ORIG_WP=tds-learning-qa-wp-20261017
DB=tds-learning-qa-db-20261017
NET=tds-learning-qa-20261017
TMP=tds-native-enrollment-297
CLONE_DB=tds_native_enrollment_297
CLONE_USER=tds_native_enrollment_297
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE="$BASE/backups/$STAMP-native-enrollment-297"
CLONE_DIR="$BASE/native-enrollment-297-$STAMP"
HOST=tds-native-enrollment-297
URL="http://$HOST"
LESSON=13
OTHER_LESSON=14
COURSE=12
CREATED_DB=0
CREATED_USER=0
CREATED_CONTAINER=0
CREATED_DIR=0
mkdir -m 700 "$EVIDENCE"
exec > >(tee "$EVIDENCE/run.log") 2>&1
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; exit 1; }
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  if [ "$CREATED_CONTAINER" = 1 ]; then
    docker logs "$TMP" > "$EVIDENCE/clone-container.log" 2>&1 || true
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
      "$BASE"/native-enrollment-297-*) rm -rf -- "$CLONE_DIR" || rc=6 ;;
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
    rm -f -- "$EVIDENCE/source-before.sql" "$EVIDENCE/source-after.sql"
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

BPASS=$(openssl rand -hex 24)
EPASS=$(openssl rand -hex 24)
TPASS=$(openssl rand -hex 24)
APASS=$(openssl rand -hex 24)
SPASS=$(openssl rand -hex 24)
TID=$(wp user create tds-http-instructor "qa-prof-a@qa-synthetic.test" --role=lp_teacher --porcelain 2>/dev/null)
AID=$(wp user create tds-http-admin "qa-admin@qa-synthetic.test" --role=administrator --porcelain 2>/dev/null)
SID=$(wp user create tds-http-subscriber "qa-aluno@qa-synthetic.test" --role=subscriber --porcelain 2>/dev/null)
set_pass() {
  docker exec -e QA_UID="$1" -e QA_PASS="$2" "$TMP" php /tmp/wp-cli.phar --allow-root --path=/var/www/html eval '$u=get_user_by("id",(int)getenv("QA_UID")); if(!$u) throw new Exception("user"); wp_set_password(getenv("QA_PASS"),$u->ID);' >/dev/null
}
BID=$(wp user create qa-prof-b qa-prof-b@qa-synthetic.test --role=lp_teacher --porcelain 2>/dev/null)
EID=$(wp user create qa-editor qa-editor@qa-synthetic.test --role=editor --porcelain 2>/dev/null)
set_pass "$BID" "$BPASS"
set_pass "$EID" "$EPASS"
set_pass "$TID" "$TPASS"
set_pass "$AID" "$APASS"
set_pass "$SID" "$SPASS"
docker exec -e QA_TEACHER="$TID" -e QA_ADMIN="$AID" "$TMP" php /tmp/wp-cli.phar --allow-root --path=/var/www/html eval 'global $wpdb; $wpdb->update($wpdb->posts,array("post_author"=>(int)getenv("QA_TEACHER")),array("ID"=>13)); $wpdb->update($wpdb->posts,array("post_author"=>(int)getenv("QA_TEACHER")),array("ID"=>12)); $wpdb->update($wpdb->posts,array("post_author"=>(int)getenv("QA_ADMIN")),array("ID"=>14));' >/dev/null
BCOURSE=$(wp post create --post_type=lp_course --post_status=publish --post_title='QA Professor B' --post_author="$BID" --porcelain)
docker exec -e QA_B="$BID" -e QA_A="$TID" "$TMP" php /tmp/wp-cli.phar --allow-root eval 'global $wpdb; $wpdb->update($wpdb->posts,["post_author"=>(int)getenv("QA_B")],["ID"=>14]); wp_set_current_user((int)getenv("QA_A")); if(!current_user_can("edit_lp_course",12)||!current_user_can("edit_lp_lesson",13)||current_user_can("edit_others_lp_courses")||current_user_can("edit_others_lp_lessons"))throw new Exception("caps");' >/dev/null
pass "five synthetic accounts, own course and own lesson; no edit_others granted to teachers"

login_user() {
  user="$1"; password="$2"; cookie="$3"; page="$4"
  curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -c "$cookie" -o /dev/null "$URL/wp-login.php"
  status=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$cookie" -c "$cookie" -o "$page" -w '%{http_code}'     --data-urlencode "log=$user" --data-urlencode "pwd=$password" --data-urlencode "wp-submit=Log In"     --data-urlencode "redirect_to=$URL/wp-admin/" --data-urlencode "testcookie=1" "$URL/wp-login.php")
  [ "$status" = 302 ] && grep -q 'wordpress_logged_in_' "$cookie"
}
TC="$CLONE_DIR/teacher.cookies"; AC="$CLONE_DIR/admin.cookies"; SC="$CLONE_DIR/subscriber.cookies"
login_user tds-http-instructor "$TPASS" "$TC" "$CLONE_DIR/teacher-login.html" || fail "instructor login"
login_user tds-http-admin "$APASS" "$AC" "$CLONE_DIR/admin-login.html" || fail "administrator login"
login_user tds-http-subscriber "$SPASS" "$SC" "$CLONE_DIR/subscriber-login.html" || fail "subscriber login"
EC="$CLONE_DIR/editor.cookies"
login_user qa-editor "$EPASS" "$EC" "$CLONE_DIR/editor-login.html" || fail "editor login"
pass "real WordPress session cookies issued to synthetic roles"


COURSE_URL=$(wp eval 'echo get_permalink(12);')
printf 'REGISTRATION_POLICY=%s\n' "$(wp option get users_can_register)"
printf 'ACTIVE_THEME=%s\n' "$(wp option get stylesheet)"
printf 'COURSE_URL=%s\n' "$COURSE_URL"
for role in visitor student; do
  cookie=/dev/null; [ "$role" = student ] && cookie="$SC"
  code=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$cookie" -o "$CLONE_DIR/$role-course.html" -w '%{http_code}' "$COURSE_URL")
  printf 'COURSE_GET_%s=%s\n' "$role" "$code"
done
curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -o "$CLONE_DIR/register.html" -w 'REGISTER_GET=%{http_code}\n' "$URL/wp-login.php?action=register"
# Read actual frontend controls and REST nonce; never emit credentials/nonces.
python3 - "$CLONE_DIR/student-course.html" "$CLONE_DIR/rest-nonce" <<'PY'
import re,sys,json
s=open(sys.argv[1],encoding="utf-8",errors="replace").read()
print("ENROLL_FORM_PRESENT="+str('name="enroll-course"' in s))
print("ENROLL_BUTTON_PRESENT="+str('button-enroll-course' in s))
m=re.search(r'var\s+lpData\s*=\s*(\{.*?\});',s,re.S)
if not m:
    m=re.search(r'var\s+learn_press_js_localize\s*=\s*(\{.*?\});',s,re.S)
if not m: raise SystemExit("BLOCKED no frontend REST config")
d=json.loads(m.group(1))
nonce=d.get("nonce")
if not nonce: raise SystemExit("BLOCKED no native REST nonce")
open(sys.argv[2],"w").write(nonce)
PY
nonce=$(cat "$CLONE_DIR/rest-nonce")
for attempt in first duplicate; do
  status=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$SC" -H "X-WP-Nonce: $nonce" --data-urlencode "id=$COURSE" -o "$EVIDENCE/enroll-$attempt.json" -w '%{http_code}' "$URL/wp-json/lp/v1/courses/enroll-course")
  printf 'ENROLL_%s_HTTP=%s\n' "$attempt" "$status"
  jq '{status,message,data}' "$EVIDENCE/enroll-$attempt.json"
done
docker exec -e QA_STUDENT="$SID" "$TMP" php /tmp/wp-cli.phar --allow-root eval 'global $wpdb; echo json_encode($wpdb->get_results($wpdb->prepare("SELECT item_type,status,graduation,COUNT(*) AS rows_count FROM {$wpdb->prefix}learnpress_user_items WHERE user_id=%d GROUP BY item_type,status,graduation",(int)getenv("QA_STUDENT"))));' > "$EVIDENCE/enrollment-readback.json"
cat "$EVIDENCE/enrollment-readback.json"
# Missing/expired cookie must not enroll as the previous student.
status=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -H "X-WP-Nonce: $nonce" --data-urlencode "id=$COURSE" -o "$CLONE_DIR/expired.json" -w '%{http_code}' "$URL/wp-json/lp/v1/courses/enroll-course")
printf 'EXPIRED_SESSION_HTTP=%s\n' "$status"
printf 'NEW_PUBLIC_ACCOUNT=BLOCKED_REGISTRATION_DISABLED\n'
printf 'INSTITUTIONAL_THEME_E2E=UNKNOWN_THEME_NOT_PRESENT\n'

# Follow only the native redirect on the isolated origin and test logout.
redirect=$(jq -r '.data.redirect // empty' "$EVIDENCE/enroll-first.json")
case "$redirect" in "$URL/"*) ;; *) fail "unsafe or missing native enrollment redirect";; esac
for role in visitor student; do
 cookie=/dev/null; [ "$role" = student ] && cookie="$SC"
 code=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$cookie" -o "$CLONE_DIR/$role-lesson.html" -w '%{http_code}' "$redirect")
 printf 'LESSON_GET_%s=%s\n' "$role" "$code"
done
python3 - "$CLONE_DIR/student-course.html" "$CLONE_DIR/logout-url" "$URL" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urlparse, parse_qs
import sys
class P(HTMLParser):
    url=None
    def handle_starttag(self,t,attrs):
        d=dict(attrs); h=d.get("href",""); p=urlparse(h)
        if t=="a" and p.netloc==urlparse(sys.argv[3]).netloc and p.path.endswith("wp-login.php") and parse_qs(p.query).get("action")==["logout"]:
            self.url=h
p=P();p.feed(open(sys.argv[1],encoding="utf-8",errors="replace").read())
if p.url: open(sys.argv[2],"w").write(p.url)
print("LOGOUT_LINK_PRESENT="+str(bool(p.url)))
PY
if [ -f "$CLONE_DIR/logout-url" ]; then
 logout_url=$(cat "$CLONE_DIR/logout-url")
 code=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$SC" -c "$SC" -o "$CLONE_DIR/logout.html" -w '%{http_code}' "$logout_url")
 printf 'LOGOUT_HTTP=%s\n' "$code"
 code=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$SC" -H "X-WP-Nonce: $nonce" -o "$CLONE_DIR/after-logout.json" -w '%{http_code}' "$URL/wp-json/wp/v2/users/me")
 printf 'AFTER_LOGOUT_ME_HTTP=%s\n' "$code"
else
 printf 'LOGOUT_HTTP=UNKNOWN_NO_LINK\n'
fi
