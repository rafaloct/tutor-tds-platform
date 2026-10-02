from __future__ import annotations

import json
from datetime import date, datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    CertificateRequest,
    ClassEnrollment,
    Classroom,
    Course,
    CourseVersion,
    Enrollment,
    Institution,
    LearningEventRecord,
    Program,
    ProgramCourse,
    ProgramMembership,
)


@pytest.fixture
def reference_api():
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        certificate_verification_url_prefix="https://cert.example/v1/certificates/",
        certificate_approval_required=True,
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        account = client.post("/auth/register", json={
            "name": "Estudante Teste", "cpf": "123.456.789-09",
            "phone": "61999990000", "password": "uma-senha-forte-2026",
        }).json()
        user_id = account["user"]["id"]
        with Session(app.state.database.engine) as session:
            session.add_all([
                Institution(id="institution", name="Instituto TDS"),
                Program(id="program", institution_id="institution", name="Programa TDS"),
                Course(id="course", title="Curso", author="TDS", content={}, active=True),
            ])
            session.flush()
            session.add_all([
                ProgramCourse(program_id="program", course_id="course", planned_seconds=60),
                ProgramMembership(user_id=user_id, program_id="program", role="student", status="active"),
                Enrollment(id="enrollment", user_id=user_id, program_id="program", course_id="course", status="active"),
                CourseVersion(id="edition-1", course_id="course", version_number=1, revision=1, status="published", content={"title": "Edição 1"}),
                CourseVersion(id="edition-2", course_id="course", version_number=2, revision=1, status="published", content={"title": "Edição 2"}),
                Classroom(id="class-1", program_id="program", course_id="course", course_version_id="edition-1", teacher_id=user_id, name="Turma 1", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1), status="closed"),
                Classroom(id="class-2", program_id="program", course_id="course", course_version_id="edition-2", teacher_id=user_id, name="Turma 2", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1), status="closed"),
                ClassEnrollment(class_id="class-1", user_id=user_id, enrollment_id="enrollment", program_id="program", course_id="course", status="active"),
                ClassEnrollment(class_id="class-2", user_id=user_id, enrollment_id="enrollment", program_id="program", course_id="course", status="active"),
            ])
            session.commit()
        yield client, app.state.database.engine, user_id, account["access_token"]


def _approve(engine, user_id: str, edition: str, class_id: str | None) -> None:
    with Session(engine) as session:
        session.add(CertificateRequest(
            id=f"request-{edition}", user_id=user_id, enrollment_id="enrollment",
            course_id="course", course_version_id=edition, class_id=class_id,
            program_id="program", institution_id="institution", holder_name="Estudante Teste",
            course_title=edition, program_name="Programa TDS", institution_name="Instituto TDS",
            required_seconds=60, status="approved", revision=2,
            reviewed_at=datetime(2026, 1, 2, tzinfo=timezone.utc), review_reason="Conferido",
        ))
        session.commit()


def _evidence(engine, user_id: str, edition: str, class_id: str) -> None:
    payload = {"course_version_id": edition, "class_id": class_id}
    with Session(engine) as session:
        session.add_all([
            LearningEventRecord(event_id=f"activity-{edition}", user_id=user_id, enrollment_id="enrollment", course_id="course", event_type="study_activity", session_id=edition, occurred_at=datetime(2026, 1, 3, tzinfo=timezone.utc), payload=payload, active_seconds=60, validated_seconds=60),
            LearningEventRecord(event_id=f"complete-{edition}", user_id=user_id, enrollment_id="enrollment", course_id="course", event_type="lesson_completed", session_id=edition, occurred_at=datetime(2026, 1, 3, tzinfo=timezone.utc), payload=payload),
        ])
        session.commit()


def _post(client, token: str, certificate_id: str, class_id: str | None):
    payload = {
        "id": certificate_id, "program_id": "program", "course_id": "course",
        "issued_at": "2026-01-04T00:00:00Z",
        "verification_url": f"https://cert.example/v1/certificates/{certificate_id}",
        "content_hash": "a" * 64,
    }
    if class_id is not None:
        payload["class_id"] = class_id
    public = json.dumps({"valid": True, "certificate": {
        "id": certificate_id, "courseId": "course", "holderName": "Estudante Teste", "contentHash": "a" * 64,
    }}).encode()
    response_mock = MagicMock()
    response_mock.__enter__.return_value.read.return_value = public
    with patch("app.certificates.urlrequest.urlopen", return_value=response_mock):
        return client.post("/certificates/references", json=payload, headers={"Authorization": f"Bearer {token}"})


def test_reference_guard_rejects_other_edition_evidence(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _approve(engine, user_id, "edition-2", "class-2")
    _evidence(engine, user_id, "edition-2", "class-2")

    assert _post(client, token, "certificate-class-1", "class-1").status_code == 422


def test_reference_guard_rejects_omitted_class_with_approved_editions(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _approve(engine, user_id, "edition-2", "class-2")
    _evidence(engine, user_id, "edition-2", "class-2")

    assert _post(client, token, "certificate-no-class", None).status_code == 422


def test_reference_guard_revalidates_revoked_context(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-1")
    with Session(engine) as session:
        session.get(ProgramMembership, (user_id, "program")).status = "inactive"
        session.commit()

    assert _post(client, token, "certificate-revoked", "class-1").status_code == 422


def test_reference_guard_accepts_exact_context_and_replays(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-1")

    assert _post(client, token, "certificate-valid", "class-1").status_code == 201
    assert _post(client, token, "certificate-valid", "class-1").status_code == 200


def test_reference_guard_rejects_explicit_wrong_class(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-1")
    assert _post(client, token, "certificate-wrong-class", "class-2").status_code == 422


def test_reference_guard_rejects_ambiguous_public_editions(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", None)
    _approve(engine, user_id, "edition-2", None)
    _evidence(engine, user_id, "edition-2", "class-2")
    assert _post(client, token, "certificate-ambiguous", None).status_code == 422


def test_reference_guard_accepts_exact_public_context(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", None)
    _evidence(engine, user_id, "edition-1", "class-1")
    assert _post(client, token, "certificate-public", None).status_code == 201
    assert _post(client, token, "certificate-public", None).status_code == 200


def test_reference_guard_rejects_changed_fixed_edition(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-1")
    with Session(engine) as session:
        session.get(Classroom, "class-1").course_version_id = "edition-2"
        session.commit()
    assert _post(client, token, "certificate-changed-edition", "class-1").status_code == 422


def test_reference_guard_rejects_revoked_class_link(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-1")
    with Session(engine) as session:
        session.get(ClassEnrollment, ("class-1", user_id)).status = "inactive"
        session.commit()
    assert _post(client, token, "certificate-revoked-class", "class-1").status_code == 422


def test_reference_guard_rejects_same_edition_wrong_class_events(reference_api):
    client, engine, user_id, token = reference_api
    _approve(engine, user_id, "edition-1", "class-1")
    _evidence(engine, user_id, "edition-1", "class-2")
    assert _post(client, token, "certificate-other-class-events", "class-1").status_code == 422
