from datetime import datetime, timezone

import pytest
from sqlalchemy import event, text
from sqlalchemy.orm import Session

from app.models import ClassEnrollment, ClassSession, Classroom, Enrollment, ProgramMembership
from test_certificate_requests import evidence
from test_certificate_requests import header, requests_api
from test_presence import activity, decide, presence_api
from test_student_followup import baseline, case_create, case_patch


def dashboard(client, actor="teacher"):
    return client.get("/classes/c1/dashboard", headers=header(actor))


def test_progress_never_mixes_class_edition_or_unscoped_legacy_events(presence_api):
    client, engine = presence_api
    with Session(engine) as session:
        version = session.get(Classroom, "c1").course_version_id
        other_version = session.get(Classroom, "c2").course_version_id
    evidence(engine, classroom="c2", version=version, seconds=3600)
    evidence(engine, classroom="c1", version=other_version, seconds=3600)
    evidence(engine, classroom=None, version=version, seconds=3600)
    evidence(engine, classroom="c1", version=None, seconds=3600)
    row = next(item for item in dashboard(client).json()["students"] if item["user_id"] == "learner")
    assert row["validated_hours"] == 0 and row["last_activity_at"] is None
    assert "required_activity_pending" in [item["code"] for item in row["alerts"]]
    evidence(engine, classroom="c1", version=version, seconds=1800)
    row = next(item for item in dashboard(client).json()["students"] if item["user_id"] == "learner")
    assert row["validated_hours"] == 0.5 and row["last_activity_at"] is not None
    assert "required_activity_pending" not in [item["code"] for item in row["alerts"]]


def test_dashboard_aggregates_only_exact_class_roster_without_private_content(presence_api):
    client, engine = presence_api
    # c1 and c2 pin different editions, but share the same learner/enrollment.
    assert baseline(client, user="other", record="private-reference-other").status_code == 200
    assert baseline(client, classroom="c2", actor="teacher2", key="other-class-baseline").status_code == 200
    assert decide(client).status_code == 200
    assert decide(client, user="other", status="absent", key="human-absence-other").status_code == 200
    with Session(engine) as session:
        session.add(ClassSession(id="s3", class_id="c1", starts_at=datetime(2026, 1, 1, tzinfo=timezone.utc), ends_at=datetime(2027, 12, 1, tzinfo=timezone.utc), status="open", opened_by="teacher", checkin_token_digest="b" * 64, token_expires_at=datetime(2027, 12, 1, tzinfo=timezone.utc)))
        # Separate program/enrollment for the same learner must not leak counts.
        session.add(ClassEnrollment(class_id="foreign-class", user_id="learner", enrollment_id="e2", program_id="p2", course_id="course", status="active"))
        session.commit()
    for classroom, identity, actor in (("c1", "s3", "teacher"), ("c2", "s2", "teacher2")):
        response = client.post(f"/classes/{classroom}/sessions/{identity}/presence/learner", headers=header(actor), json={"status": "confirmed_present", "expected_revision": 0, "reason": "Conferido em pessoa", "idempotency_key": f"human-presence-{identity}"})
        assert response.status_code == 200, response.text
    assert baseline(client, classroom="foreign-class", actor="outsider", key="foreign-enrollment-baseline").status_code == 200
    first = case_create(client, objective="Private objective never in dashboard").json()
    progress = case_create(client, key="in-progress-case-key").json()
    assert case_patch(client, progress["id"], status="in_progress").status_code == 200
    closed = case_create(client, key="closed-case-key").json()
    assert case_patch(client, closed["id"], key="close-case-key", status="closed").status_code == 200
    assert case_create(client, user_id="other", key="other-person-case").status_code == 201
    for classroom, actor in (("c2", "teacher2"), ("foreign-class", "outsider")):
        response = client.post(f"/classes/{classroom}/mentorship-cases", headers=header(actor), json={"user_id": "learner", "mentor_id": actor, "objective": "Private other class objective", "next_action": "Revisão humana", "reason": "Conferido em pessoa", "idempotency_key": f"mentorship-{classroom}"})
        assert response.status_code == 201, response.text

    aggregate_queries = []

    def capture(_conn, _cursor, statement, _parameters, _context, _executemany):
        normalized = " ".join(statement.lower().split())
        if any(f"from {table} " in normalized for table in ("student_baselines", "session_presence", "mentorship_cases")):
            aggregate_queries.append(normalized)

    event.listen(engine, "before_cursor_execute", capture)
    try:
        response = dashboard(client)
    finally:
        event.remove(engine, "before_cursor_execute", capture)
    assert response.status_code == 200, response.text
    assert len(aggregate_queries) == 3
    assert all("group by" in query for query in aggregate_queries)
    result = response.json()
    students = {item["user_id"]: item for item in result["students"]}
    assert students["learner"]["baseline_linked"] is False
    assert students["learner"]["confirmed_sessions"] == 2
    assert students["learner"]["open_mentorship_cases"] == 2
    assert students["other"]["baseline_linked"] is True
    assert students["other"]["confirmed_sessions"] == 0
    assert students["other"]["open_mentorship_cases"] == 1
    assert result["summary"]["baseline_linked_students"] == 1
    assert result["summary"]["confirmed_participations"] == 2
    assert result["summary"]["open_mentorship_cases"] == 3
    for private in ("private-reference-other", "Private objective", "Revisão humana", first["id"]):
        assert private not in response.text


def test_dashboard_does_not_treat_qr_or_accepted_activity_as_formal_presence(presence_api):
    client, engine = presence_api
    activity(engine, status="accepted")
    response = client.post("/classes/c1/sessions/s1/checkins", headers=header("teacher"), json={"kind": "checkin", "user_id": "learner", "idempotency_key": "dashboard-checkin-only"})
    assert response.status_code == 201
    reviewed = client.post(f"/classes/c1/evidence/{response.json()['evidence_id']}/review", headers=header("teacher"), json={"decision": "accepted", "reason_code": "verified"})
    assert reviewed.status_code == 200
    result = dashboard(client).json()
    assert result["summary"]["confirmed_participations"] == 0
    assert all(item["confirmed_sessions"] == 0 for item in result["students"])


@pytest.mark.parametrize("target", ["membership", "enrollment", "class", "inconsistent"])
def test_dashboard_excludes_revoked_students_and_their_aggregates(presence_api, target):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    assert decide(client).status_code == 200
    assert case_create(client).status_code == 201
    if target == "inconsistent":
        with engine.connect() as connection:
            connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
            connection.execute(text("UPDATE class_enrollments SET enrollment_id = 'other-e' WHERE class_id = 'c1' AND user_id = 'learner'"))
            connection.commit()
    else:
        with Session(engine) as session:
            record = (session.get(ProgramMembership, ("learner", "p1")) if target == "membership" else session.get(Enrollment, "e1") if target == "enrollment" else session.get(ClassEnrollment, ("c1", "learner")))
            record.status = "inactive"
            session.commit()
    result = dashboard(client).json()
    assert [item["user_id"] for item in result["students"]] == ["other"]
    assert result["summary"]["total_students"] == 1
    assert result["summary"]["baseline_linked_students"] == 0
    assert result["summary"]["confirmed_participations"] == 0
    assert result["summary"]["open_mentorship_cases"] == 0


def test_dashboard_revalidates_staff_membership_and_isolates_scope(presence_api):
    client, engine = presence_api
    for actor in ("teacher", "monitor", "admin"):
        assert dashboard(client, actor).status_code == 200
    for actor in ("learner", "outsider", "teacher2", "coordinator"):
        assert dashboard(client, actor).status_code == 403
    with Session(engine) as session:
        session.get(ProgramMembership, ("teacher", "p1")).status = "inactive"
        session.get(ProgramMembership, ("monitor", "p1")).role = "student"
        session.commit()
    assert dashboard(client, "teacher").status_code == 403
    assert dashboard(client, "monitor").status_code == 403
