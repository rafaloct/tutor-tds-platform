"""Synthetic coverage for open-class self-enrollment and LearnPress projection."""
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.learnpress_sync import LearnPressSyncWorker, WordPressTdsClient
from app.models import (
    ClassEnrollment,
    Classroom,
    CohortMembership,
    Course,
    CourseVersion,
    Enrollment,
    ExternalSyncRequest,
    OperatorCommandReceipt,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)
from test_certificate_requests import requests_api, header


@pytest.fixture
def self_enroll_api(requests_api):
    client, engine = requests_api
    client.app.state.settings = replace(
        client.app.state.settings, self_enrollment_enabled=True
    )
    with Session(engine) as session:
        session.add(
            User(
                id="spontaneous",
                cpf_digest="spontaneous",
                phone="63999887766",
                name="Aluno Espontâneo",
                password_digest="digest",
                role="student",
            )
        )
        session.commit()
    return client, engine


def _chain(session, class_id, user_id):
    link = session.get(ClassEnrollment, (class_id, user_id))
    bound = (
        session.get(CohortMembership, link.membership_id)
        if link is not None and link.membership_id
        else None
    )
    return link, bound


def test_flag_disabled_blocks_both_endpoints(requests_api):
    client, _ = requests_api
    assert client.get("/open-classes", headers=header("learner")).status_code == 404
    assert (
        client.post("/courses/course/self-enroll", headers=header("learner")).status_code
        == 404
    )


def test_first_enroll_provisions_open_class_and_full_contextual_chain(self_enroll_api):
    client, engine = self_enroll_api
    response = client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    assert response.status_code == 200, response.text
    snapshot = response.json()
    context = snapshot["context"]
    assert context["user_id"] == "spontaneous"
    assert snapshot["contract_version"] == "cohort-enrollment-v2"
    class_id = context["cohort_id"]
    with Session(engine) as session:
        classroom = session.get(Classroom, class_id)
        assert classroom.enrollment_policy == "open"
        assert classroom.status == "active"
        assert classroom.program_id == "p1"
        assert classroom.teacher_id == "teacher"
        assert classroom.course_version_id == "v2"
        assert classroom.end_date == date(2100, 12, 31)
        assert context["course_version_id"] == "v2"
        assert context["membership_id"]
        assert context["legacy_enrollment_id"]
        member = session.get(ProgramMembership, ("spontaneous", "p1"))
        assert member is not None and member.role == "student" and member.status == "active"
        enrollment = session.get(Enrollment, context["legacy_enrollment_id"])
        assert enrollment.user_id == "spontaneous" and enrollment.status == "active"
        link, bound = _chain(session, class_id, "spontaneous")
        assert link.status == "active" and link.context_id == context["enrollment_id"]
        assert bound.status == "active" and bound.role == "student"
        receipt = session.scalar(
            select(OperatorCommandReceipt).where(
                OperatorCommandReceipt.subject_id == "spontaneous"
            )
        )
        assert receipt is not None
        assert receipt.actor_id == "spontaneous" and receipt.action == "enroll"
        assert receipt.reason == "self_enroll_open_class"
        assert receipt.result["enrolled"] and receipt.result["assigned"]


def test_replay_is_idempotent_and_open_class_is_unique(self_enroll_api):
    client, engine = self_enroll_api
    first = client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    second = client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    assert first.status_code == 200 and second.status_code == 200
    assert second.json()["context"] == first.json()["context"]
    with Session(engine) as session:
        open_classes = session.scalars(
            select(Classroom).where(Classroom.enrollment_policy == "open")
        ).all()
        assert len(open_classes) == 1
        assert len(session.scalars(select(Enrollment).where(Enrollment.user_id == "spontaneous")).all()) == 1
        assert len(session.scalars(select(OperatorCommandReceipt).where(OperatorCommandReceipt.subject_id == "spontaneous")).all()) == 1


def test_second_student_reuses_the_same_open_class(self_enroll_api):
    client, engine = self_enroll_api
    with Session(engine) as session:
        session.add(User(id="second", cpf_digest="second", phone="63988776655", name="Outra", password_digest="d", role="student"))
        session.commit()
    first = client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    second = client.post("/courses/course/self-enroll", headers=header("second"))
    assert first.status_code == 200 and second.status_code == 200
    assert first.json()["context"]["cohort_id"] == second.json()["context"]["cohort_id"]
    with Session(engine) as session:
        assert len(session.scalars(select(Classroom).where(Classroom.enrollment_policy == "open")).all()) == 1
        assert len(session.scalars(select(ClassEnrollment)).all()) == 4  # 2 seed links + 2 new


def test_open_classes_lists_policy_and_viewer_state(self_enroll_api):
    client, _ = self_enroll_api
    client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    listing = client.get("/open-classes", headers=header("learner")).json()["classes"]
    assert len(listing) == 1
    row = listing[0]
    assert row["enrollment_policy"] == "open" and row["course_id"] == "course"
    assert row["course_title"] and row["course_version_id"] == "v2"
    assert row["viewer_enrolled"] is False
    own = client.get("/open-classes", headers=header("spontaneous")).json()["classes"]
    assert own[0]["viewer_enrolled"] is True


def test_unknown_or_unpublished_course_fails_explicitly(self_enroll_api):
    client, engine = self_enroll_api
    assert client.post("/courses/missing/self-enroll", headers=header("spontaneous")).status_code == 404
    with Session(engine) as session:
        session.add(Course(id="draft-course", title="Draft", author="TDS", content={}, active=True))
        session.add(CourseVersion(id="dv1", course_id="draft-course", version_number=1, revision=1, status="draft", content={}))
        session.commit()
    denied = client.post("/courses/draft-course/self-enroll", headers=header("spontaneous"))
    assert denied.status_code == 409


def test_course_without_offering_or_responsible_fails_explicitly(self_enroll_api):
    client, engine = self_enroll_api
    with Session(engine) as session:
        session.add(Course(id="offered-nowhere", title="Sem oferta", author="TDS", content={}, active=True))
        session.add(CourseVersion(id="onv1", course_id="offered-nowhere", version_number=1, revision=1, status="published", content={}))
        session.add(Program(id="p3", institution_id="i1", name="Program 3"))
        session.add(Course(id="no-owner", title="Sem responsável", author="TDS", content={}, active=True))
        session.add(CourseVersion(id="nov1", course_id="no-owner", version_number=1, revision=1, status="published", content={}))
        session.add(ProgramCourse(program_id="p3", course_id="no-owner", planned_seconds=60))
        session.commit()
    assert client.post("/courses/offered-nowhere/self-enroll", headers=header("spontaneous")).status_code == 409
    assert client.post("/courses/no-owner/self-enroll", headers=header("spontaneous")).status_code == 409


def test_inactive_enrollment_is_not_silently_reactivated(self_enroll_api):
    client, engine = self_enroll_api
    assert client.post("/courses/course/self-enroll", headers=header("spontaneous")).status_code == 200
    with Session(engine) as session:
        enrollment = session.scalar(select(Enrollment).where(Enrollment.user_id == "spontaneous"))
        enrollment.status = "inactive"
        session.commit()
    assert client.post("/courses/course/self-enroll", headers=header("spontaneous")).status_code == 409


class _RecordingSink:
    def __init__(self, fail=False):
        self.calls = []
        self.fail = fail

    def wp_user_id(self, user):
        self.calls.append(("resolve", user.id))
        if self.fail:
            raise RuntimeError("boom")
        return 4242

    def enroll(self, wp_user_id, course_slug):
        self.calls.append(("enroll", wp_user_id, course_slug))


@pytest.fixture
def syncing_api(self_enroll_api):
    client, engine = self_enroll_api
    client.app.state.settings = replace(
        client.app.state.settings, learnpress_sync_enabled=True
    )
    return client, engine


def _database(client):
    return client.app.state.database


def test_sync_enqueues_and_worker_projects_to_wordpress(syncing_api):
    client, engine = syncing_api
    assert client.post("/courses/course/self-enroll", headers=header("spontaneous")).status_code == 200
    client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    with Session(engine) as session:
        items = session.scalars(select(ExternalSyncRequest)).all()
        assert len(items) == 1
        assert items[0].status == "pending" and items[0].kind == "learnpress_enroll"
    sink = _RecordingSink()
    worker = LearnPressSyncWorker(_database(client), sink, batch_size=10, max_attempts=2)
    assert worker.run_once() == 1
    assert sink.calls == [("resolve", "spontaneous"), ("enroll", 4242, "course")]
    with Session(engine) as session:
        item = session.scalar(select(ExternalSyncRequest))
        assert item.status == "done" and item.completed_at is not None
    assert worker.run_once() == 0


def test_sync_failure_retries_with_backoff_then_exhausts(syncing_api):
    client, engine = syncing_api
    client.post("/courses/course/self-enroll", headers=header("spontaneous"))
    sink = _RecordingSink(fail=True)
    worker = LearnPressSyncWorker(_database(client), sink, batch_size=10, max_attempts=2)
    start = datetime.now(timezone.utc)
    assert worker.run_once(now=start) == 0
    with Session(engine) as session:
        item = session.scalar(select(ExternalSyncRequest))
        assert item.status == "failed" and item.attempts == 1 and item.next_attempt_at is not None
        retry_at = item.next_attempt_at
    # Not yet due: stays claimed-free until backoff elapses.
    assert worker.run_once(now=start) == 0
    later = retry_at + timedelta(seconds=1)
    assert worker.run_once(now=later) == 0
    with Session(engine) as session:
        item = session.scalar(select(ExternalSyncRequest))
        assert item.status == "failed" and item.attempts == 2 and item.next_attempt_at is None


def test_wordpress_client_registers_when_lookup_misses(monkeypatch):
    calls = []

    class _Response:
        def __init__(self, status, payload):
            self.status = status
            self._payload = payload

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def read(self):
            import json as _json

            return _json.dumps(self._payload).encode()

    def fake_urlopen(call, timeout=0):
        calls.append((call.get_method(), call.full_url))
        if "/user-by-phone/" in call.full_url:
            from urllib.error import HTTPError

            raise HTTPError(call.full_url, 404, "nf", None, None)
        if call.full_url.endswith("/wp-json/tds/v1/register"):
            return _Response(201, {"created": True, "user_id": 99})
        if call.full_url.endswith("/wp-json/tds/v1/enroll"):
            return _Response(201, {"success": True})
        raise AssertionError(call.full_url)

    monkeypatch.setattr("app.learnpress_sync.request.urlopen", fake_urlopen)
    client = WordPressTdsClient("https://wp.example", "x" * 20)
    user = User(id="u1", cpf_digest="d", phone="63 99988-7766", name="Aluno", password_digest="d", role="student")
    assert client.wp_user_id(user) == 99
    client.enroll(99, "course")
    methods = [method for method, _ in calls]
    assert methods == ["GET", "POST", "POST"]
    assert calls[1][1].endswith("/wp-json/tds/v1/register")
    assert calls[2][1].endswith("/wp-json/tds/v1/enroll")
