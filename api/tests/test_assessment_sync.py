from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    Base,
    Course,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
)

PASSWORD = "uma-senha-forte-2026"


def _register(client: TestClient, cpf: str, name: str) -> dict[str, object]:
    return client.post(
        "/auth/register",
        json={
            "name": name,
            "cpf": cpf,
            "phone": "61999990000",
            "password": PASSWORD,
        },
    ).json()


def _bearer(account: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {account['access_token']}"}


def _payload(*, revision: int = 1) -> dict[str, object]:
    return {
        "course_id": "course-1",
        "assessment_content_id": "content-exam-1",
        "topic": "Princípios do cooperativismo",
        "mode": "exam",
        "revision": revision,
        "answers": {"0": 2},
        "marked": [1],
        "current_index": 1,
        "remaining_seconds": 300,
        "completed": False,
        "score": 0,
        "updated_at": f"2026-09-20T12:0{revision}:00Z",
    }


def _content_payload() -> dict[str, object]:
    return {
        "course_id": "course-1",
        "topic": "Princípios do cooperativismo",
        "mode": "exam",
        "title": "Simulado de cooperativismo",
        "duration_seconds": 600,
        "questions": [
            {
                "question": "Questão um?",
                "options": ["A", "B", "C"],
                "correct_index": 2,
                "explanation": "A alternativa C é a correta.",
                "topic": "Princípios",
            },
            {
                "question": "Questão dois?",
                "options": ["A", "B"],
                "correct_index": 0,
                "explanation": "A alternativa A é a correta.",
                "topic": "Valores",
            },
            {
                "question": "Questão três?",
                "options": ["A", "B"],
                "correct_index": 1,
                "explanation": "A alternativa B é a correta.",
                "topic": "Prática",
            },
        ],
    }


def test_attempt_upsert_retry_revision_isolation_and_account_deletion() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="j" * 32,
        cpf_pepper="p" * 32,
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        student = _register(client, "123.456.789-09", "Estudante")
        other = _register(client, "987.654.321-00", "Outra estudante")
        student_id = student["user"]["id"]
        other_id = other["user"]["id"]
        with Session(app.state.database.engine) as session:
            session.add(Institution(id="institution-1", name="Instituto"))
            session.add(Program(id="program-1", institution_id="institution-1", name="Programa"))
            session.add(Course(id="course-1", title="Curso", author="TDS", content={"sections": []}, active=True))
            session.flush()
            session.add(ProgramCourse(program_id="program-1", course_id="course-1"))
            session.add_all([
                ProgramMembership(user_id=student_id, program_id="program-1", role="student", status="active"),
                ProgramMembership(user_id=other_id, program_id="program-1", role="student", status="active"),
            ])
            session.flush()
            session.add_all([
                Enrollment(id="enrollment-1", user_id=student_id, program_id="program-1", course_id="course-1", status="active"),
                Enrollment(id="enrollment-2", user_id=other_id, program_id="program-1", course_id="course-1", status="active"),
            ])
            session.commit()

        content_created = client.put(
            "/assessment-contents/content-exam-1",
            headers=_bearer(student),
            json=_content_payload(),
        )
        content_retry = client.put(
            "/assessment-contents/content-exam-1",
            headers=_bearer(student),
            json=_content_payload(),
        )
        content_conflict = client.put(
            "/assessment-contents/content-exam-1",
            headers=_bearer(student),
            json=_content_payload() | {"title": "Título divergente"},
        )
        content_cross_read = client.get(
            "/assessment-contents/content-exam-1",
            headers=_bearer(other),
        )
        missing_content_reference = client.put(
            "/assessment-attempts/attempt-without-content",
            headers=_bearer(student),
            json={
                key: value
                for key, value in _payload().items()
                if key != "assessment_content_id"
            },
        )
        invalid_answer_reference = client.put(
            "/assessment-attempts/attempt-invalid-answer",
            headers=_bearer(student),
            json=_payload() | {"answers": {"99": 0}},
        )
        created = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=_payload(),
        )
        retry = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=_payload(),
        )
        divergent_retry = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=_payload() | {"current_index": 2},
        )
        revision_two_payload = _payload(revision=2) | {
            "answers": {"0": 2, "1": 1},
            "marked": [],
            "current_index": 2,
            "remaining_seconds": 240,
        }
        updated = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=revision_two_payload,
        )
        update_retry = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=revision_two_payload,
        )
        stale = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=_payload(),
        )
        fetched = client.get(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
        )
        hydrated_incomplete = client.get(
            "/assessment-attempts/attempt-exam-1/content",
            headers=_bearer(student),
        )
        listed = client.get(
            "/assessment-attempts?course_id=course-1&mode=exam&completed=false",
            headers=_bearer(student),
        )
        cross_read = client.get(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(other),
        )
        cross_content_read = client.get(
            "/assessment-attempts/attempt-exam-1/content",
            headers=_bearer(other),
        )
        cross_write = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(other),
            json=revision_two_payload,
        )
        other_list = client.get("/assessment-attempts", headers=_bearer(other))
        free_text_rejected = client.put(
            "/assessment-attempts/attempt-extra",
            headers=_bearer(student),
            json=_payload() | {"deck": {"questions": ["texto bruto"]}},
        )
        identity_conflict = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=revision_two_payload | {
                "revision": 3,
                "topic": "Outro tópico",
                "updated_at": "2026-09-20T12:03:00Z",
            },
        )
        updated_at_conflict = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=revision_two_payload | {
                "revision": 3,
                "updated_at": "2026-09-20T11:00:00Z",
            },
        )
        completed_payload = revision_two_payload | {
            "revision": 3,
            "remaining_seconds": 0,
            "completed": True,
            "score": 0,
            "updated_at": "2026-09-20T12:03:00Z",
        }
        completed = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=completed_payload,
        )
        hydrated_completed = client.get(
            "/assessment-attempts/attempt-exam-1/content",
            headers=_bearer(student),
        )
        completed_edit = client.put(
            "/assessment-attempts/attempt-exam-1",
            headers=_bearer(student),
            json=completed_payload | {
                "revision": 4,
                "answers": {"0": 1, "1": 1},
                "updated_at": "2026-09-20T12:04:00Z",
            },
        )
        client_score_rejected = client.put(
            "/assessment-attempts/attempt-score-client",
            headers=_bearer(student),
            json=_payload() | {
                "remaining_seconds": 0,
                "completed": True,
                "score": 1,
            },
        )
        preview_after_completion = client.get(
            "/assessment-contents/content-exam-1",
            headers=_bearer(student),
        )
        deleted = client.delete("/auth/me", headers=_bearer(student))
        with Session(app.state.database.engine) as session:
            remaining_attempts = session.scalar(
                select(func.count()).select_from(AssessmentAttemptRecord)
            )
            remaining_contents = session.scalar(
                select(func.count()).select_from(AssessmentContentRecord)
            )

    assert content_created.status_code == 201
    assert content_created.json()["answer_key"] is None
    assert "correct_index" not in content_created.json()["questions"][0]
    assert content_retry.status_code == 200
    assert content_retry.json() == content_created.json()
    assert content_conflict.status_code == 409
    assert content_conflict.json()["detail"]["code"] == "assessment_content_immutable"
    assert content_cross_read.status_code == 404
    assert missing_content_reference.status_code == 422
    assert missing_content_reference.json()["detail"]["code"] == "assessment_content_required"
    assert invalid_answer_reference.status_code == 422
    assert created.status_code == 201 and created.json()["revision"] == 1
    assert created.json()["assessment_content_id"] == "content-exam-1"
    assert retry.status_code == 200 and retry.json() == created.json()
    assert divergent_retry.status_code == 409
    assert divergent_retry.json()["detail"]["code"] == "revision_conflict"
    assert updated.status_code == 200 and updated.json()["revision"] == 2
    assert update_retry.status_code == 200 and update_retry.json() == updated.json()
    assert stale.status_code == 409
    assert stale.json()["detail"]["current_revision"] == 2
    assert fetched.status_code == 200 and fetched.json()["answers"] == {"0": 2, "1": 1}
    assert hydrated_incomplete.status_code == 200
    assert len(hydrated_incomplete.json()["questions"]) == 3
    assert hydrated_incomplete.json()["answer_key"] is None
    assert listed.status_code == 200 and listed.json()["total"] == 1
    assert cross_read.status_code == cross_write.status_code == 404
    assert cross_content_read.status_code == 404
    assert other_list.status_code == 200 and other_list.json()["attempts"] == []
    assert free_text_rejected.status_code == 422
    assert identity_conflict.status_code == 409
    assert identity_conflict.json()["detail"]["code"] == "attempt_identity_conflict"
    assert updated_at_conflict.status_code == 409
    assert updated_at_conflict.json()["detail"]["code"] == "updated_at_conflict"
    assert completed.status_code == 200 and completed.json()["completed"] is True
    assert completed.json()["score"] == 1
    assert hydrated_completed.status_code == 200
    assert hydrated_completed.json()["answer_key"][0]["correct_index"] == 2
    assert completed_edit.status_code == 409
    assert completed_edit.json()["detail"]["code"] == "completed_attempt"
    assert client_score_rejected.status_code == 422
    assert preview_after_completion.json()["answer_key"] is None
    assert deleted.status_code == 204
    assert remaining_attempts == 0
    assert remaining_contents == 0


def test_attempt_requires_active_course_enrollment_and_timezone() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="j" * 32,
        cpf_pepper="p" * 32,
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        student = _register(client, "123.456.789-09", "Estudante")
        with Session(app.state.database.engine) as session:
            session.add(Course(id="course-1", title="Curso", author="TDS", content={"sections": []}, active=True))
            session.commit()
        no_enrollment = client.put(
            "/assessment-attempts/attempt-1",
            headers=_bearer(student),
            json=_payload(),
        )
        naive_timestamp = client.put(
            "/assessment-attempts/attempt-2",
            headers=_bearer(student),
            json=_payload() | {"updated_at": "2026-09-20T12:00:00"},
        )

    assert no_enrollment.status_code == 403
    assert naive_timestamp.status_code == 422
