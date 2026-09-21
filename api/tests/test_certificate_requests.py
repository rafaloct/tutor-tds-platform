from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
from uuid import uuid4

from alembic import command
from alembic.config import Config
from fastapi import Header
from fastapi.testclient import TestClient
import pytest
from sqlalchemy import event, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import access_claims
from app.config import Settings
from app.course_editor import legacy_version_id
from app.main import create_app
from app.models import CertificateReference, CertificateRequest, CertificateRequestTransition, ClassEnrollment, Classroom, Course, CourseVersion, CourseVersionTransition, Enrollment, Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User

ORIGINAL = legacy_version_id("course")


@pytest.fixture
def requests_api(tmp_path):
    url = f"sqlite+pysqlite:///{(tmp_path / 'requests.db').as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", url)
    command.upgrade(config, "head")
    settings = Settings(database_url=url, allowed_origins=(), jwt_secret="test-jwt-secret-with-at-least-32-chars", cpf_pepper="test-cpf-pepper-with-at-least-32-chars")
    app = create_app(settings=settings)
    engine = app.state.database.engine

    @event.listens_for(engine, "connect")
    def foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    def claims(x_user: str = Header(default="learner")):
        return {"sub": x_user, "role": "admin" if x_user == "admin" else "student"}

    app.dependency_overrides[access_claims] = claims
    with Session(engine) as session:
        session.add_all([Institution(id=identity, name=f"Institution {identity}") for identity in ("i1", "i2")])
        session.add_all([User(id=identity, cpf_digest=identity, phone="61999990000", name=f"Name {identity}", password_digest="digest", role="admin" if identity == "admin" else "student") for identity in ("learner", "other", "teacher", "teacher2", "coordinator", "monitor", "outsider", "admin")])
        session.flush()
        session.add_all([Program(id=f"p{index}", institution_id=f"i{index}", name=f"Program {index}") for index in (1, 2)])
        session.add(Course(id="course", title="Current edition", author="TDS", content={"sections": []}, active=True))
        session.flush()
        for program in ("p1", "p2"):
            session.add(ProgramCourse(program_id=program, course_id="course", planned_seconds=60))
        for user, program, role in (("learner", "p1", "student"), ("learner", "p2", "student"), ("other", "p1", "student"), ("teacher", "p1", "teacher"), ("teacher2", "p1", "teacher"), ("coordinator", "p1", "coordinator"), ("monitor", "p1", "monitor"), ("outsider", "p2", "coordinator")):
            session.add(ProgramMembership(user_id=user, program_id=program, role=role, status="active"))
        session.add_all([CourseVersion(id=ORIGINAL, course_id="course", version_number=1, revision=2, status="archived", content={"title": "Original edition", "sections": []}), CourseVersion(id="v2", course_id="course", version_number=2, revision=1, status="published", content={"title": "Current edition", "sections": []}), CourseVersion(id="draft", course_id="course", version_number=3, revision=1, status="draft", content={"title": "Private draft"})])
        session.flush()
        session.add(CourseVersionTransition(id="original-publication", version_id=ORIGINAL, to_status="published", actor_role="migration"))
        for identity, user, program in (("e1", "learner", "p1"), ("e2", "learner", "p2"), ("other-e", "other", "p1")):
            session.add(Enrollment(id=identity, user_id=user, program_id=program, course_id="course", status="active"))
        for identity, program, teacher, version in (("c1", "p1", "teacher", ORIGINAL), ("c2", "p1", "teacher2", "v2"), ("foreign-class", "p2", "outsider", ORIGINAL)):
            session.add(Classroom(id=identity, program_id=program, course_id="course", course_version_id=version, teacher_id=teacher, name=identity, start_date=date(2026, 1, 1), end_date=date(2026, 12, 1), status="closed"))
        session.flush()
        session.add_all([ClassEnrollment(class_id=identity, user_id="learner", enrollment_id="e1", program_id="p1", course_id="course", status="active") for identity in ("c1", "c2")])
        session.commit()
    with TestClient(app) as client:
        yield client, engine


def header(user):
    return {"X-User": user}


def create(client, *, enrollment="e1", version=ORIGINAL, classroom=None, user="learner"):
    return client.post("/certificate-requests", headers=header(user), json={"enrollment_id": enrollment, "course_version_id": version, "class_id": classroom})


def review(client, record, *, user="coordinator", decision="approve", reason="Conferido pela equipe"):
    return client.post(f"/certificate-requests/{record['id']}/review", headers=header(user), json={"expected_revision": record["revision"], "decision": decision, "reason": reason})


def evidence(engine, *, enrollment="e1", user="learner", version=ORIGINAL, classroom=None, seconds=60, completed=True):
    payload = {} if version is None else {"course_version_id": version}
    if classroom is not None:
        payload["class_id"] = classroom
    with Session(engine) as session:
        session.add(LearningEventRecord(event_id=str(uuid4()), user_id=user, enrollment_id=enrollment, course_id="course", event_type="study_activity", session_id="study", occurred_at=datetime(2026, 1, 1, tzinfo=timezone.utc), payload=payload, active_seconds=seconds, validated_seconds=seconds))
        if completed:
            session.add(LearningEventRecord(event_id=str(uuid4()), user_id=user, enrollment_id=enrollment, course_id="course", event_type="lesson_completed", session_id="study", occurred_at=datetime(2026, 1, 1, tzinfo=timezone.utc), payload=payload))
        session.commit()


def test_contexts_are_own_active_and_snapshot_request_is_pending_idempotent(requests_api):
    client, engine = requests_api
    contexts = client.get(f"/certificate-requests/contexts?course_id=course&course_version_id={ORIGINAL}").json()["contexts"]
    assert {(row["enrollment_id"], row["class_id"]) for row in contexts} == {("e1", None), ("e1", "c1"), ("e2", None)}
    assert all(row["course_title"] == "Original edition" and not row["eligibility"]["eligible"] for row in contexts)
    first = create(client)
    assert first.status_code == 201, first.text
    record = first.json()
    assert record["status"] == "pending" and record["institution_name"] == "Institution i1"
    assert record["holder_name"] == "Name learner" and record["reviewed_at"] is None
    assert record["requested_at"].endswith(("Z", "+00:00"))
    assert create(client).json() == record
    assert create(client).status_code == 200
    assert create(client, classroom="c1").status_code == 409
    with Session(engine) as session:
        session.get(Course, "course").title = "Later catalog title"
        session.get(User, "learner").name = "Changed profile"
        session.get(ProgramCourse, ("p1", "course")).planned_seconds = 999
        session.get(Program, "p1").name = "Changed program name"
        session.get(Institution, "i1").name = "Changed institution name"
        session.commit()
    current = client.get(f"/certificate-requests/{record['id']}").json()
    assert current["course_title"] == "Original edition" and current["holder_name"] == "Name learner"
    assert current["program_name"] == "Program 1" and current["institution_name"] == "Institution i1"
    assert current["eligibility"]["required_seconds"] == 60
    with Session(engine) as session:
        assert session.scalars(select(CertificateReference)).all() == []
        assert len(session.scalars(select(CertificateRequestTransition)).all()) == 1


def test_request_review_roundtrip_persists_decision_and_student_rereads_it(requests_api):
    client, engine = requests_api
    contexts = client.get(f"/certificate-requests/contexts?course_id=course&course_version_id={ORIGINAL}").json()["contexts"]
    context = next(row for row in contexts if row["class_id"] == "c1")
    response = create(client, enrollment=context["enrollment_id"], version=context["course_version_id"], classroom=context["class_id"])
    assert response.status_code == 201
    pending = response.json()
    assert client.get(f"/certificate-requests/{pending['id']}").json()["status"] == "pending"
    queue = client.get("/certificate-requests/review-queue", headers=header("teacher")).json()["requests"]
    assert [row["id"] for row in queue] == [pending["id"]]
    evidence(engine, classroom="c1")
    assert review(client, pending, user="teacher").status_code == 200
    with Session(engine) as session:
        assert session.get(CertificateRequest, pending["id"]).status == "approved"
        decision = session.scalar(select(CertificateRequestTransition).where(CertificateRequestTransition.request_id == pending["id"], CertificateRequestTransition.revision == 2))
        assert decision.actor_user_id == "teacher" and decision.to_status == "approved"
        assert decision.reason == "Conferido pela equipe"
    own = client.get("/certificate-requests").json()["requests"]
    assert own[0]["id"] == pending["id"] and own[0]["status"] == "approved"


def test_public_requests_require_coordinator_and_private_reads_do_not_leak(requests_api):
    client, engine = requests_api
    record = create(client).json()
    assert client.get("/certificate-requests", headers=header("other")).json() == {"requests": []}
    for outsider in ("other", "monitor", "teacher", "outsider"):
        assert client.get(f"/certificate-requests/{record['id']}", headers=header(outsider)).status_code == 404
        assert review(client, record, user=outsider).status_code in {403, 404}
    assert client.get("/certificate-requests/review-queue", headers=header("learner")).status_code == 403
    assert client.get("/certificate-requests/review-queue", headers=header("monitor")).status_code == 403
    assert client.get("/certificate-requests/review-queue", headers=header("teacher")).json() == {"requests": []}
    assert client.get("/certificate-requests/review-queue", headers=header("outsider")).json() == {"requests": []}
    assert client.get("/certificate-requests/review-queue", headers=header("coordinator")).json()["requests"][0]["id"] == record["id"]
    assert review(client, record).status_code == 422
    evidence(engine)
    approved = review(client, record)
    assert approved.status_code == 200, approved.text
    assert approved.json()["status"] == "approved" and approved.json()["revision"] == 2
    assert approved.json()["reviewed_at"].endswith(("Z", "+00:00"))
    assert review(client, record).status_code == 409
    assert create(client).json()["status"] == "approved"
    assert client.get("/certificate-requests/review-queue", headers=header("coordinator")).json() == {"requests": []}


def test_review_queue_scopes_rows_before_orm_loading(requests_api):
    client, engine = requests_api
    class_request = create(client, classroom="c1").json()
    foreign_request = create(client, enrollment="e2").json()
    public_request = create(client, enrollment="other-e", user="other").json()
    assert class_request["class_name"] == "c1"
    assert public_request["class_name"] is None
    loaded = []

    def on_load(record, _context):
        loaded.append(record.id)

    event.listen(CertificateRequest, "load", on_load)
    try:
        expected_by_actor = {
            "coordinator": {class_request["id"], public_request["id"]},
            "outsider": {foreign_request["id"]},
            "teacher": {class_request["id"]},
            "teacher2": set(),
            "admin": {class_request["id"], public_request["id"], foreign_request["id"]},
        }
        for actor, expected in expected_by_actor.items():
            loaded.clear()
            response = client.get("/certificate-requests/review-queue", headers=header(actor))
            assert response.status_code == 200
            assert {item["id"] for item in response.json()["requests"]} == expected
            assert set(loaded) == expected
    finally:
        event.remove(CertificateRequest, "load", on_load)
    with Session(engine) as session:
        session.get(Classroom, "c1").name = "Renamed class"
        session.commit()
    assert client.get(f"/certificate-requests/{class_request['id']}").json()["class_name"] == "Renamed class"


def test_review_queue_revalidates_membership_and_teacher_ownership(requests_api):
    client, engine = requests_api
    record = create(client, classroom="c1").json()
    with Session(engine) as session:
        session.get(ProgramMembership, ("coordinator", "p1")).role = "admin"
        session.get(Classroom, "c1").teacher_id = "teacher2"
        session.commit()
    assert client.get("/certificate-requests/review-queue", headers=header("teacher")).status_code == 403
    for actor in ("coordinator", "teacher2"):
        response = client.get("/certificate-requests/review-queue", headers=header(actor))
        assert response.status_code == 200
        assert [item["id"] for item in response.json()["requests"]] == [record["id"]]
    with Session(engine) as session:
        session.get(ProgramMembership, ("teacher2", "p1")).status = "inactive"
        session.get(ProgramMembership, ("coordinator", "p1")).status = "inactive"
        session.get(Classroom, "c1").teacher_id = "monitor"
        session.commit()
    for actor in ("teacher2", "coordinator", "monitor", "learner"):
        assert client.get("/certificate-requests/review-queue", headers=header(actor)).status_code == 403


def test_class_teacher_and_exact_edition_evidence_only(requests_api):
    client, engine = requests_api
    record = create(client, classroom="c1").json()
    evidence(engine, version="v2", classroom="c2")
    evidence(engine, version=ORIGINAL, classroom="c2")
    evidence(engine, version=ORIGINAL)
    evidence(engine, version=None)
    evidence(engine, enrollment="e2", version=ORIGINAL, classroom="c1")
    assert client.get(f"/certificate-requests/{record['id']}").json()["eligibility"]["validated_seconds"] == 0
    assert review(client, record, user="teacher2").status_code == 404
    assert review(client, record, user="teacher").status_code == 422
    evidence(engine, classroom="c1", seconds=30, completed=False)
    assert review(client, record, user="teacher").status_code == 422
    evidence(engine, classroom="c1", seconds=30)
    assert review(client, record, user="teacher").json()["status"] == "approved"


def test_unversioned_legacy_counts_only_original_public_edition(requests_api):
    client, engine = requests_api
    evidence(engine, version=None)
    original = create(client).json()
    latest = create(client, version="v2").json()
    assert original["eligibility"]["eligible"] is True
    assert latest["eligibility"] == {"required_seconds": 60, "validated_seconds": 0, "completed": False, "eligible": False}
    assert review(client, latest).status_code == 422
    assert review(client, original).status_code == 200


def test_rejection_explicit_resubmit_and_immutable_audit(requests_api):
    client, engine = requests_api
    pending = create(client, classroom="c1").json()
    rejected = review(client, pending, user="teacher", decision="reject", reason="Atividade ainda incompleta").json()
    assert rejected["status"] == "rejected"
    assert create(client, classroom="c1").json()["status"] == "rejected"
    assert client.post(f"/certificate-requests/{pending['id']}/resubmit", headers=header("coordinator"), json={"expected_revision": 2}).status_code == 403
    assert client.post(f"/certificate-requests/{pending['id']}/resubmit", json={"expected_revision": 1}).status_code == 409
    reopened = client.post(f"/certificate-requests/{pending['id']}/resubmit", json={"expected_revision": 2}).json()
    assert reopened["status"] == "pending" and reopened["revision"] == 3 and reopened["review_reason"] is None
    assert reopened["requested_at"] == pending["requested_at"]
    evidence(engine, classroom="c1")
    assert review(client, reopened, user="teacher").json()["status"] == "approved"
    with Session(engine) as session:
        history = session.scalars(select(CertificateRequestTransition).order_by(CertificateRequestTransition.revision)).all()
        assert [item.to_status for item in history] == ["pending", "rejected", "pending", "approved"]
        assert [item.actor_user_id for item in history] == ["learner", "teacher", "learner", "teacher"]
        assert history[1].reason == "Atividade ainda incompleta" and not history[1].eligibility["eligible"]
        assert history[-1].eligibility["eligible"]
    for statement in ("UPDATE certificate_requests SET holder_name='Tampered'", "UPDATE certificate_requests SET required_seconds=0", "UPDATE certificate_requests SET revision=99", "UPDATE certificate_request_transitions SET reason='Rewritten'", "DELETE FROM certificate_request_transitions"):
        with pytest.raises(IntegrityError), engine.begin() as connection:
            connection.execute(text(statement))


@pytest.mark.parametrize("mutation", ["enrollment", "class", "membership", "reviewer"])
def test_approval_revalidates_active_links(requests_api, mutation):
    client, engine = requests_api
    record = create(client, classroom="c1").json()
    evidence(engine, classroom="c1")
    with Session(engine) as session:
        target = {"enrollment": session.get(Enrollment, "e1"), "class": session.get(ClassEnrollment, ("c1", "learner")), "membership": session.get(ProgramMembership, ("learner", "p1")), "reviewer": session.get(ProgramMembership, ("teacher", "p1"))}[mutation]
        target.status = "inactive"
        session.commit()
    assert review(client, record, user="teacher").status_code in {403, 404, 422}
    assert client.get(f"/certificate-requests/{record['id']}").json()["status"] == "pending"


def test_owner_cannot_approve_even_with_global_admin_role(requests_api):
    client, engine = requests_api
    record = create(client).json()
    evidence(engine)
    with Session(engine) as session:
        session.get(User, "learner").role = "admin"
        session.commit()
    assert review(client, record, user="learner").status_code == 403
    assert client.get("/certificate-requests/review-queue").json() == {"requests": []}
    assert review(client, record, user="admin").status_code == 200


def test_foreign_enrollment_edition_class_institution_and_payload_are_rejected(requests_api):
    client, engine = requests_api
    assert create(client, enrollment="other-e").status_code == 404
    assert create(client, version="draft").status_code == 422
    assert create(client, classroom="foreign-class").status_code == 422
    assert create(client, version="v2", classroom="c1").status_code == 422
    assert client.post("/certificate-requests", json={"enrollment_id": "e1", "course_version_id": ORIGINAL, "holder_name": "Injected"}).status_code == 422
    record = create(client).json()
    for reason in ("  ", "aa", "x" * 501):
        assert review(client, record, reason=reason).status_code == 422
    evidence(engine)
    with Session(engine) as session:
        session.get(Program, "p1").institution_id = "i2"
        session.commit()
    assert review(client, record).status_code == 409
    assert client.get(f"/certificate-requests/{record['id']}").json()["institution_name"] == "Institution i1"


def test_parallel_reviews_have_one_winner_and_one_audit(requests_api):
    client, engine = requests_api
    record = create(client).json()
    evidence(engine)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda user: review(client, record, user=user).status_code, ["coordinator", "admin"]))
    assert sorted(results) == [200, 409]
    with Session(engine) as session:
        assert len(session.scalars(select(CertificateRequestTransition)).all()) == 2


@pytest.mark.parametrize("foreign_keys_enabled", [True, False])
def test_account_erasure_removes_private_request_history_without_orphans(requests_api, foreign_keys_enabled):
    client, engine = requests_api
    record = create(client).json()
    review(client, record, decision="reject")
    if not foreign_keys_enabled:
        with engine.connect() as connection:
            connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
    deleted = client.delete("/auth/me")
    assert deleted.status_code == 204, deleted.text
    with Session(engine) as session:
        assert session.get(User, "learner") is None
        assert session.scalars(select(CertificateRequest)).all() == []
        assert session.scalars(select(CertificateRequestTransition)).all() == []
        assert session.get(User, "coordinator") is not None


def test_departed_reviewer_is_anonymized_without_rewriting_other_learners_decision(requests_api):
    client, engine = requests_api
    record = create(client).json()
    review(client, record, decision="reject")
    with Session(engine) as session:
        session.get(ProgramMembership, ("coordinator", "p1")).status = "inactive"
        session.commit()
    assert client.delete("/auth/me", headers=header("coordinator")).status_code == 204
    with Session(engine) as session:
        audit = session.scalar(select(CertificateRequestTransition).where(CertificateRequestTransition.revision == 2))
        assert audit.actor_user_id is None and audit.actor_role == "coordinator"
        assert audit.reason == "Conferido pela equipe"
        assert session.get(CertificateRequest, record["id"]).holder_name == "Name learner"


def test_parallel_create_reuses_one_request_without_duplicate_audit(requests_api):
    client, engine = requests_api
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: create(client), range(2)))
    assert sorted(response.status_code for response in responses) == [200, 201]
    assert len({response.json()["id"] for response in responses}) == 1
    with Session(engine) as session:
        assert len(session.scalars(select(CertificateRequest)).all()) == 1
        assert len(session.scalars(select(CertificateRequestTransition)).all()) == 1


def test_requests_do_not_change_existing_certificate_or_allow_issued_status(requests_api):
    client, engine = requests_api
    with Session(engine) as session:
        session.add(CertificateReference(id="legacy-certificate", user_id="learner", course_id="course", course_title="Historical title", holder_name="Historical holder", verification_url="https://example.test/verify/legacy", content_hash="unchanged", issued_at=datetime(2025, 1, 1, tzinfo=timezone.utc)))
        session.commit()
    pending = create(client).json()
    evidence(engine)
    assert review(client, pending).json()["status"] == "approved"
    with Session(engine) as session:
        certificate = session.get(CertificateReference, "legacy-certificate")
        assert certificate.course_title == "Historical title" and certificate.holder_name == "Historical holder"
        assert certificate.content_hash == "unchanged"
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("UPDATE certificate_requests SET status='issued', revision=revision+1"))
