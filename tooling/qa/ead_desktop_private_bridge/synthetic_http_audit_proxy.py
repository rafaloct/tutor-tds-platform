#!/usr/bin/env python3
"""QA-only loopback proxy: emulator tcp:18731 -> desktop tcp:18733 -> SSH tcp:18731.
Read-only and synthetic course 12 / lesson 13 exclusively. No body/PII in audit.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
from http.client import HTTPConnection, HTTPException
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
from urllib.parse import urlsplit, parse_qsl

ALLOW = {
    "/tds-learning/v1/courses/12/curriculum": "curriculum_12",
    "/tds-learning/v1/courses/12/lessons/13": "lesson_13",
}
VHOST = "tds-learning-qa-wp-20261017"
LOCK = threading.Lock()
MAX_SIZE = 512 * 1024


def route_label(path):
    u = urlsplit(path)
    if u.scheme or u.netloc or u.fragment or u.path != "/":
        return None
    try:
        pairs = parse_qsl(u.query, strict_parsing=True)
    except ValueError:
        return None
    if len(pairs) != 1 or pairs[0][0] != "rest_route":
        return None
    return ALLOW.get(pairs[0][1])


def handler_factory(audit):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_):
            pass  # no request target or headers printed

        def reject(self, code):
            self.send_response(code)
            self.send_header("Content-Length", "0")
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True

        def record(self, route, code, etag, conditional, size):
            row = {
                "utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "route": route, "http": code, "etag": etag,
                "conditional": conditional, "bytes": size,
            }
            with LOCK:
                with audit.open("a", encoding="utf-8") as stream:
                    stream.write(json.dumps(row, separators=(",", ":")) + "\n")

        def do_GET(self):
            route = route_label(self.path)
            if route is None:
                self.reject(404)
                return
            if (self.headers.get("Cookie") or self.headers.get("Authorization") or
                self.headers.get("Host") not in (VHOST, "127.0.0.1:18731",
                                                  "127.0.0.1:18733")):
                self.record(route, 403, False, False, 0)
                self.reject(403)
                return
            etag = self.headers.get("If-None-Match")
            hdr = {"Host": VHOST, "Accept": "application/json",
                   "Accept-Encoding": "identity",
                   "User-Agent": "TDS-SYNTHETIC-QA",
                   "Connection": "close"}
            if etag:
                hdr["If-None-Match"] = etag
            upstream = HTTPConnection("127.0.0.1", 18731, timeout=12)
            try:
                upstream.request("GET", self.path, headers=hdr)
                response = upstream.getresponse()
                body = response.read(MAX_SIZE + 1)
                if len(body) > MAX_SIZE:
                    self.record(route, 502, False, bool(etag), 0)
                    self.reject(502)
                    return
                self.send_response(response.status)
                for key in ("Content-Type", "ETag", "Cache-Control", "Last-Modified"):
                    value = response.getheader(key)
                    if value:
                        self.send_header(key, value)
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Connection", "close")
                self.end_headers()
                if body:
                    self.wfile.write(body)
                self.close_connection = True
                self.record(route, response.status, bool(response.getheader("ETag")),
                            bool(etag), len(body))
            except (OSError, HTTPException):
                self.record(route, 502, False, bool(etag), 0)
                self.reject(502)
            finally:
                upstream.close()

        def do_POST(self): self.reject(405)
        def do_PUT(self): self.reject(405)
        def do_PATCH(self): self.reject(405)
        def do_DELETE(self): self.reject(405)

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", type=Path, required=True)
    args = parser.parse_args()
    args.audit.parent.mkdir(parents=True, exist_ok=True)
    if args.audit.exists():
        parser.error("audit exists; never overwrite")
    server = ThreadingHTTPServer(("127.0.0.1", 18733), handler_factory(args.audit))
    print("QA_PROXY_READY=127.0.0.1:18733", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
