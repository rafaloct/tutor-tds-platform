import json, os, sys

d = json.load(sys.stdin)
if not isinstance(d, list):
    print("ERRO: section-items não é lista", file=sys.stderr)
    sys.exit(1)
draft_id = str(os.environ.get("DRAFT_ITEM_ID", ""))
items = []
draft_visible = False
for it in d:
    status = it.get("status")
    items.append({
        "id": it.get("id"),
        "type": it.get("type"),
        "post_status": status,
        "locked": it.get("locked"),
        "name_present": bool(it.get("name")),
        "permalink_present": bool(it.get("permalink")),
    })
    if str(it.get("id")) == draft_id or status not in ("publish", None):
        draft_visible = True
print(json.dumps({
    "visible_items": len(items),
    "items": items,
    "draft_item_visible": draft_visible,
    "contains_non_publish": any(i["post_status"] != "publish" for i in items),
}))
