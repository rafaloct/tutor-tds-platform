from __future__ import annotations

from datetime import date, datetime, timezone

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
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)

PASSWORD = "uma-senha-forte-2026"
CPFS = {
    "student": "123.456.789-09",
    "teacher": "987.654.321-00",
    "outsider": "529.982.247-25",
}


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


def register(client: TestClient, role: str) -> dict[str, object]:
    response = client.post(
        "/auth/register",
        json={
            "name": role.title(),
            "cpf": CPFS[role],
            "phone": "61999990000",
            "password": PASSWORD,
        },
    )
    assert response.status_code == 201
    return response.json()


def login(client: TestClient, role: str) -> str:
    response = client.post(
        "/auth/login",
        json={"cpf": CPFS[role], "password": PASSWORD},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def bearer(token: object) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def telemetry(event_id: str, event_type: str, key: str, target: str) -> dict[str, object]:
    return {
        "event_id": event_id,
        "event_type": event_type,
        "course_id": "course-1",
        "session_id": "app-session-1",
        "occurred_at": datetime.now(timezone.utc).isoformat(),
        "payload": {key: target},
    }


def test_usage_analytics_respects_student_and_classroom_hierarchy() -> None:
    client, app = make_client()
    with client:
        accounts = {role: register(client, role) for role in CPFS}
        ids = {role: account["user"]["id"] for role, account in accounts.items()}
        with Session(app.state.database.engine) as session:
            teacher = session.get(User, ids["teacher"])
            outsider = session.get(User, ids["outsider"])
            assert teacher is not None and outsider is not None
            teacher.role = "teacher"
            outsider.role = "teacher"
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
            session.add(ProgramCourse(program_id="program-1", course_id="course-1"))
            session.add_all(
                [
                    ProgramMembership(
                        user_id=ids["student"],
                        program_id="program-1",
                        role="student",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=ids["teacher"],
                        program_id="program-1",
                        role="teacher",
                        status="active",
                    ),
                ]
            )
            session.flush()
            enrollment = Enrollment(
                id="enrollment-1",
                user_id=ids["student"],
                program_id="program-1",
                course_id="course-1",
                status="active",
            )
            classroom = Classroom(
                id="class-1",
                program_id="program-1",
                course_id="course-1",
                teacher_id=ids["teacher"],
                name="Turma A",
                start_date=date(2026, 9, 1),
                end_date=date(2026, 12, 1),
                status="active",
            )
            session.add_all([enrollment, classroom])
            session.flush()
            session.add(
                ClassEnrollment(
                    class_id="class-1",
                    user_id=ids["student"],
                    enrollment_id="enrollment-1",
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.commit()

        student_headers = bearer(accounts["student"]["access_token"])
        events = [
            telemetry("page-1", "page_viewed", "page_id", "study_hub"),
            telemetry("page-2", "page_viewed", "page_id", "study_hub"),
            telemetry("resource-1", "resource_opened", "resource_id", "ai_quiz"),
        ]
        created = [
            client.post("/events", json=event, headers=student_headers)
            for event in events
        ]
        student_summary = client.get("/analytics/usage", headers=student_headers)
        forbidden_student = client.get(
            f"/analytics/usage?user_id={ids['teacher']}",
            headers=student_headers,
        )
        teacher_headers = bearer(login(client, "teacher"))
        teacher_summary = client.get(
            "/analytics/usage?class_id=class-1", headers=teacher_headers
        )
        missing_scope = client.get("/analytics/usage", headers=teacher_headers)
        outsider_summary = client.get(
            "/analytics/usage?class_id=class-1",
            headers=bearer(login(client, "outsider")),
        )

    assert all(response.status_code == 201 for response in created)
    assert student_summary.status_code == 200
    assert teacher_summary.status_code == 200
    assert student_summary.json()["items"] == teacher_summary.json()["items"]
    assert student_summary.json()["items"] == [
        {
            "course_id": "course-1",
            "event_type": "page_viewed",
            "target_id": "study_hub",
            "count": 2,
            "unique_users": 1,
            "last_occurred_at": student_summary.json()["items"][0]["last_occurred_at"],
        },
        {
            "course_id": "course-1",
            "event_type": "resource_opened",
            "target_id": "ai_quiz",
            "count": 1,
            "unique_users": 1,
            "last_occurred_at": student_summary.json()["items"][1]["last_occurred_at"],
        },
    ]
    assert forbidden_student.status_code == 403
    assert missing_scope.status_code == 422
    assert outsider_summary.status_code == 403
