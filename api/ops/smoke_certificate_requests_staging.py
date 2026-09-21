"""Synthetic staging request/review roundtrip; no issuance or forged evidence.

Uses the existing course-editor QA fixture and protected VPS credentials.
Keeps its request and rejection for audit. Re-runs only read that decision.
"""
import json
from pathlib import Path

from smoke_course_editor_staging import call

COURSE = "staging-editor-course-qa-20260921-a"
CLASS = "8d7e5869-cdd6-4ebe-a94e-2de91c0e7399"
VERSION = "c276ae19-3f49-4271-99ae-2a367e04d517"
REASON = "Teste sintético staging: aguardar validação humana da carga horária."


def run():
    env = {}
    for line in Path("/opt/tutor-tds-staging/.staging-seed.env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip("\"'")
    tokens = {}
    for role in ("student", "teacher"):
        prefix = "STAGING_SEED_" + role.upper()
        session = call("POST", "/auth/login", {"cpf": env[prefix + "_CPF"], "password": env[prefix + "_PASSWORD"]})
        tokens[role] = session["access_token"]
        assert call("GET", "/auth/me", token=tokens[role])["id"] == "staging-qa-" + role
    student, teacher = tokens["student"], tokens["teacher"]
    classroom = call("GET", f"/classes/{CLASS}", token=teacher)
    assert classroom["course_id"] == COURSE and classroom["course_version_id"] == VERSION
    assert classroom["teacher_id"] == "staging-qa-teacher"
    contexts = call("GET", f"/certificate-requests/contexts?course_id={COURSE}&course_version_id={VERSION}", token=student)["contexts"]
    context = next(row for row in contexts if row["class_id"] == CLASS)
    body = {key: context[key] for key in ("enrollment_id", "course_version_id", "class_id")}
    row = call("POST", "/certificate-requests", body, student, (200, 201))
    assert call("POST", "/certificate-requests", body, student)["id"] == row["id"]
    path = "/certificate-requests/" + row["id"]
    assert call("GET", path, token=student)["id"] == row["id"]
    call("GET", "/certificate-requests/review-queue", token=student, expected=(403,))
    if row["status"] == "pending":
        queue = call("GET", "/certificate-requests/review-queue", token=teacher)["requests"]
        assert any(item["id"] == row["id"] for item in queue)
        decision = {"decision": "reject", "expected_revision": row["revision"], "reason": REASON}
        call("POST", path + "/review", decision, student, (403,))
        if not row["eligibility"]["eligible"]:
            call("POST", path + "/review", decision | {"decision": "approve"}, teacher, (422,))
        row = call("POST", path + "/review", decision, teacher)
        call("POST", path + "/review", decision, teacher, (409,))
    assert row["status"] == "rejected" and row["review_reason"] == REASON
    reread = call("GET", path, token=student)
    assert reread["status"] == "rejected" and reread["review_reason"] == REASON
    assert row["id"] in {item["id"] for item in call("GET", "/certificate-requests", token=student)["requests"]}
    assert row["id"] not in {item["id"] for item in call("GET", "/certificate-requests/review-queue", token=teacher)["requests"]}
    print(json.dumps({"request_id": row["id"], "class_id": CLASS, "version_id": VERSION,
                      "status": reread["status"], "revision": reread["revision"],
                      "real_login_roundtrip": "pass", "issuance": "not_attempted"}))


if __name__ == "__main__":
    run()
