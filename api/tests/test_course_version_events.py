from datetime import date, datetime, timezone

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient
import pytest
from sqlalchemy.orm import Session

from app.database import Database
from app.events import router, student_claims
from app.models import Base, ClassEnrollment, Classroom, Course, CourseVersion, CourseVersionTransition, Enrollment, Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User


@pytest.fixture
def version_events():
    database = Database("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(database.engine)
    app = FastAPI()
    app.state.database = database
    app.include_router(router)

    def claims(x_user: str = Header(default="student")):
        return {"sub": x_user, "role": "student"}

    app.dependency_overrides[student_claims] = claims
    with Session(database.engine) as session:
        session.add(Institution(id="i", name="Institution"))
        session.add_all([User(id=identity, name=identity, cpf_digest=identity, phone="61999990000", password_digest="digest", role="student") for identity in ("student", "outsider", "teacher")])
        session.flush()
        session.add_all([Program(id=identity, institution_id="i", name=identity) for identity in ("p1", "p2")])
        session.add(Course(id="course", title="Course", author="TDS", content={"sections": []}, active=True))
        session.flush()
        for program in ("p1", "p2"):
            session.add(ProgramCourse(program_id=program, course_id="course"))
            session.add(ProgramMembership(program_id=program, user_id="student", role="student", status="active"))
            session.add(ProgramMembership(program_id=program, user_id="teacher", role="teacher", status="active"))
        session.flush()
        session.add_all([CourseVersion(id=identity, course_id="course", version_number=index + 1, revision=1, status=status, content={"id": "course", "title": "Course", "author": "TDS", "sections": []}) for index, (identity, status) in enumerate((("old", "archived"), ("current", "published"), ("draft", "draft"), ("review", "in_review")))])
        session.add_all([Enrollment(id=f"enrollment-{program}", user_id="student", program_id=program, course_id="course", status="active") for program in ("p1", "p2")])
        session.flush()
        session.add_all([Classroom(id=f"class-{program}", program_id=program, course_id="course", course_version_id="old" if program == "p1" else "current", teacher_id="teacher", name="Turma", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1)) for program in ("p1", "p2")])
        session.flush()
        session.add_all([ClassEnrollment(class_id=f"class-{program}", user_id="student", enrollment_id=f"enrollment-{program}", program_id=program, course_id="course", status="active") for program in ("p1", "p2")])
        session.commit()
    with TestClient(app) as client:
        yield client, database.engine
    database.dispose()


def event(identity="e1", event_type="lesson_started", **context):
    payload = {"event_id": identity, "event_type": event_type, "course_id": "course", "session_id": "session", "occurred_at": datetime(2026, 1, 1, tzinfo=timezone.utc).isoformat(), "payload": context}
    if event_type == "study_activity":
        payload["active_seconds"] = 30
    return payload


@pytest.mark.parametrize("event_type", ["lesson_started", "lesson_completed", "study_activity"])
def test_class_context_persists_and_resolves_exact_program_enrollment(version_events, event_type):
    client, engine = version_events
    payload = event(event_type=event_type, course_version_id="old", class_id="class-p1")
    response = client.post("/events", json=payload)
    assert response.status_code == 201, response.text
    assert response.json()["payload"] == payload["payload"]
    with Session(engine) as session:
        assert session.get(LearningEventRecord, "e1").enrollment_id == "enrollment-p1"
    assert client.post("/events", json=payload).status_code == 200
    assert client.get("/events").json()["events"][0]["payload"] == payload["payload"]
    payload["payload"] = {"course_version_id": "current", "class_id": "class-p2"}
    assert client.post("/events", json=payload).status_code == 409


@pytest.mark.parametrize("context,status", [
    ({"class_id": "class-p1"}, 422),
    ({"course_version_id": "old", "class_id": "class-p2"}, 403),
    ({"course_version_id": "old", "class_id": "missing"}, 403),
    ({"course_version_id": "draft"}, 404),
    ({"course_version_id": "review"}, 404),
    ({"course_version_id": "missing"}, 404),
    ({"course_version_id": "old", "unknown": "no"}, 422),
    ({"course_version_id": ""}, 422),
])
def test_rejects_invalid_or_unpublished_context(version_events, context, status):
    client, _ = version_events
    assert client.post("/events", json=event(**context)).status_code == status


def test_public_version_without_enrollment_and_archived_version_requires_class_membership(version_events):
    client, _ = version_events
    assert client.post("/events", headers={"X-User": "outsider"}, json=event(course_version_id="current")).status_code == 201
    assert client.post("/events", headers={"X-User": "outsider"}, json=event("e2", course_version_id="old")).status_code == 403
    assert client.post("/events", headers={"X-User": "outsider"}, json=event("e3", course_version_id="old", class_id="class-p1")).status_code == 403
    assert client.post("/events", json=event("e4", course_version_id="old")).status_code == 201


@pytest.mark.parametrize("table", ["enrollments", "class_enrollments"])
def test_inactive_enrollment_is_not_allowed_to_claim_archived_snapshot(version_events, table):
    client, engine = version_events
    with Session(engine) as session:
        record = session.get(Enrollment, "enrollment-p1") if table == "enrollments" else session.get(ClassEnrollment, ("class-p1", "student"))
        record.status = "inactive"
        session.commit()
    assert client.post("/events", json=event(course_version_id="old", class_id="class-p1")).status_code == 403
    assert client.post("/events", json=event("e2", course_version_id="old")).status_code == 403


def test_legacy_payloads_keep_behavior_and_telemetry_video_are_not_broadened(version_events):
    client, _ = version_events
    assert client.post("/events", json=event()).status_code == 201
    # Ambiguous legacy study activities still require disambiguation.
    assert client.post("/events", json=event("e2", "study_activity")).status_code == 422
    assert client.post("/events", json=event("e3", "page_viewed", page_id="home", course_version_id="current")).status_code == 422
    assert client.post("/events", json=event("e4", "video_started", media_id="media", module_id="module", course_version_id="current")).status_code == 422
    assert client.post("/events", json=event("e5", "feature_used", feature_id="chat")).status_code == 201


def test_version_cannot_be_attached_to_another_course(version_events):
    client, _ = version_events
    payload = event(course_version_id="current")
    payload["course_id"] = "different"
    assert client.post("/events", json=payload).status_code == 404


def _audit_publication_window(engine):
    with Session(engine) as session:
        session.add_all([
            CourseVersionTransition(id="published", version_id="old", from_status="in_review", to_status="published", actor_role="coordinator", occurred_at=datetime(2026, 1, 1, 10, tzinfo=timezone.utc)),
            CourseVersionTransition(id="archived", version_id="old", from_status="published", to_status="archived", actor_role="coordinator", occurred_at=datetime(2026, 1, 2, 10, tzinfo=timezone.utc)),
        ])
        session.commit()


@pytest.mark.parametrize("event_type", ["lesson_started", "lesson_completed", "study_activity"])
def test_offline_catalog_event_from_publication_window_survives_archive(version_events, event_type):
    client, engine = version_events
    _audit_publication_window(engine)
    payload = event(event_type=event_type, course_version_id="old")
    payload["occurred_at"] = "2026-01-01T09:00:00-03:00"
    response = client.post("/events", headers={"X-User": "outsider"}, json=payload)
    assert response.status_code == 201, response.text
    assert response.json()["payload"] == {"course_version_id": "old"}
    assert client.post("/events", headers={"X-User": "outsider"}, json=payload).status_code == 200
    with Session(engine) as session:
        stored = session.get(LearningEventRecord, "e1")
        assert stored.enrollment_id is None and stored.occurred_at.hour == 12


@pytest.mark.parametrize("timestamp,expected", [
    ("2026-01-01T09:59:59Z", 403),
    ("2026-01-01T10:00:00Z", 201),
    ("2026-01-02T09:59:59Z", 201),
    ("2026-01-02T10:00:00Z", 403),
    ("2026-01-02T10:00:01Z", 403),
])
def test_archived_public_window_has_utc_boundaries(version_events, timestamp, expected):
    client, engine = version_events
    _audit_publication_window(engine)
    payload = event(course_version_id="old")
    payload["occurred_at"] = timestamp
    assert client.post("/events", headers={"X-User": "outsider"}, json=payload).status_code == expected


def test_offline_public_replay_cannot_bypass_explicit_class_validation(version_events):
    client, engine = version_events
    _audit_publication_window(engine)
    payload = event(course_version_id="old", class_id="class-p1")
    payload["occurred_at"] = "2026-01-01T12:00:00Z"
    assert client.post("/events", headers={"X-User": "outsider"}, json=payload).status_code == 403
    payload["payload"]["class_id"] = "class-p2"
    assert client.post("/events", json=payload).status_code == 403
    payload["payload"]["class_id"] = "class-p1"
    payload["occurred_at"] = "2026-01-03T12:00:00Z"
    assert client.post("/events", json=payload).status_code == 201


def test_archived_never_published_version_has_no_public_replay_window(version_events):
    client, engine = version_events
    with Session(engine) as session:
        session.add(CourseVersionTransition(id="legacy-archive", version_id="old", from_status=None, to_status="archived", actor_role="migration", occurred_at=datetime(2026, 1, 2, tzinfo=timezone.utc)))
        session.commit()
    payload = event(course_version_id="old")
    assert client.post("/events", headers={"X-User": "outsider"}, json=payload).status_code == 403
    payload["payload"]["course_version_id"] = "draft"
    assert client.post("/events", headers={"X-User": "outsider"}, json=payload).status_code == 404
