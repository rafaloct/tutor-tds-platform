import json, sys

d = json.load(sys.stdin)
if not isinstance(d, list):
    print("ERRO: section-items não é lista", file=sys.stderr)
    sys.exit(1)
items = []
for it in d:
    items.append({
        "id": it.get("id"),
        "type": it.get("type"),
        "post_status": it.get("status"),
        "user_status": it.get("user_status"),
        "graduation": it.get("graduation"),
        "locked": it.get("locked"),
        "name_present": bool(it.get("name")),
        "permalink_present": bool(it.get("permalink")),
    })
print(json.dumps({
    "items": items,
    "contains_draft_items": any(i.get("post_status") == "draft" for i in items),
}))
