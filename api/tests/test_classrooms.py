from __future__ import annotations

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
    User,
)

PASSWORD = "uma-senha-forte-2026"
CPFS = {
    "admin": "123.456.789-09",
    "teacher": "987.654.321-00",
    "monitor": "529.982.247-25",
    "student": "168.995.350-09",
    "outsider": "111.444.777-35",
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


def bearer(token: object) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_classroom_preserves_teacher_monitor_student_hierarchy() -> None:
    client, app = make_client()
    with client:
        accounts = {role: register(client, role) for role in CPFS}
        ids = {
            role: account["user"]["id"]
            for role, account in accounts.items()
        }
        with Session(app.state.database.engine) as session:
            admin = session.get(User, ids["admin"])
            assert admin is not None
            admin.role = "admin"
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
                        user_id=ids["teacher"],
                        program_id="program-1",
                        role="teacher",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=ids["monitor"],
                        program_id="program-1",
                        role="monitor",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=ids["student"],
                        program_id="program-1",
                        role="student",
                        status="active",
                    ),
                ]
            )
            session.flush()
            session.add(
                Enrollment(
                    id="enrollment-1",
                    user_id=ids["student"],
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.commit()

        admin_login = client.post(
            "/auth/login",
            json={"cpf": CPFS["admin"], "password": PASSWORD},
        ).json()
        admin_headers = bearer(admin_login["access_token"])
        payload = {
            "program_id": "program-1",
            "course_id": "course-1",
            "teacher_id": ids["teacher"],
            "name": "Turma A",
            "start_date": "2026-10-01",
            "end_date": "2026-12-01",
            "status": "planned",
        }
        created = client.post("/admin/classes", json=payload, headers=admin_headers)
        class_id = created.json()["id"]
        student_added = client.post(
            f"/admin/classes/{class_id}/students/{ids['student']}",
            headers=admin_headers,
        )
        monitor_added = client.post(
            f"/admin/classes/{class_id}/monitors/{ids['monitor']}",
            headers=admin_headers,
        )
        duplicate_student = client.post(
            f"/admin/classes/{class_id}/students/{ids['student']}",
            headers=admin_headers,
        )
        outsider_added = client.post(
            f"/admin/classes/{class_id}/students/{ids['outsider']}",
            headers=admin_headers,
        )

        teacher_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["teacher"]["access_token"]),
        )
        monitor_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["monitor"]["access_token"]),
        )
        student_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["student"]["access_token"]),
        )

        invalid_teacher = client.post(
            "/admin/classes",
            json=payload | {"teacher_id": ids["student"], "name": "Inválida"},
            headers=admin_headers,
        )
        invalid_dates = client.post(
            "/admin/classes",
            json=payload | {"start_date": "2026-12-02", "end_date": "2026-12-01"},
            headers=admin_headers,
        )

    assert created.status_code == 201
    assert student_added.status_code == 201
    assert monitor_added.status_code == 201
    assert duplicate_student.status_code == 409
    assert outsider_added.status_code == 422
    assert teacher_view.status_code == 200
    assert monitor_view.status_code == 200
    assert teacher_view.json()["student_ids"] == [ids["student"]]
    assert teacher_view.json()["monitor_ids"] == [ids["monitor"]]
    assert student_view.status_code == 403
    assert invalid_teacher.status_code == 422
    assert invalid_dates.status_code == 422
