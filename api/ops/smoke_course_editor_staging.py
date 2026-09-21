"""Explicit synthetic end-to-end staging exercise; never targets production.

Reads existing synthetic credentials on the VPS, prints only QA identities/results.
Run once per unique --run-id. Keeps records for traceability; does not clean data.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BASE = "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
PROGRAM = "staging-qa-program"


def call(method, path, body=None, token=None, expected=(200,)):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = Request(BASE + path, data=json.dumps(body).encode() if body is not None else None, headers=headers, method=method)
    try:
        with urlopen(request, timeout=25) as response:
            status, raw = response.status, response.read()
    except HTTPError as error:
        status, raw = error.code, error.read()
    if status not in expected:
        # Avoid logging response bodies that may echo secrets or personal fields.
        raise RuntimeError(f"{method} {path}: HTTP {status}; expected {expected}")
    return json.loads(raw) if raw else {}


def run(run_id):
    if not re.fullmatch(r"[a-z0-9-]{1,35}", run_id):
        raise ValueError("Invalid synthetic run identifier")
    env = {}
    for line in Path("/opt/tutor-tds-staging/.staging-seed.env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip("\"'")
    sessions = {}
    for role in ("admin", "teacher", "student"):
        prefix = "STAGING_SEED_" + role.upper()
        sessions[role] = call("POST", "/auth/login", {"cpf": env[prefix + "_CPF"], "password": env[prefix + "_PASSWORD"]})
    tokens = {role: data["access_token"] for role, data in sessions.items()}
    # Refresh is exercised without disclosing either token.
    refreshed = call("POST", "/auth/refresh", {"refresh_token": sessions["student"]["refresh_token"]})
    tokens["student"] = refreshed["access_token"]
    assert call("GET", "/auth/me", token=tokens["student"])["id"] == "staging-qa-student"
    real_catalog = call("GET", "/courses")["courses"]
    real_ids = [row["id"] for row in real_catalog if not row["id"].startswith("staging-")]
    assert len(real_ids) == 9
    for course_id in real_ids:
        call("POST", f"/admin/programs/{PROGRAM}/courses/{course_id}", token=tokens["admin"], expected=(201, 409))
    course_id = "staging-editor-" + run_id
    draft = call("POST", "/courses", {"course_id": course_id, "program_id": PROGRAM, "title": "QA editor [STAGING]", "author": "Equipe QA"}, tokens["teacher"], (201,))
    call("PATCH", f"/courses/{course_id}", {"version_id": draft["version_id"], "expected_revision": draft["revision"], "title": "Negado", "author": "QA", "sections": []}, tokens["student"], (403, 404))

    def save(view, message):
        return call("PATCH", f"/courses/{course_id}", {"version_id": view["version_id"], "expected_revision": view["revision"], "title": "QA editor [STAGING]", "author": "Equipe QA", "sections": [{"id": "module", "title": "Módulo QA", "messages": [{"id": "intro", "type": "bot", "content": message}, {"id": "question", "type": "question", "content": "Qual edição você abriu?", "options": [{"label": "Edição da minha turma"}, {"label": "Catálogo público"}]}]}]}, tokens["teacher"])

    def action(view, verb, role):
        return call("POST", f"/courses/{course_id}/{verb}", {"version_id": view["version_id"], "expected_revision": view["revision"]}, tokens[role])

    saved = save(draft, "Primeira edição preservada")
    call("PATCH", f"/courses/{course_id}", {"version_id": draft["version_id"], "expected_revision": draft["revision"], "title": "Conflito", "author": "QA", "sections": []}, tokens["teacher"], (409,))
    first = action(action(saved, "submit", "teacher"), "publish", "admin")
    class_payload = {"program_id": PROGRAM, "course_id": course_id, "teacher_id": "staging-qa-teacher", "name": "QA edição 1 " + run_id, "start_date": "2026-09-21", "end_date": "2026-12-31", "status": "active"}
    first_class = call("POST", "/admin/classes", class_payload, tokens["admin"], (201,))
    call("POST", "/admin/enrollments", {"user_id": "staging-qa-student", "program_id": PROGRAM, "course_id": course_id}, tokens["admin"], (201,))
    membership_path = f"/classes/{first_class['id']}/students/staging-qa-student"
    call("PUT", membership_path, token=tokens["teacher"])
    call("PUT", membership_path, token=tokens["teacher"])
    first_content = call("GET", f"/classes/{first_class['id']}/course", token=tokens["student"])
    fork = call("POST", f"/courses/{course_id}/versions", {"source_version_id": first["version_id"]}, tokens["teacher"], (201,))
    second = action(action(save(fork, "Segunda edição pública"), "submit", "teacher"), "publish", "admin")
    assert call("GET", f"/classes/{first_class['id']}/course", token=tokens["student"]) == first_content
    assert call("GET", f"/courses/{course_id}")["course_version_id"] == second["version_id"]
    second_class = call("POST", "/admin/classes", class_payload | {"name": "QA edição 2 " + run_id}, tokens["admin"], (201,))
    assert second_class["course_version_id"] == second["version_id"]
    call("GET", f"/classes/{second_class['id']}/course", token=tokens["student"], expected=(403,))
    event_ids = []
    for kind in ("lesson_started", "study_activity", "lesson_completed"):
        event = {"event_id": f"{run_id}:{kind}", "event_type": kind, "course_id": course_id, "session_id": run_id, "occurred_at": datetime.now(timezone.utc).isoformat(), "payload": {"course_version_id": first["version_id"], "class_id": first_class["id"]}}
        if kind == "study_activity":
            event["active_seconds"] = 1
        created = call("POST", "/events", event, tokens["student"], (201,))
        replay = call("POST", "/events", event, tokens["student"])
        assert created["event_id"] == replay["event_id"] and created["payload"] == event["payload"]
        event_ids.append(created["event_id"])
    return {"status": "passed", "run_id": run_id, "real_courses": len(real_ids), "course_id": course_id, "first_version": first["version_id"], "second_version": second["version_id"], "first_class": first_class["id"], "second_class": second_class["id"], "events": event_ids, "verified": ["refresh_auth", "role_denial", "revision_conflict", "publish", "class_pin", "new_class_latest_version", "unenrolled_denial", "event_context", "idempotent_replay"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    print(json.dumps(run(args.run_id), sort_keys=True))
