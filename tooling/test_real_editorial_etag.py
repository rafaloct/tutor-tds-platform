"""Focal HTTP GET on verified disposable WP6.7.2/LP4.3.6; no production POST."""
import gzip
import json
import socket
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ip, container, evidence = sys.argv[1:]
assert container.startswith("tds-immutable-editorial-")
resolver = socket.getaddrinfo


def resolve(host, *args, **kwargs):
    if host != "tds-registration-299":
        raise RuntimeError("External destination forbidden")
    return resolver(ip, *args, **kwargs)


socket.getaddrinfo = resolve
browser = urllib.request.build_opener(urllib.request.ProxyHandler({}))
rows = []


def wp(code):
    return subprocess.check_output(
        ["docker", "exec", container, "php", "/tmp/wp-cli.phar", "--allow-root",
         "eval", code], stderr=subprocess.PIPE, text=True).strip()


def get(route, tag=None):
    headers = {"Accept-Encoding": "gzip", "Accept": "application/json"}
    if tag is not None:
        headers["If-None-Match"] = tag
    request = urllib.request.Request(
        "http://tds-registration-299/?rest_route=/tds-learning/v1/courses/12/" + route,
        headers=headers)
    try:
        response = browser.open(request, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        raw = response.read()
        body = gzip.decompress(raw) if response.headers.get("Content-Encoding") == "gzip" and raw else raw
        rows.append({"route": route, "status": response.status, "etag": response.headers.get("ETag"),
                     "if_none_match": tag, "encoding": response.headers.get("Content-Encoding"),
                     "body_bytes": len(body)})
        Path(evidence, "etag-real-http.json").write_text(json.dumps(rows, indent=2))
        return response.status, response.headers.get("ETag"), body


assert wp("echo DB_NAME;").startswith("tds_registration_299r_immutable_")
assert wp('echo get_post_status(12);') == "publish"
assert wp('echo get_post_status(13);') == "publish"
# Only synthetic fixture metadata; not a test of privileged editorial HTTP save.
wp('update_post_meta(13,"_tds_mobile_public","1"); update_post_meta(13,"_tds_mobile_rights_approved","0");')
for route in ("curriculum", "lessons/13"):
    status, tag, body = get(route)
    assert status == 200
    revision = json.loads(body)["revision"]
    strong = '"' + revision + '"'
    assert tag in (strong, "W/" + strong)
    for validator in (strong, "W/" + strong):
        status, _, body = get(route, validator)
        assert status == 304 and not body
    status, _, body = get(route, 'W/"different"')
    assert status == 200 and body
lesson_tag = get("lessons/13")[1]
wp('update_post_meta(13,"_tds_mobile_public","0");')
status, _, body = get("lessons/13", lesson_tag)
assert status == 404 and "content_html" not in json.loads(body)
assert wp('global $wpdb; echo $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items");') == "0"
print("PASS real WP/LP HTTP requests=" + str(len(rows)) + "; academic_rows=0; no public POST")
