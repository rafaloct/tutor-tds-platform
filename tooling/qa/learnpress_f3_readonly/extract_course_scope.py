import json, sys

d = json.load(sys.stdin)
cd = d.get("course_data") or {}
res = cd.get("result") or {}

def num(x):
    try:
        return int(x)
    except (TypeError, ValueError):
        return None

items = []
for s in d.get("sections") or []:
    for it in s.get("items") or []:
        items.append({
            "id": it.get("id"), "type": it.get("type"),
            "title": it.get("title"),
            "status": it.get("status"), "locked": it.get("locked"),
            "graduation": it.get("graduation"),
        })

enrollment = {"enrolled": "enrolled", "finished": "completed"}.get(cd.get("status"))

# Próximo item pendente (qualquer tipo) e próxima LIÇÃO pendente (lp_lesson),
# derivados apenas quando há matrícula (guest/não-inscrito não tem "próxima").
pending_item = next(
    (it for it in items if it.get("status") != "completed" and not it.get("locked")),
    None,
) if enrollment else None
next_lesson = pending_item if (pending_item or {}).get("type") == "lp_lesson" else None

print(json.dumps({
    "wpCourseId": d.get("id"),
    "title": d.get("name"),
    "course_data": {
        "status": cd.get("status"),
        "graduation": cd.get("graduation"),
        "start_time": cd.get("start_time"),
        "end_time": cd.get("end_time"),
        "result": {
            "result": res.get("result"),
            "pass": res.get("pass"),
            "count_items": res.get("count_items"),
            "completed_items": res.get("completed_items"),
            "evaluate_type": res.get("evaluate_type"),
            "items": res.get("items"),
        },
    },
    "sections_items": items,
    "derived": {
        "enrollment": enrollment,
        "progressPercent": num(res.get("result")) if enrollment else None,
        "nextPendingItemId": (pending_item or {}).get("id"),
        "nextPendingItemType": (pending_item or {}).get("type"),
        "nextLessonId": (next_lesson or {}).get("id"),
        "nextLessonTitle": (next_lesson or {}).get("title"),
        "resumeAuthorized": bool(enrollment == "enrolled" and pending_item),
    },
}, ensure_ascii=False))
