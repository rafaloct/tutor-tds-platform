import json, sys

d = json.load(sys.stdin)
print(json.dumps({
    "code": d.get("code"),
    "status": (d.get("data") or {}).get("status"),
    "message_prefix": str(d.get("message") or "")[:60],
}))
