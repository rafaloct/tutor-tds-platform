import json, sys

d = json.load(sys.stdin)
routes = d.get("routes")
if not isinstance(routes, dict) or not routes:
    print("ERRO: resposta sem mapa 'routes' não-vazio", file=sys.stderr)
    sys.exit(1)
print(json.dumps({"count": len(routes), "routes": sorted(routes.keys())}))
