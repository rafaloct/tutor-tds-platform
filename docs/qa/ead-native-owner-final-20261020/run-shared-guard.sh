#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(hostname)" = srv1533541 ] || exit 90
umask 077
BASE=/opt/tds-learning-qa-20261017
ORIG_WP=tds-learning-qa-wp-20261017
DB=tds-learning-qa-db-20261017
NET=tds-learning-qa-20261017
TMP=tds-native-owner-297
CLONE_DB=tds_native_owner_297
CLONE_USER=tds_native_owner_297
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE="$BASE/backups/$STAMP-native-owner-297"
CLONE_DIR="$BASE/native-owner-297-$STAMP"
HOST=tds-native-owner-297
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
      "$BASE"/native-owner-297-*) rm -rf -- "$CLONE_DIR" || rc=6 ;;
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
cp /tmp/tds-issue297-candidate-admin.php "$CLONE_DIR/wp-content/plugins/tds-learnpress-editorial/includes/class-tds-learnpress-editorial-admin.php"
cp /tmp/tds-issue297-candidate-entry.php "$CLONE_DIR/wp-content/plugins/tds-learnpress-editorial/tds-learnpress-editorial.php"
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

access_code() {
  curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$1" -o "$2" -w '%{http_code}' "$URL/wp-admin/post.php?post=$3&action=edit"
}
T_OWN=$(access_code "$TC" "$CLONE_DIR/teacher-edit.html" "$LESSON")
T_OTHER=$(access_code "$TC" "$CLONE_DIR/teacher-other.html" "$OTHER_LESSON")
A_OTHER=$(access_code "$AC" "$CLONE_DIR/admin-other.html" "$OTHER_LESSON")
S_OWN=$(access_code "$SC" "$CLONE_DIR/subscriber-edit.html" "$LESSON")
[ "$T_OWN" = 200 ] || fail "LP Instructor own lesson editor access"
case "$T_OTHER" in 401|403|500) grep -q 'name="post_ID"' "$CLONE_DIR/teacher-other.html" && fail "LP Instructor reached other lesson editor" || : ;; *) fail "LP Instructor other lesson denial";; esac
[ "$A_OTHER" = 200 ] || fail "administrator lesson editor access"
case "$S_OWN" in 401|403|500) grep -q 'name="post_ID"' "$CLONE_DIR/subscriber-edit.html" && fail "subscriber reached lesson editor" || : ;; *) fail "subscriber lesson editor denial";; esac
grep -q 'name="tds_mobile_lesson_nonce"' "$CLONE_DIR/teacher-edit.html" || fail "editorial metabox nonce absent"
E_OWN=$(access_code "$EC" "$CLONE_DIR/editor-edit.html" "$LESSON")
V_OWN=$(access_code /dev/null "$CLONE_DIR/visitor-edit.html" "$LESSON")
for denied in teacher-other subscriber-edit editor-edit visitor-edit; do
  if grep -q 'name="post_ID"' "$CLONE_DIR/$denied.html"; then fail "unauthorized form exposed"; fi
done
printf 'GET_NEGATIVE_STATUS teacher_other=%s subscriber=%s editor=%s visitor=%s\n' "$T_OTHER" "$S_OWN" "$E_OWN" "$V_OWN"
pass "browser RBAC denied unauthorized editors (statuses instructor-other=$T_OTHER subscriber=$S_OWN); authorized pages=200"

nonce_from() {
  python3 - "$1" "$2" <<'PY'
from html.parser import HTMLParser
import sys
class P(HTMLParser):
    value = None
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == "input" and d.get("name") == sys.argv[2]:
            self.value = d.get("value", "")
p=P(); p.feed(open(sys.argv[1], encoding="utf-8", errors="replace").read())
if not p.value: raise SystemExit(1)
print(p.value)
PY
}
post_edit() {
  page="$1"; title="$2"; video="$3"; rights="$4"; nonce_mode="$5"; output="$6"
  form="$output.form"
  python3 - "$page" "$form" "$title" "$video" "$rights" "$nonce_mode" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urlencode
import sys
page, target, title, video, rights, nonce_mode = sys.argv[1:]
class Form(HTMLParser):
    def __init__(self):
        super().__init__(); self.active=False; self.pairs=[]; self.select=None; self.options=[]; self.option=None
    def handle_starttag(self, tag, attrs):
        d=dict(attrs)
        if tag == "form" and d.get("id") == "post": self.active=True
        elif self.active and tag == "input" and d.get("name") and "disabled" not in d:
            typ=d.get("type","text").lower()
            if typ not in ("submit","button","image","file","reset") and (typ not in ("checkbox","radio") or "checked" in d):
                self.pairs.append((d["name"], d.get("value","")))
        elif self.active and tag == "select" and d.get("name"):
            self.select=d["name"]; self.options=[]
        elif self.select and tag == "option":
            self.option=[d.get("value",""), "selected" in d]; self.options.append(self.option)
    def handle_endtag(self, tag):
        if tag == "form": self.active=False
        if tag == "select" and self.select:
            selected=[o for o in self.options if o[1]] or self.options[:1]
            self.pairs.extend((self.select,o[0]) for o in selected); self.select=None
p=Form(); p.feed(open(page, encoding="utf-8", errors="replace").read())
if not any(k == "_wpnonce" for k,v in p.pairs) or not any(k == "tds_mobile_lesson_nonce" for k,v in p.pairs):
    raise SystemExit("required form nonces absent")
overrides = {
    "action":"editpost", "post_ID":"13", "post_type":"lp_lesson",
    "post_status":"publish", "original_post_status":"publish",
    "post_title":title,
    "content":"<h2>Homologa��o institucional sint�tica</h2><p>Fluxo HTTP real, sem dados pessoais.</p>",
    "tds_mobile_public":"1", "tds_mobile_youtube_id":video,
    "tds_mobile_poster_url":"https://tds-native-owner-297/wp-content/uploads/qa-poster.jpg",
    "tds_mobile_captions_url":"https://tds-native-owner-297/wp-content/uploads/qa-caption.vtt",
}
if video.startswith("mp4"):
    overrides["tds_mobile_youtube_id"]=""
    base="https://tds-native-owner-297/wp-content/uploads/tutor-tds/qa/"
    overrides["content"]='<h2>QA MP4</h2><p>Native HTTP content.</p><video controls><source src="'+base+video+'.mp4"><track kind="captions" src="'+base+video+'.vtt" srclang="pt-BR"></video>'
if rights == "1": overrides["tds_mobile_rights_approved"] = "1"
if nonce_mode == "csrf": overrides["_wpnonce"]="invalid-native-nonce"
if nonce_mode == "draft": overrides["post_status"]="draft"
if nonce_mode == "invalid": overrides["tds_mobile_lesson_nonce"] = "definitely-invalid"
pairs = [(k,v) for k,v in p.pairs if k not in overrides]
pairs.extend(overrides.items())
open(target, "w", encoding="ascii").write(urlencode(pairs))
PY
  status=$(curl --noproxy '*' --resolve "$HOST:80:$IP" -sS -b "$TC" -o "$output" -w '%{http_code}'     -H 'Content-Type: application/x-www-form-urlencoded' --data-binary "@$form" "$URL/wp-admin/post.php")
  rm -f -- "$form"
  printf '%s' "$status"
}
# A second course owned by a different instructor shares the same lesson.
docker exec -e QA_B_COURSE="$BCOURSE" "$TMP" php /tmp/wp-cli.phar --allow-root --path=/var/www/html eval 'global $wpdb; $s=$wpdb->prefix."learnpress_sections"; $i=$wpdb->prefix."learnpress_section_items"; $b=(int)getenv("QA_B_COURSE"); $ok=$wpdb->insert($s,["section_name"=>"QA shared parent","section_course_id"=>$b,"section_order"=>99,"section_description"=>""]); if($ok!==1)throw new Exception("section insert failed"); $sid=$wpdb->insert_id; $ok=$wpdb->insert($i,["section_id"=>$sid,"item_id"=>13,"item_order"=>1,"item_type"=>"lp_lesson"]); if($ok!==1)throw new Exception("item insert failed");' >/dev/null
PARENTS=$(wp eval 'global $wpdb; echo json_encode($wpdb->get_results("SELECT s.section_course_id,p.post_author FROM {$wpdb->prefix}learnpress_section_items i JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id=i.section_id JOIN {$wpdb->posts} p ON p.ID=s.section_course_id WHERE i.item_id=13 ORDER BY s.section_course_id"));')
printf 'SHARED_PARENTS=%s\n' "$PARENTS"
BEFORE_TITLE=$(wp post get "$LESSON" --field=post_title)
BEFORE_COURSE_STATUS=$(wp post get "$COURSE" --field=post_status)
BEFORE_B_STATUS=$(wp post get "$BCOURSE" --field=post_status)
GET_SHARED=$(access_code "$TC" "$CLONE_DIR/shared-get.html" "$LESSON")
[ "$GET_SHARED" = 403 ] || fail "shared GET denial status=$GET_SHARED"
! grep -q 'name="post_ID"' "$CLONE_DIR/shared-get.html" || fail "shared form leaked"
HTTP_SHARED=$(post_edit "$CLONE_DIR/teacher-edit.html" "QA shared must not mutate" 123456789ab 1 valid "$CLONE_DIR/shared-save.html")
AFTER_TITLE=$(wp post get "$LESSON" --field=post_title)
AFTER_COURSE_STATUS=$(wp post get "$COURSE" --field=post_status)
AFTER_B_STATUS=$(wp post get "$BCOURSE" --field=post_status)
printf 'SHARED_POST status=%s title_mutated=%s own_course_before=%s own_course_after=%s other_course_before=%s other_course_after=%s\n' "$HTTP_SHARED" "$([ "$BEFORE_TITLE" != "$AFTER_TITLE" ] && echo yes || echo no)" "$BEFORE_COURSE_STATUS" "$AFTER_COURSE_STATUS" "$BEFORE_B_STATUS" "$AFTER_B_STATUS"
[ "$HTTP_SHARED" = 403 ] || fail "shared POST denial status=$HTTP_SHARED"
[ "$BEFORE_TITLE" = "$AFTER_TITLE" ] || fail "shared denied POST mutated lesson"
[ "$BEFORE_COURSE_STATUS" = "$AFTER_COURSE_STATUS" ] || fail "shared denied POST touched own course"
[ "$BEFORE_B_STATUS" = "$AFTER_B_STATUS" ] || fail "shared denied POST touched other course"
# Administrator still edits the shared lesson through the native form.
TC="$AC"
ADMIN_GET=$(access_code "$AC" "$CLONE_DIR/admin-shared.html" "$LESSON")
[ "$ADMIN_GET" = 200 ] || fail "admin shared GET"
ADMIN_POST=$(post_edit "$CLONE_DIR/admin-shared.html" "QA admin shared save" 123456789ab 1 valid "$CLONE_DIR/admin-shared-save.html")
[ "$ADMIN_POST" = 302 ] || fail "admin shared POST status=$ADMIN_POST"
[ "$(wp post get "$LESSON" --field=post_title)" = 'QA admin shared save' ] || fail "admin shared readback"
printf 'ADMIN_SHARED_SAVE=PASS status=%s\n' "$ADMIN_POST"
wp eval 'global $wpdb; if((int)$wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items")!==0)throw new Exception("academic mutation");' >/dev/null
printf 'ACADEMIC_ROWS=0\n'
printf 'RESULT=PASS\n'