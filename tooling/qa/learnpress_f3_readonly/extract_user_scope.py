import json, sys

d = json.load(sys.stdin)
out = {"id": d.get("id")}

c = (d.get("tabs") or {}).get("courses", {}).get("content", {})
out["courses_content"] = {
    k: (len(v) if isinstance(v, list)
        else ({kk: len(vv) for kk, vv in v.items()} if isinstance(v, dict) else type(v).__name__))
    for k, v in c.items()
}
q = (d.get("tabs") or {}).get("quizzes", {}).get("content", {})
out["quizzes_content"] = {k: (len(v) if isinstance(v, list) else type(v).__name__) for k, v in q.items()}
out["passed_quiz_ids"] = [i.get("id") for i in q.get("passed", []) if isinstance(i, dict)]
print(json.dumps(out))
