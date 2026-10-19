#!/usr/bin/env python3
"""Issue #276: verify real LearnPress lesson edit capability in EPHEMERAL QA ONLY.

Never contacts an institutional installation. The owning shell runner
creates/destroys an isolated DB clone with five synthetic accounts.
The user-role changes below exist ONLY inside that disposable DB.
"""
from __future__ import annotations

import json
import re
import secrets
import subprocess
import sys
from http.cookiejar import CookieJar
from urllib.error import HTTPError
from urllib.parse import urlencode, urlsplit
from urllib.request import (
    HTTPCookieProcessor, HTTPRedirectHandler, Request, build_opener, urlopen
)

WPCLI, SITE, BASE = sys.argv[1:4]
if (not SITE.startswith("/workspace/tds-editorial236-") or
        not SITE.endswith("/site") or
        BASE != "http://127.0.0.1:18736"):
    raise SystemExit("BLOCKED clone path or loopback URL untrusted")

passed = 0
failed = 0


def check(name: str, ok: bool) -> None:
    global passed, failed
    print(("PASS " if ok else "FAIL ") + name, flush=True)
    passed += bool(ok)
    failed += not bool(ok)


def wp(*args: str, user: int | None = None) -> subprocess.CompletedProcess:
    argv = ["php", WPCLI, "--allow-root", "--path=" + SITE]
    if user is not None:
        argv.append("--user=" + str(user))
    argv.extend(args)
    return subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=25, check=False)


def wpeval(code: str, user: int | None = None) -> str:
    proc = wp("eval", code, user=user)
    if proc.returncode:
        raise RuntimeError("QA WP eval failed")
    return proc.stdout.strip()


def read_http(path: str, etag: str | None = None) -> tuple[int, str | None, dict | None]:
    headers = {"Accept": "application/json"}
    if etag:
        headers["If-None-Match"] = etag
    req = Request(BASE + path, headers=headers, method="GET")
    try:
        with urlopen(req, timeout=15) as response:
            status, tag = response.status, response.headers.get("ETag")
            payload = response.read(512001)
    except HTTPError as exc:
        status, tag = exc.code, exc.headers.get("ETag")
        payload = exc.read(512001)
    if len(payload) > 512000:
        raise RuntimeError("QA endpoint exceeded allowed size")
    try:
        body = json.loads(payload) if payload else None
    except (ValueError, UnicodeDecodeError):
        body = None
    return status, tag, body


def user_caps(user: int) -> dict:
    # No personal data exposed. Only numeric synthetic fixture capabilities.
    code = """
      $u=wp_get_current_user();
      $caps=array();
      foreach (array('edit_lp_lessons','edit_others_lp_lessons',
                     'edit_published_lp_lessons') as $cap) {
        $caps[$cap] = (int) user_can($u,$cap);
      }
      $caps['edit_lesson12'] = (int) user_can($u,'edit_lp_lesson',12);
      $caps['edit_lesson13'] = (int) user_can($u,'edit_lp_lesson',13);
      echo json_encode($caps);
    """
    return json.loads(wpeval(code, user=user))


db = wp("config", "get", "DB_NAME")
home = wp("option", "get", "home")
count = wpeval("""
  global $wpdb;
  $emails=$wpdb->get_col("SELECT user_email FROM {$wpdb->users}");
  $bad=0;
  foreach ($emails as $email) {
    if (!str_ends_with($email,'@qa-synthetic.test')) $bad++;
  }
  echo count($emails).':'.$bad;
""")
if (db.returncode or not re.fullmatch(r"tdsqa236_[A-Za-z0-9]+", db.stdout.strip()) or
        home.returncode or home.stdout.strip() != BASE or count != "5:0"):
    raise SystemExit("BLOCKED QA clone synthetic identity preflight failed")

lesson = "/wp-json/tds-learning/v1/courses/11/lessons/12"
curriculum = "/wp-json/tds-learning/v1/courses/11/curriculum"

admin_before = user_caps(1)
editor_before = user_caps(4)
subscriber_before = user_caps(2)
check("RB01 synthetic admin lacks LP lesson-edit caps initially",
      admin_before["edit_lesson12"] == 0 and admin_before["edit_lp_lessons"] == 0)
check("RB02 synthetic editor lacks LP lesson-edit caps initially",
      editor_before["edit_lesson12"] == 0 and editor_before["edit_lp_lessons"] == 0)
check("RB03 subscriber cannot edit LP lesson initially",
      subscriber_before["edit_lesson12"] == 0)

# In LearnPress 4.3.6, WP-CLI post update runs privileged core code and
# may persist a change even when a later LP hook raises a permission error.
# Never test HTTP-denial guarantees with privileged WP-CLI mutations.
initial_title = wp("post", "get", "12", "--field=post_title")
check("RB04 absent LP capabilities explain initial admin edit denial",
      admin_before["edit_lesson12"] == 0 and
      admin_before["edit_others_lp_lessons"] == 0)
check("RB05 fixture lesson still has a published, synthetic baseline",
      initial_title.returncode == 0 and initial_title.stdout.strip() != "" and
      wpeval('echo get_post_status(12);') == "publish")

# Mirror the *institutional* role policy observed via read-only WPVibe:
# administrator owns broad LP edit caps; LP Instructor owns/publishes
# their lessons but CANNOT edit another author's; generic editor has no LP
# caps. All role and author changes exist ONLY in the disposable clone.
grant = wpeval("""
  $admin=get_role('administrator');
  if (!$admin || get_role('lp_teacher')) {
    throw new Exception('synthetic role fixture diverged');
  }
  foreach (array('edit_lp_lessons','edit_others_lp_lessons',
                 'edit_published_lp_lessons') as $cap) $admin->add_cap($cap);
  $teacher_caps=array_fill_keys(array(
    'delete_lp_courses','delete_lp_lessons',
    'delete_published_lp_courses','delete_published_lp_lessons',
    'edit_lp_courses','edit_lp_lessons','edit_posts',
    'edit_published_lp_courses','edit_published_lp_lessons',
    'publish_lp_lessons','read','read_private_lp_courses',
    'read_private_lp_lessons','upload_files'), true);
  add_role('lp_teacher','LP Instructor',$teacher_caps);
  $instructor=new WP_User(4);
  $instructor->set_role('lp_teacher');
  echo 'CLONE_INSTITUTIONAL_ROLE_CAPS_APPLIED';
""")
check("RB06 clone-only institutional role policy installed",
      "CLONE_INSTITUTIONAL_ROLE_CAPS_APPLIED" in grant)

# Make the synthetic lesson belong to the synthetic instructor rather than
# orphan author ID 0. Administrator editing rights are checked by WordPress.
assign = wp("post", "update", "12", "--post_author=4", user=1)
author = wpeval('echo get_post_field("post_author",12);')
# WP-CLI is privileged and a late LearnPress post-save exception can make
# its exit code nonzero AFTER core has applied the change. For fixture author
# assignment assert stored state, not the command's unreliable exit code.
check("RB07 synthetic lesson owner assigned to LP Instructor in clone",
      author == "4")
admin_after = user_caps(1)
teacher_after = user_caps(4)
subscriber_after = user_caps(2)
generic_editor_lacks_lp = wpeval("""
  $e=get_role('editor');
  echo (int) ($e && ! $e->has_cap('edit_lp_lessons'));
""")
check("RB08 administrator can edit instructor lesson", admin_after["edit_lesson12"] == 1)
check("RB09 LP Instructor can edit own published lesson",
      teacher_after["edit_lesson12"] == 1 and
      teacher_after["edit_others_lp_lessons"] == 0)
check("RB10 LP Instructor cannot edit other author's lesson",
      teacher_after["edit_lesson13"] == 0)
check("RB11 subscriber remains unauthorized",
      subscriber_after["edit_lesson12"] == 0)
check("RB12 generic WordPress editor keeps no LearnPress edit powers",
      generic_editor_lacks_lp == "1")

# Test the actual browser editing boundary with synthetic WordPress cookies.
# Privileged WP-CLI is intentionally NOT used for negative writes.
class SameOriginRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urlsplit(newurl)
        if (target.scheme, target.hostname, target.port) != (
                "http", "127.0.0.1", 18736):
            raise RuntimeError("QA login attempted external redirect")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def login_synthetic(user_id, username):
    temporary_password = secrets.token_urlsafe(28)
    result = wp("user", "update", str(user_id),
                "--user_pass=" + temporary_password)
    if result.returncode:
        raise RuntimeError("Synthetic QA password provision failed")
    cookies = CookieJar()
    opener = build_opener(HTTPCookieProcessor(cookies), SameOriginRedirect())
    with opener.open(BASE + "/wp-login.php", timeout=15) as response:
        response.read(200000)
    body = urlencode({
        "log": username, "pwd": temporary_password,
        "wp-submit": "Log In",
        "redirect_to": BASE + "/wp-admin/",
        "testcookie": "1"
    }).encode()
    with opener.open(Request(BASE + "/wp-login.php", data=body,
                             method="POST"), timeout=15) as response:
        response.read(250000)
    return opener, any(c.name.startswith("wordpress_logged_in_") for c in cookies)


def browser_edit_access(opener):
    request = Request(BASE + "/wp-admin/post.php?post=12&action=edit")
    try:
        with opener.open(request, timeout=20) as response:
            code = response.status
            final = response.geturl()
            html = response.read(750000).decode("utf-8", "replace")
    except HTTPError as exc:
        code, final, html = exc.code, exc.geturl(), ""
    return (code, final.startswith(BASE + "/wp-admin/post.php"),
            'id="post"' in html or 'name="post_ID"' in html)


admin_browser, admin_login_ok = login_synthetic(1, "qa-admin")
teacher_browser, teacher_login_ok = login_synthetic(4, "instructor-QA")
subscriber_browser, subscriber_login_ok = login_synthetic(2, "student-A")
check("RB13 administrator/instructor/subscriber synthetic sessions issued",
      admin_login_ok and teacher_login_ok and subscriber_login_ok)
admin_http = browser_edit_access(admin_browser)
teacher_http = browser_edit_access(teacher_browser)
subscriber_http = browser_edit_access(subscriber_browser)
check("RB14 WP browser edit page restricted to authorized synthetic roles",
      admin_http[0] == 200 and admin_http[1] and
      teacher_http[0] == 200 and teacher_http[1] and
      (subscriber_http[0] in (401, 403) or not subscriber_http[1]))

# WordPress editor should legitimately edit title/content (not just postmeta).
new_title = "Aula QA - Revisor Sintetico 276"
new_html = "<h2>Revisao real LearnPress</h2><p>Texto sintético de instrutor QA.</p>"
update = wp("post", "update", "12", "--post_title=" + new_title,
            "--post_content=" + new_html, user=4)
check("RB15 synthetic instructor WP-CLI lesson edit succeeds", update.returncode == 0)
readback = wp("post", "get", "12", "--field=post_title")
check("RB16 stored lesson title changed", readback.returncode == 0 and
      readback.stdout.strip() == new_title)

# Turn on public editorial opt-in solely on clone to validate projection.
optin = wp("post", "meta", "update", "12", "_tds_mobile_public", "1", user=1)
check("RB17 synthetic opt-in enabled in clone", optin.returncode == 0)
status, tag, doc = read_http(lesson)
check("RB18 public lesson reflects authorized instructor title",
      status == 200 and isinstance(doc, dict) and doc.get("title") == new_title and
      "Revisao real LearnPress" in doc.get("content_html", ""))
check("RB19 new lesson returns revision ETag", bool(tag) and
      re.fullmatch(r'"[0-9a-f]{64}"', tag) is not None)
status, _, _ = read_http(lesson, tag)
check("RB20 unchanged lesson responds HTTP 304", status == 304)

# Edit published content again, keeping same APK compatibility with ETag.
last_html = "<h2>Revisao adicional 276</h2><p>Segundo texto sintético.</p>"
second = wp("post", "update", "12", "--post_content=" + last_html, user=4)
check("RB21 subsequent synthetic body edit succeeds", second.returncode == 0)
status, newtag, doc = read_http(lesson, tag)
check("RB22 revision changed HTTP 200 and not old ETag", status == 200 and
      bool(newtag) and newtag != tag and isinstance(doc, dict) and
      "Revisao adicional 276" in doc.get("content_html", ""))

# Draft withdrawal must be a 404 and item excluded from public curriculum,
# regardless of previous ETag.
draft = wp("post", "update", "12", "--post_status=draft", user=1)
check("RB23 admin can change synthetic lesson to draft", draft.returncode == 0)
status, _, _ = read_http(lesson)
check("RB24 withdrawn lesson returns 404", status == 404)
status, _, course = read_http(curriculum)
items = [item.get("id") for section in (course or {}).get("sections", [])
         for item in section.get("items", []) if isinstance(item, dict)]
check("RB25 draft lesson removed from public curriculum",
      status == 200 and 12 not in items)

# Nothing escapes the disposable clone. External runner removes its DB and
# directory on all outcomes, including raised exceptions.
print("RESULT PR238_LEARNPRESS_RBAC PASS=%d FAIL=%d" % (passed, failed), flush=True)
sys.exit(0 if failed == 0 else 1)
