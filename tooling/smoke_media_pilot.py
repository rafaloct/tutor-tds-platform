"""GET-only institutional pilot acceptance; no credentials or enrollment writes."""
import gzip
import json
import urllib.error
import urllib.request

ORIGIN = "https://ead.ipexdesenvolvimento.cloud"
BASE = ORIGIN + "/wp-json/tds-learning/v1/courses/1298/"
rows = []


def get(url, headers=None):
    request = urllib.request.Request(url, headers={"Accept-Encoding": "gzip",
        "User-Agent": "Dart/3.12 (dart:io)", "Accept": "application/json", **(headers or {})})
    try:
        response = urllib.request.urlopen(request, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read()
        if response.headers.get("Content-Encoding") == "gzip" and body:
            body = gzip.decompress(body)
        rows.append({"url": url, "status": response.status, "bytes": len(body),
                     "etag": response.headers.get("ETag")})
        return response.status, response.headers, body


status, headers, body = get(BASE + "curriculum")
assert status == 200, rows[-1]
course = json.loads(body)
items = [item for section in course["sections"] for item in section["items"]]
authorized = [item for item in items if item.get("mobile_content")]
assert len(items) == 13 and [item["id"] for item in authorized] == [1420]
assert authorized[0]["media"]["provider"] == "ipex_mp4"
status, _, body = get(BASE + "curriculum", {"If-None-Match": headers["ETag"]})
assert status == 304 and not body
status, headers, body = get(BASE + "lessons/1420")
assert status == 200
lesson = json.loads(body)
assert lesson["media"]["provider"] == "ipex_mp4" and lesson["content_html"]
status, _, body = get(BASE + "lessons/1420", {"If-None-Match": headers["ETag"]})
assert status == 304 and not body
status, _, body = get(BASE + "lessons/1299")
assert status == 404 and "content_html" not in json.loads(body)
status, headers, body = get(lesson["media"]["source_url"], {"Range": "bytes=0-1023"})
assert status == 206 and len(body) == 1024 and b"ftyp" in body[:32]
status, _, body = get(lesson["media"]["captions_url"])
assert status == 200 and body.startswith(b"WEBVTT") and b"-->" in body
print(json.dumps({"status": "PASS", "http_checks": len(rows), "authorized_lesson_ids": [1420],
                  "vtt_cues": body.count(b"-->"), "requests": rows}, indent=2))
