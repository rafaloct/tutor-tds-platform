import json, sys

d = json.load(sys.stdin)
if not isinstance(d, list):
    print("ERRO: catálogo não é lista", file=sys.stderr)
    sys.exit(1)
print(json.dumps({"count": len(d), "ids": [x.get("id") for x in d]}))
