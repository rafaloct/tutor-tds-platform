from __future__ import annotations

from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.bootstrap_admin import ensure_admin
from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    Course,
    Enrollment,
    LearningEventRecord,
    ProgramCourse,
    ProgramMembership,
    User,
)

PASSWORD = "uma-senha-forte-2026"
CPF_ADMIN = "123.456.789-09"
CPF_STUDENT = "987.654.321-00"


def make_client() -> tuple[TestClient, object, Settings]:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app, settings


def register(client: TestClient, *, cpf: str, name: str) -> dict[str, object]:
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


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_admin_builds_and_reads_complete_program_hierarchy() -> None:
    client, app, _ = make_client()
    with client:
        register(client, cpf=CPF_ADMIN, name="Administradora")
        student = register(client, cpf=CPF_STUDENT, name="Estudante")
        with Session(app.state.database.engine) as session:
            admin = session.scalar(select(User).where(User.name == "Administradora"))
            assert admin is not None
            admin.role = "admin"
            session.add(
                Course(
                    id="course-1",
                    title="Curso Um",
                    author="TDS",
                    content={"sections": []},
                    active=True,
                )
            )
            session.add(
                LearningEventRecord(
                    event_id="activity-before-enrollment",
                    user_id=student["user"]["id"],
                    enrollment_id=None,
                    course_id="course-1",
                    event_type="study_activity",
                    session_id="session-1",
                    occurred_at=datetime(2026, 9, 20, 12, tzinfo=timezone.utc),
                    payload={},
                    active_seconds=30,
                    validated_seconds=30,
                    sync_status="pending",
                )
            )
            session.commit()
        login = client.post(
            "/auth/login",
            json={"cpf": CPF_ADMIN, "password": PASSWORD},
        )
        headers = bearer(login.json()["access_token"])

        institution = client.post(
            "/admin/institutions",
            json={"name": "Instituto Parceiro"},
            headers=headers,
        )
        program = client.post(
            "/admin/programs",
            json={
                "institution_id": institution.json()["id"],
                "name": "Programa TDS 2026",
            },
            headers=headers,
        )
        program_id = program.json()["id"]
        offered = client.post(
            f"/admin/programs/{program_id}/courses/course-1",
            headers=headers,
        )
        workload = client.put(
            f"/admin/programs/{program_id}/courses/course-1/workload",
            json={"planned_hours": 36.5},
            headers=headers,
        )
        membership = client.post(
            f"/admin/programs/{program_id}/memberships",
            json={"user_id": student["user"]["id"], "role": "student"},
            headers=headers,
        )
        enrollment = client.post(
            "/admin/enrollments",
            json={
                "user_id": student["user"]["id"],
                "program_id": program_id,
                "course_id": "course-1",
            },
            headers=headers,
        )
        duplicate = client.post(
            "/admin/enrollments",
            json={
                "user_id": student["user"]["id"],
                "program_id": program_id,
                "course_id": "course-1",
            },
            headers=headers,
        )
        hierarchy = client.get("/admin/hierarchy", headers=headers)
        with Session(app.state.database.engine) as session:
            course_link_count = session.scalar(
                select(func.count()).select_from(ProgramCourse)
            )
            membership_count = session.scalar(
                select(func.count()).select_from(ProgramMembership)
            )
            enrollment_count = session.scalar(
                select(func.count()).select_from(Enrollment)
            )
            reconciled_event = session.get(
                LearningEventRecord, "activity-before-enrollment"
            )

    assert institution.status_code == 201
    assert program.status_code == 201
    assert offered.status_code == 201
    assert workload.status_code == 200
    assert workload.json()["planned_hours"] == 36.5
    assert membership.status_code == 201
    assert enrollment.status_code == 201
    assert duplicate.status_code == 409
    assert hierarchy.status_code == 200
    tree = hierarchy.json()
    assert tree[0]["programs"][0]["course_ids"] == ["course-1"]
    assert tree[0]["programs"][0]["memberships"][0] == {
        "user_id": student["user"]["id"],
        "role": "student",
        "program_id": program_id,
        "status": "active",
    }

    assert course_link_count == 1
    assert membership_count == 1
    assert enrollment_count == 1
    assert reconciled_event is not None
    assert reconciled_event.enrollment_id == enrollment.json()["id"]


def test_student_cannot_manage_hierarchy() -> None:
    client, _, _ = make_client()
    with client:
        student = register(client, cpf=CPF_STUDENT, name="Estudante")
        response = client.post(
            "/admin/institutions",
            json={"name": "Instituto Indevido"},
            headers=bearer(student["access_token"]),
        )
    assert response.status_code == 403


def test_admin_creates_role_account_and_program_membership_atomically() -> None:
    client, app, _ = make_client()
    with client:
        register(client, cpf=CPF_ADMIN, name="Administradora")
        with Session(app.state.database.engine) as session:
            admin = session.scalar(select(User).where(User.name == "Administradora"))
            assert admin is not None
            admin.role = "admin"
            session.commit()
        admin_login = client.post(
            "/auth/login", json={"cpf": CPF_ADMIN, "password": PASSWORD}
        )
        headers = bearer(admin_login.json()["access_token"])
        institution = client.post(
            "/admin/institutions", json={"name": "Instituto"}, headers=headers
        )
        program = client.post(
            "/admin/programs",
            json={"institution_id": institution.json()["id"], "name": "Programa"},
            headers=headers,
        )
        response = client.post(
            "/admin/accounts",
            json={
                "name": "Professora TDS",
                "cpf": "111.444.777-35",
                "phone": "61999990001",
                "password": PASSWORD,
                "role": "teacher",
                "program_id": program.json()["id"],
            },
            headers=headers,
        )
        with Session(app.state.database.engine) as session:
            created = session.get(User, response.json()["id"])
            membership = session.get(
                ProgramMembership, (response.json()["id"], program.json()["id"])
            )
    assert response.status_code == 201
    assert response.json()["role"] == "teacher"
    assert created is not None and created.role == "teacher"
    assert membership is not None and membership.role == "teacher"


def test_admin_provisions_program_operator_through_canonical_control_plane() -> None:
    client, app, _ = make_client()
    with client:
        register(client, cpf=CPF_ADMIN, name="Administradora")
        operator = register(
            client,
            cpf="529.982.247-25",
            name="Operadora de Programa",
        )
        with Session(app.state.database.engine) as session:
            admin = session.scalar(select(User).where(User.name == "Administradora"))
            assert admin is not None
            admin.role = "admin"
            session.commit()

        login = client.post(
            "/auth/login",
            json={"cpf": CPF_ADMIN, "password": PASSWORD},
        )
        headers = bearer(login.json()["access_token"])
        institution = client.post(
            "/admin/institutions",
            json={"name": "Instituto Operação"},
            headers=headers,
        )
        program = client.post(
            "/admin/programs",
            json={
                "institution_id": institution.json()["id"],
                "name": "Programa Operacional",
            },
            headers=headers,
        )
        program_id = program.json()["id"]

        membership = client.post(
            f"/admin/programs/{program_id}/memberships",
            json={
                "user_id": operator["user"]["id"],
                "role": "program_operator",
            },
            headers=headers,
        )
        hierarchy = client.get(
            "/admin/hierarchy",
            params={"institution_id": institution.json()["id"]},
            headers=headers,
        )
        openapi = client.get("/openapi.json").json()

        with Session(app.state.database.engine) as session:
            persisted = session.get(
                ProgramMembership,
                (operator["user"]["id"], program_id),
            )

    assert membership.status_code == 201
    assert membership.json()["role"] == "program_operator"
    assert persisted is not None
    assert persisted.role == "program_operator"
    assert hierarchy.status_code == 200
    assert hierarchy.json()[0]["programs"][0]["memberships"] == [
        {
            "user_id": operator["user"]["id"],
            "program_id": program_id,
            "role": "program_operator",
            "status": "active",
        }
    ]
    schemas = openapi["components"]["schemas"]
    assert "program_operator" in schemas["MembershipCreate"]["properties"]["role"]["enum"]
    assert "program_operator" in schemas["ManagedAccountCreate"]["properties"]["role"]["enum"]


def test_admin_managed_account_accepts_program_operator_consistently() -> None:
    client, app, _ = make_client()
    with client:
        register(client, cpf=CPF_ADMIN, name="Administradora")
        with Session(app.state.database.engine) as session:
            admin = session.scalar(select(User).where(User.name == "Administradora"))
            assert admin is not None
            admin.role = "admin"
            session.commit()

        login = client.post(
            "/auth/login",
            json={"cpf": CPF_ADMIN, "password": PASSWORD},
        )
        headers = bearer(login.json()["access_token"])
        institution = client.post(
            "/admin/institutions",
            json={"name": "Instituto Conta"},
            headers=headers,
        )
        program = client.post(
            "/admin/programs",
            json={
                "institution_id": institution.json()["id"],
                "name": "Programa Conta",
            },
            headers=headers,
        )
        response = client.post(
            "/admin/accounts",
            json={
                "name": "Operadora Gerenciada",
                "cpf": "168.995.350-09",
                "phone": "61999990002",
                "password": PASSWORD,
                "role": "program_operator",
                "program_id": program.json()["id"],
            },
            headers=headers,
        )

        with Session(app.state.database.engine) as session:
            created = session.get(User, response.json()["id"])
            membership = session.get(
                ProgramMembership,
                (response.json()["id"], program.json()["id"]),
            )

    assert response.status_code == 201
    assert response.json()["role"] == "program_operator"
    assert created is not None and created.role == "program_operator"
    assert membership is not None and membership.role == "program_operator"


def test_bootstrap_admin_is_rerunnable_without_duplicate_user() -> None:
    _, app, settings = make_client()
    with Session(app.state.database.engine) as session:
        first_id = ensure_admin(
            session,
            settings,
            name="Administradora",
            phone="61999990000",
            cpf=CPF_ADMIN,
            password=PASSWORD,
        )
    with Session(app.state.database.engine) as session:
        second_id = ensure_admin(
            session,
            settings,
            name="Administradora",
            phone="61999990000",
            cpf=CPF_ADMIN,
            password=PASSWORD,
        )
        user = session.get(User, first_id)
        count = session.scalar(select(func.count()).select_from(User))

    assert first_id == second_id
    assert count == 1
    assert user is not None
    assert user.role == "admin"
