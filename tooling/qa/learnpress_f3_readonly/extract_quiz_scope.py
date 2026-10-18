import json, sys

d = json.load(sys.stdin)
if not d.get("id"):
    print("ERRO: resposta de quiz sem 'id'", file=sys.stderr)
    sys.exit(1)
print(json.dumps({
    "id": d.get("id"),
    "name": d.get("name"),
    "status": d.get("status"),
    "question_count": len(d.get("questions", [])),
    "has_question_ids": "question_ids" in d,
}, ensure_ascii=False))
