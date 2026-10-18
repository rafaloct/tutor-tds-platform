import json, sys

d = json.load(sys.stdin)
routes = sorted(d.get("routes", {}).keys())
print(json.dumps({"count": len(routes), "routes": routes}))
