from __future__ import annotations

import json
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    Course,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    LearningEventRecord,
)

PASSWORD = "uma-senha-forte-2026"


def test_certificate_reference_preserves_academic_snapshot_and_is_idempotent() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        certificate_verification_url_prefix="https://cert.example/v1/certificates/",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        account = client.post(
            "/auth/register",
            json={
                "name": "Estudante Teste",
                "cpf": "123.456.789-09",
                "phone": "61999990000",
                "password": PASSWORD,
            },
        ).json()
        user_id = account["user"]["id"]
        headers = {"Authorization": f"Bearer {account['access_token']}"}
        with Session(app.state.database.engine) as session:
            session.add(Institution(id="institution-1", name="Instituto TDS"))
            session.add(
                Program(
                    id="program-1",
                    institution_id="institution-1",
                    name="Programa TDS",
                )
            )
            session.add(
                Course(
                    id="course-1",
                    title="Curso Seguro",
                    author="TDS",
                    content={"sections": []},
                    active=True,
                )
            )
            session.flush()
            session.add(
                ProgramCourse(
                    program_id="program-1",
                    course_id="course-1",
                    planned_seconds=60,
                )
            )
            session.add(
                ProgramMembership(
                    user_id=user_id,
                    program_id="program-1",
                    role="student",
                    status="active",
                )
            )
            session.flush()
            session.add(
                Enrollment(
                    id="enrollment-1",
                    user_id=user_id,
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.add_all([
                LearningEventRecord(
                    event_id="activity-1", user_id=user_id, enrollment_id="enrollment-1",
                    course_id="course-1", event_type="study_activity", session_id="study-1",
                    occurred_at=datetime(2026, 9, 20, 11, tzinfo=timezone.utc), payload={},
                    active_seconds=60, validated_seconds=60, sync_status="pending",
                ),
                LearningEventRecord(
                    event_id="complete-1", user_id=user_id, enrollment_id="enrollment-1",
                    course_id="course-1", event_type="lesson_completed", session_id="study-1",
                    occurred_at=datetime(2026, 9, 20, 11, 5, tzinfo=timezone.utc), payload={},
                    active_seconds=0, validated_seconds=0, sync_status="pending",
                ),
            ])
            session.commit()

        payload = {
            "id": "certificate-123",
            "program_id": "program-1",
            "course_id": "course-1",
            "issued_at": "2026-09-20T12:00:00Z",
            "verification_url": "https://cert.example/v1/certificates/certificate-123",
            "content_hash": "a" * 64,
        }
        public_payload = json.dumps({"valid": True, "certificate": {
            "id": "certificate-123", "courseId": "course-1",
            "holderName": "Estudante Teste", "contentHash": "a" * 64,
        }}).encode()
        response_mock = MagicMock()
        response_mock.__enter__.return_value.read.return_value = public_payload
        with patch("app.certificates.urlrequest.urlopen", return_value=response_mock):
            created = client.post(
                "/certificates/references", json=payload, headers=headers
            )
            retried = client.post(
                "/certificates/references", json=payload, headers=headers
            )
        conflict = client.post(
            "/certificates/references",
            json=payload | {"content_hash": "b" * 64},
            headers=headers,
        )
        wallet = client.get("/certificates", headers=headers)
        outsider = client.post(
            "/auth/register",
            json={
                "name": "Outro Estudante",
                "cpf": "987.654.321-00",
                "phone": "61999990001",
                "password": PASSWORD,
            },
        ).json()
        outsider_wallet = client.get(
            "/certificates",
            headers={"Authorization": f"Bearer {outsider['access_token']}"},
        )

    assert created.status_code == 201
    assert retried.status_code == 200
    assert conflict.status_code == 409
    assert created.json()["holder_name"] == "Estudante Teste"
    assert created.json()["course_title"] == "Curso Seguro"
    assert created.json()["institution_name"] == "Instituto TDS"
    assert created.json()["planned_hours"] == 0.0167
    assert wallet.json()["certificates"] == [created.json()]
    assert outsider_wallet.status_code == 200
    assert outsider_wallet.json() == {"certificates": []}
    serialized = json.dumps(wallet.json()).lower()
    assert "cpf" not in serialized and "phone" not in serialized


def test_certificate_reference_rejects_untrusted_verification_origin() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        certificate_verification_url_prefix="https://cert.example/v1/certificates/",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        account = client.post(
            "/auth/register",
            json={
                "name": "Estudante Teste",
                "cpf": "123.456.789-09",
                "phone": "61999990000",
                "password": PASSWORD,
            },
        ).json()
        response = client.post(
            "/certificates/references",
            headers={"Authorization": f"Bearer {account['access_token']}"},
            json={
                "id": "certificate-123",
                "program_id": "program-1",
                "course_id": "course-1",
                "issued_at": "2026-09-20T12:00:00Z",
                "verification_url": "https://evil.example/certificate-123",
                "content_hash": "a" * 64,
            },
        )

    assert response.status_code == 422
