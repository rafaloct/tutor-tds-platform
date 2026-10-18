import json, sys
from urllib.parse import urlparse

d = json.load(sys.stdin)
perm = d.get("permalink") or ""
ph = urlparse(perm).hostname if perm else ""
print(json.dumps({
    "id": d.get("id"),
    "name": d.get("name"),
    "status": d.get("status"),
    "content_present": bool(d.get("content")),
    "permalink_host_loopback": ph in ("127.0.0.1", "localhost"),
    "has_results": "results" in d,
    "has_assigned": "assigned" in d,
}, ensure_ascii=False))
