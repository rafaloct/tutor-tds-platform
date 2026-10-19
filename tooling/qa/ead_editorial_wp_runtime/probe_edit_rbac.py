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

# WordPress role APIs used normally, only in the disposable cloned DB.
# The orphan author=0 fixture needs edit_others + edit_published capabilities.
grant = wpeval("""
  foreach (array('administrator','editor') as $roleName) {
    $role=get_role($roleName);
    if (!$role) throw new Exception('synthetic role unavailable');
    foreach (array('edit_lp_lessons','edit_others_lp_lessons',
                   'edit_published_lp_lessons') as $cap) $role->add_cap($cap);
  }
  echo 'CLONE_ROLE_CAPS_APPLIED';
""")
check("RB06 clone-only role capabilities applied", "CLONE_ROLE_CAPS_APPLIED" in grant)

admin_after = user_caps(1)
editor_after = user_caps(4)
subscriber_after = user_caps(2)
check("RB07 synthetic admin may edit published orphan LP lesson", admin_after["edit_lesson12"] == 1)
check("RB08 synthetic editor may edit published orphan LP lesson", editor_after["edit_lesson12"] == 1)
check("RB09 subscriber remains unauthorized", subscriber_after["edit_lesson12"] == 0)

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
editor_browser, editor_login_ok = login_synthetic(4, "instructor-QA")
subscriber_browser, subscriber_login_ok = login_synthetic(2, "student-A")
check("RB10 administrator/editor/subscriber synthetic sessions issued",
      admin_login_ok and editor_login_ok and subscriber_login_ok)
admin_http = browser_edit_access(admin_browser)
editor_http = browser_edit_access(editor_browser)
subscriber_http = browser_edit_access(subscriber_browser)
check("RB11 WP browser edit page restricted to authorized synthetic roles",
      admin_http[0] == 200 and admin_http[1] and
      editor_http[0] == 200 and editor_http[1] and
      (subscriber_http[0] in (401, 403) or not subscriber_http[1]))

# WordPress editor should legitimately edit title/content (not just postmeta).
new_title = "Aula QA - Revisor Sintetico 276"
new_html = "<h2>Revisao real LearnPress</h2><p>Texto sintético de instrutor QA.</p>"
update = wp("post", "update", "12", "--post_title=" + new_title,
            "--post_content=" + new_html, user=4)
check("RB12 synthetic instructor WP-CLI lesson edit succeeds", update.returncode == 0)
readback = wp("post", "get", "12", "--field=post_title")
check("RB13 stored lesson title changed", readback.returncode == 0 and
      readback.stdout.strip() == new_title)

# Turn on public editorial opt-in solely on clone to validate projection.
optin = wp("post", "meta", "update", "12", "_tds_mobile_public", "1", user=1)
check("RB14 synthetic opt-in enabled in clone", optin.returncode == 0)
status, tag, doc = read_http(lesson)
check("RB15 public lesson reflects authorized instructor title",
      status == 200 and isinstance(doc, dict) and doc.get("title") == new_title and
      "Revisao real LearnPress" in doc.get("content_html", ""))
check("RB16 new lesson returns revision ETag", bool(tag) and
      re.fullmatch(r'"[0-9a-f]{64}"', tag) is not None)
status, _, _ = read_http(lesson, tag)
check("RB17 unchanged lesson responds HTTP 304", status == 304)

# Edit published content again, keeping same APK compatibility with ETag.
last_html = "<h2>Revisao adicional 276</h2><p>Segundo texto sintético.</p>"
second = wp("post", "update", "12", "--post_content=" + last_html, user=4)
check("RB18 subsequent synthetic body edit succeeds", second.returncode == 0)
status, newtag, doc = read_http(lesson, tag)
check("RB19 revision changed HTTP 200 and not old ETag", status == 200 and
      bool(newtag) and newtag != tag and isinstance(doc, dict) and
      "Revisao adicional 276" in doc.get("content_html", ""))

# Draft withdrawal must be a 404 and item excluded from public curriculum,
# regardless of previous ETag.
draft = wp("post", "update", "12", "--post_status=draft", user=1)
check("RB20 admin can change synthetic lesson to draft", draft.returncode == 0)
status, _, _ = read_http(lesson)
check("RB21 withdrawn lesson returns 404", status == 404)
status, _, course = read_http(curriculum)
items = [item.get("id") for section in (course or {}).get("sections", [])
         for item in section.get("items", []) if isinstance(item, dict)]
check("RB22 draft lesson removed from public curriculum",
      status == 200 and 12 not in items)

# Nothing escapes the disposable clone. External runner removes its DB and
# directory on all outcomes, including raised exceptions.
print("RESULT PR238_LEARNPRESS_RBAC PASS=%d FAIL=%d" % (passed, failed), flush=True)
sys.exit(0 if failed == 0 else 1)
