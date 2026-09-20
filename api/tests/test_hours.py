from __future__ import annotations

from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    ClassEnrollment,
    Classroom,
    Course,
    Enrollment,
    Institution,
    LearningEventRecord,
    Program,
    ProgramCourse,
    ProgramMembership,
)

PASSWORD = "uma-senha-forte-2026"


def make_client() -> tuple[TestClient, object]:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def register(client: TestClient, cpf: str, name: str) -> dict[str, object]:
    response = client.post(
        "/auth/register",
        json={
            "name": name,
            "cpf": cpf,
            "phone": "61999990000",
            "password": PASSWORD,
        },
    )
    assert response.status_code == 201
    return response.json()


def bearer(account: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {account['access_token']}"}


def activity(event_id: str, occurred_at: str, active_seconds: int) -> dict[str, object]:
    return {
        "event_id": event_id,
        "event_type": "study_activity",
        "course_id": "course-1",
        "session_id": "study-session-1",
        "occurred_at": occurred_at,
        "active_seconds": active_seconds,
    }


def test_hours_count_interaction_without_double_counting_overlap() -> None:
    client, app = make_client()
    with client:
        student = register(client, "123.456.789-09", "Estudante")
        teacher = register(client, "987.654.321-00", "Professora")
        outsider = register(client, "529.982.247-25", "Outra Pessoa")
        student_id = student["user"]["id"]
        teacher_id = teacher["user"]["id"]
        with Session(app.state.database.engine) as session:
            session.add_all(
                [
                    Institution(id="institution-1", name="Instituto"),
                    Program(
                        id="program-1",
                        institution_id="institution-1",
                        name="Programa",
                    ),
                    Course(
                        id="course-1",
                        title="Curso",
                        author="TDS",
                        content={"sections": []},
                        active=True,
                    ),
                ]
            )
            session.flush()
            session.add(
                ProgramCourse(
                    program_id="program-1",
                    course_id="course-1",
                    planned_seconds=40 * 60 * 60,
                )
            )
            session.add_all(
                [
                    ProgramMembership(
                        user_id=student_id,
                        program_id="program-1",
                        role="student",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=teacher_id,
                        program_id="program-1",
                        role="teacher",
                        status="active",
                    ),
                ]
            )
            session.flush()
            session.add(
                Enrollment(
                    id="enrollment-1",
                    user_id=student_id,
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.flush()
            session.add(
                Classroom(
                    id="class-1",
                    program_id="program-1",
                    course_id="course-1",
                    teacher_id=teacher_id,
                    name="Turma A",
                    start_date=date(2026, 9, 1),
                    end_date=date(2026, 12, 1),
                    status="active",
                )
            )
            session.flush()
            session.add(
                ClassEnrollment(
                    class_id="class-1",
                    user_id=student_id,
                    enrollment_id="enrollment-1",
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.commit()

        first = client.post(
            "/events",
            json=activity("activity-1", "2026-09-20T12:01:00Z", 60),
            headers=bearer(student),
        )
        second = client.post(
            "/events",
            json=activity("activity-2", "2026-09-20T12:01:30Z", 60),
            headers=bearer(student),
        )
        self_hours = client.get(
            f"/users/{student_id}/hours?course_id=course-1",
            headers=bearer(student),
        )
        teacher_hours = client.get(
            f"/users/{student_id}/hours?course_id=course-1",
            headers=bearer(teacher),
        )
        forbidden = client.get(
            f"/users/{student_id}/hours?course_id=course-1",
            headers=bearer(outsider),
        )
        spoofed = client.post(
            "/events",
            json=activity("activity-3", "2026-09-20T12:02:00Z", 30)
            | {"validated_seconds": 999},
            headers=bearer(student),
        )

    assert first.status_code == 201
    assert first.json()["validated_seconds"] == 60
    assert second.status_code == 201
    assert second.json()["validated_seconds"] == 30
    assert self_hours.status_code == 200
    assert self_hours.json() == {
        "user_id": student_id,
        "program_id": "program-1",
        "course_id": "course-1",
        "planned_hours": 40.0,
        "validated_hours": 0.025,
        "active_usage": 0.0333,
    }
    assert teacher_hours.status_code == 200
    assert forbidden.status_code == 403
    assert spoofed.status_code == 422


def test_activity_before_enrollment_is_preserved_and_duration_is_bounded() -> None:
    client, app = make_client()
    with client:
        student = register(client, "123.456.789-09", "Estudante")
        missing_enrollment = client.post(
            "/events",
            json=activity("activity-1", "2026-09-20T12:01:00Z", 60),
            headers=bearer(student),
        )
        excessive = client.post(
            "/events",
            json=activity("activity-2", "2026-09-20T12:02:00Z", 61),
            headers=bearer(student),
        )
        with Session(app.state.database.engine) as session:
            stored = session.get(LearningEventRecord, "activity-1")
            assert stored is not None
            assert stored.enrollment_id is None
            assert stored.validated_seconds == 60

    assert missing_enrollment.status_code == 201
    assert excessive.status_code == 422
