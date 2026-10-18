import json, sys

d = json.load(sys.stdin)
if not isinstance(d, list):
    print(json.dumps({"error": "not-a-list", "code": d.get("code")}))
    raise SystemExit(0)
print(json.dumps({"count": len(d), "ids": [x.get("id") for x in d]}))
