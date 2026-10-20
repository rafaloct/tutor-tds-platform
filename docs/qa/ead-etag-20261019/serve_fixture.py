"""Loopback-only #303 APK smoke fixture; no WordPress or external requests.

Run from any directory, then adb reverse tcp:18731 tcp:18731.
Uses the existing sanitized WP/MySQL fixture with no authorized media.
"""

import gzip
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[3]
BODY = (ROOT / "cartilhas_app/test/fixtures/ead_editorial/"
        "curriculum-wp672-lp436-mysql-synthetic.json").read_bytes()
ETAG = 'W/"' + json.loads(BODY)["revision"] + '"'
ROUTE = "/tds-learning/v1/courses/12/curriculum"


class Fixture(BaseHTTPRequestHandler):
    def do_GET(self):
        route = parse_qs(urlsplit(self.path).query).get("rest_route")
        if route != [ROUTE]:
            self.send_error(404)
            return
        conditional = self.headers.get("If-None-Match")
        status = 304 if conditional == ETAG else 200
        self.send_response(status)
        self.send_header("ETag", ETAG)
        self.send_header("Vary", "Accept-Encoding")
        body = gzip.compress(BODY, mtime=0)
        if status == 200:
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if status == 200:
            self.wfile.write(body)
        print(json.dumps({
            "status": status,
            "etag": ETAG,
            "if_none_match": conditional,
            "accept_encoding": self.headers.get("Accept-Encoding"),
            "authorization_present": "Authorization" in self.headers,
            "cookie_present": "Cookie" in self.headers,
            "compressed_body_bytes": len(body) if status == 200 else 0,
        }), flush=True)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    print("Synthetic fixture listening on 127.0.0.1:18731", flush=True)
    HTTPServer(("127.0.0.1", 18731), Fixture).serve_forever()
