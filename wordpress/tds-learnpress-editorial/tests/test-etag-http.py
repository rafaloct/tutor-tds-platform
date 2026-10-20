"""Real loopback HTTP transport, synthetic WP/LP stubs; no database or production."""
import gzip
import json
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


def main():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    router = Path(__file__).with_name("etag-http-router.php")
    with tempfile.TemporaryFile() as log:
        server = subprocess.Popen(
            ["php", "-n", "-S", f"127.0.0.1:{port}", str(router)],
            stdout=log, stderr=log,
        )
        try:
            for _ in range(100):
                if server.poll() is not None:
                    raise RuntimeError("PHP fixture exited before readiness")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=.2):
                        break
                except OSError:
                    time.sleep(.05)
            else:
                raise RuntimeError("PHP fixture did not become ready")
            rows = []

            def get(query="", tag=None, encoding="gzip"):
                headers = {"Accept-Encoding": encoding}
                if tag is not None:
                    headers["If-None-Match"] = tag
                request = urllib.request.Request(
                    f"http://127.0.0.1:{port}/?{query}", headers=headers
                )
                try:
                    response = urllib.request.urlopen(request, timeout=5)
                except urllib.error.HTTPError as error:
                    response = error
                with response:
                    body = response.read()
                    if response.headers.get("Content-Encoding") == "gzip" and body:
                        body = gzip.decompress(body)
                    rows.append({"query": query, "status": response.status,
                                 "etag": response.headers.get("ETag"),
                                 "if_none_match": tag, "body_bytes": len(body),
                                 "encoding": response.headers.get("Content-Encoding")})
                    return response.status, response.headers, body

            for query in ("", "lesson=1"):
                status, headers, body = get(query)
                assert status == 200 and headers["Content-Encoding"] == "gzip"
                tag = headers["ETag"]
                assert tag == 'W/"' + json.loads(body)["revision"] + '"'
                status, _, body = get(query, tag)
                assert status == 304 and body == b""
                status, _, body = get(query, 'W/"different"')
                assert status == 200 and body
                status, changed, body = get(query + "&changed=1", tag)
                assert status == 200 and changed["ETag"] != tag
                status, identity, body = get(query, encoding="identity")
                assert status == 200 and "Content-Encoding" not in identity
                assert tag == "W/" + identity["ETag"]
                status, _, body = get(query, identity["ETag"], encoding="identity")
                assert status == 304 and body == b""
            status, _, body = get("lesson=1&revoked=1", tag)
            assert status == 404 and "content_html" not in json.loads(body)
            print(json.dumps({"status": "PASS", "http_requests": len(rows),
                              "boundary": "PHP HTTP with WP/LP stubs, not real WordPress",
                              "requests": rows}, indent=2))
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()


if __name__ == "__main__":
    main()
