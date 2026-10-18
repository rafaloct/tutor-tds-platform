import json, sys

d = json.load(sys.stdin)
if not d.get("code"):
    print("ERRO: resposta de erro sem campo 'code'", file=sys.stderr)
    sys.exit(1)
print(json.dumps({
    "code": d.get("code"),
    "status": (d.get("data") or {}).get("status"),
    "message_prefix": str(d.get("message") or "")[:60],
}))
