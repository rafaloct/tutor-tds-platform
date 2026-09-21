"""Synthetic staging-only presence roundtrip. Keeps records for audit."""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

from smoke_course_editor_staging import call

CLASS = "8d7e5869-cdd6-4ebe-a94e-2de91c0e7399"
STUDENT = "staging-qa-student"


def run(session_id):
    env = {}
    for line in Path("/opt/tutor-tds-staging/.staging-seed.env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip("\"'")
    tokens = {}
    for role in ("student", "teacher"):
        prefix = "STAGING_SEED_" + role.upper()
        login = call("POST", "/auth/login", {"cpf": env[prefix + "_CPF"], "password": env[prefix + "_PASSWORD"]})
        tokens[role] = login["access_token"]
        assert call("GET", "/auth/me", token=tokens[role])["id"] == "staging-qa-" + role
    teacher, student = tokens["teacher"], tokens["student"]
    classroom = call("GET", f"/classes/{CLASS}", token=teacher)
    assert classroom["course_id"] == "staging-editor-course-qa-20260921-a"
    if not session_id:
        now = datetime.now(timezone.utc)
        created = call("POST", f"/admin/classes/{CLASS}/sessions", {
            "starts_at": now.isoformat(), "ends_at": (now + timedelta(minutes=30)).isoformat(),
        }, teacher, (201,))
        session_id = created["id"]
        print(json.dumps({"created_synthetic_session": session_id}), flush=True)
    base = f"/classes/{CLASS}/sessions/{session_id}"
    call("GET", base + "/presence", token=student, expected=(403,))
    page = call("GET", base + "/presence", token=teacher)
    assert page["total"] == 1 and page["items"][0]["user_id"] == STUDENT
    payload = {"status": "confirmed_present", "expected_revision": 0,
               "reason": "Teste sintético staging: confirmação manual QA, não presença real.",
               "idempotency_key": "presence-qa-" + session_id}
    call("POST", base + "/presence/" + STUDENT, payload, student, (403,))
    if page["session_status"] == "open":
        if page["items"][0]["revision"] == 0:
            assert page["items"][0]["status"] == "pending"
            call("POST", base + "/close", token=teacher, expected=(409,))
        decision = call("POST", base + "/presence/" + STUDENT, payload, teacher)
        assert decision["status"] == "confirmed_present" and decision["revision"] == 1
    replay = call("POST", base + "/presence/" + STUDENT, payload, teacher)
    assert replay["revision"] == 1
    stale = dict(payload, status="absent", idempotency_key="stale-qa-" + session_id)
    call("POST", base + "/presence/" + STUDENT, stale, teacher, (409,))
    reread = call("GET", base + "/presence", token=teacher)
    assert reread["items"][0]["revision"] == 1
    report = call("POST", base + "/close", token=teacher)
    assert report["summary"]["presence"]["counts"]["confirmed_present"] == 1
    assert report["summary"]["presence"]["pending_count"] == 0
    assert call("POST", base + "/close", token=teacher) == report
    assert call("POST", base + "/presence/" + STUDENT, payload, teacher) == replay
    call("POST", base + "/presence/" + STUDENT,
         dict(stale, expected_revision=1), teacher, (409,))
    print(json.dumps({"session_id": session_id, "report_id": report["id"],
                      "presence_roundtrip": "pass", "revision": 1,
                      "student_denied": True, "closed_report_stable": True}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--create-synthetic-session", action="store_true")
    mode.add_argument("--session-id")
    args = parser.parse_args()
    run(args.session_id)
