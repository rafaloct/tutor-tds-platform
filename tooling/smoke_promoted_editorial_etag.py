"""Public GET-only acceptance, no cookies or authentication."""
import gzip
import json
import urllib.error
import urllib.request

base = "https://ead.ipexdesenvolvimento.cloud/wp-json/tds-learning/v1/courses/1298/"
rows = []


def get(path, tag=None):
    headers = {"Accept-Encoding": "gzip", "Accept": "application/json",
               "User-Agent": "Dart/3.12 (dart:io)"}
    if tag is not None:
        headers["If-None-Match"] = tag
    try:
        response = urllib.request.urlopen(urllib.request.Request(base + path, headers=headers), timeout=20)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        raw = response.read()
        body = gzip.decompress(raw) if response.headers.get("Content-Encoding") == "gzip" and raw else raw
        rows.append({"path": path, "status": response.status,
                     "etag": response.headers.get("ETag"), "if_none_match": tag,
                     "encoding": response.headers.get("Content-Encoding"),
                     "wire_bytes": len(raw), "body_bytes": len(body)})
        return response.status, response.headers, body


try:
    status, headers, body = get("curriculum")
    assert status == 200 and headers.get("Content-Encoding") == "gzip"
    data = json.loads(body)
    tag = headers["ETag"]
    assert data["course_id"] == 1298 and data["authority"] == "learnpress"
    assert tag == 'W/"' + data["revision"] + '"'
    items = [item for section in data["sections"] for item in section["items"]]
    assert len(items) == 13
    assert all(not item.get("mobile_content") and item.get("media") is None for item in items)
    status, _, body = get("curriculum", tag)
    assert status == 304 and not body, "Literal weak If-None-Match must return304"
    status, _, body = get("lessons/" + str(items[0]["id"]))
    assert status == 404 and "content_html" not in json.loads(body)
    print(json.dumps({"status": "PASS", "items": len(items), "media_exposed": 0, "requests": rows}, indent=2))
except Exception:
    print(json.dumps({"status": "FAIL", "requests": rows}, indent=2))
    raise
