from __future__ import annotations

from datetime import date

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import AuthService
from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    Classroom,
    Course,
    CourseVersion,
    CourseVersionTransition,
    Institution,
    LearningEventRecord,
    Program,
    ProgramCourse,
    ProgramMembership,
    SessionToken,
    User,
)

CPF = "123.456.789-09"
PASSWORD = "uma-senha-forte-2026"


def make_client(
    *,
    access_minutes: int = 15,
    operator_operations_enabled: bool = False,
) -> tuple[TestClient, object]:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        access_token_minutes=access_minutes,
        refresh_token_days=30,
        operator_operations_enabled=operator_operations_enabled,
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def registration_payload() -> dict[str, str]:
    return {
        "name": "Pessoa de Teste",
        "cpf": CPF,
        "phone": "(61) 99999-0000",
        "password": PASSWORD,
    }


def test_register_protects_credentials_and_stores_digests() -> None:
    client, app = make_client()
    with client:
        response = client.post("/auth/register", json=registration_payload())

        with Session(app.state.database.engine) as session:
            user = session.scalar(select(User))
            stored_session = session.scalar(select(SessionToken))
            assert user is not None
            assert user.cpf_digest not in {CPF, "12345678909"}
            assert user.password_digest.startswith("$argon2id$")
            assert stored_session is not None
            assert stored_session.refresh_token_digest != response.json()[
                "refresh_token"
            ]

    assert response.status_code == 201
    body = response.json()
    serialized = response.text
    assert CPF not in serialized
    assert "12345678909" not in serialized
    assert PASSWORD not in serialized
    assert body["user"]["role"] == "student"
    assert body["token_type"] == "bearer"


def test_register_rejects_invalid_and_duplicate_cpf_without_echoing_it() -> None:
    client, _ = make_client()
    invalid = registration_payload() | {"cpf": "111.111.111-11"}
    with client:
        rejected = client.post("/auth/register", json=invalid)
        created = client.post("/auth/register", json=registration_payload())
        duplicate = client.post("/auth/register", json=registration_payload())

    assert rejected.status_code == 422
    assert invalid["cpf"] not in rejected.text
    assert created.status_code == 201
    assert duplicate.status_code == 409
    assert CPF not in duplicate.text


def test_login_returns_tokens_and_uses_generic_error_for_wrong_password() -> None:
    client, _ = make_client()
    with client:
        client.post("/auth/register", json=registration_payload())
        response = client.post(
            "/auth/login", json={"cpf": CPF, "password": PASSWORD}
        )
        rejected = client.post(
            "/auth/login", json={"cpf": CPF, "password": "senha-incorreta"}
        )

    assert response.status_code == 200
    assert response.json()["access_token"]
    assert response.json()["refresh_token"]
    assert rejected.status_code == 401
    assert rejected.json()["detail"] == "Credenciais inválidas."
    assert CPF not in rejected.text


def test_refresh_rotates_token_and_rejects_reuse() -> None:
    client, _ = make_client()
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        first = registered["refresh_token"]
        rotated = client.post("/auth/refresh", json={"refresh_token": first})
        reused = client.post("/auth/refresh", json={"refresh_token": first})

    assert rotated.status_code == 200
    assert rotated.json()["refresh_token"] != first
    assert reused.status_code == 401
    assert first not in reused.text


def test_expired_access_token_is_rejected() -> None:
    client, _ = make_client(access_minutes=-1)
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        response = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {registered['access_token']}"},
        )

    assert response.status_code == 401
    assert response.json()["detail"] == "Token inválido ou expirado."


def test_valid_access_token_returns_only_public_user_fields() -> None:
    client, _ = make_client()
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        response = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {registered['access_token']}"},
        )

    assert response.status_code == 200
    assert set(response.json()) == {"id", "name", "role"}
    assert CPF not in response.text


@pytest.mark.parametrize(
    "role",
    ["student", "teacher", "monitor", "program_operator", "coordinator", "admin"],
)
def test_decode_access_and_access_claims_accept_only_supported_roles(role: str) -> None:
    client, app = make_client()
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        user_id = registered["user"]["id"]
        with Session(app.state.database.engine) as session:
            user = session.get(User, user_id)
            assert user is not None
            user.role = role
            session.commit()

        logged_in = client.post(
            "/auth/login",
            json={"cpf": CPF, "password": PASSWORD},
        )
        assert logged_in.status_code == 200
        token = logged_in.json()["access_token"]

        with Session(app.state.database.engine) as session:
            claims = AuthService(session, app.state.settings).decode_access(token)
        assert claims["sub"] == user_id
        assert claims["role"] == role
        assert claims["type"] == "access"

        me = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert me.status_code == 200
    assert me.json()["role"] == role


def test_decode_access_rejects_unknown_role_fail_closed() -> None:
    client, app = make_client()
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        user_id = registered["user"]["id"]
        with Session(app.state.database.engine) as session:
            user = session.get(User, user_id)
            assert user is not None
            user.role = "unexpected_role"
            session.commit()

        logged_in = client.post(
            "/auth/login",
            json={"cpf": CPF, "password": PASSWORD},
        )
        assert logged_in.status_code == 200
        token = logged_in.json()["access_token"]

        with Session(app.state.database.engine) as session:
            service = AuthService(session, app.state.settings)
            with pytest.raises(HTTPException) as rejected:
                service.decode_access(token)
        denied = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert rejected.value.status_code == 401
    assert denied.status_code == 401


def test_program_operator_remains_scoped_and_is_not_global_admin() -> None:
    client, app = make_client(operator_operations_enabled=True)
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        operator_id = registered["user"]["id"]

        with Session(app.state.database.engine) as session:
            operator = session.get(User, operator_id)
            assert operator is not None
            operator.role = "program_operator"
            session.add_all(
                [
                    Institution(id="i1", name="Instituição 1"),
                    Institution(id="i2", name="Instituição 2"),
                    User(
                        id="teacher-1",
                        cpf_digest="1" * 64,
                        phone="61999990001",
                        name="Teacher 1",
                        password_digest="not-used",
                        role="teacher",
                    ),
                    User(
                        id="teacher-2",
                        cpf_digest="2" * 64,
                        phone="61999990002",
                        name="Teacher 2",
                        password_digest="not-used",
                        role="teacher",
                    ),
                    Course(
                        id="course",
                        title="Curso",
                        author="TDS",
                        content={"sections": []},
                        active=True,
                    ),
                ]
            )
            session.flush()
            session.add_all(
                [
                    Program(id="p1", institution_id="i1", name="Programa 1"),
                    Program(id="p2", institution_id="i2", name="Programa 2"),
                ]
            )
            session.flush()
            session.add_all(
                [
                    ProgramCourse(program_id="p1", course_id="course"),
                    ProgramCourse(program_id="p2", course_id="course"),
                    ProgramMembership(
                        user_id="teacher-1",
                        program_id="p1",
                        role="teacher",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id="teacher-2",
                        program_id="p2",
                        role="teacher",
                        status="active",
                    ),
                    CourseVersion(
                        id="version-1",
                        course_id="course",
                        version_number=1,
                        revision=1,
                        status="published",
                        content={"sections": []},
                    ),
                ]
            )
            session.flush()
            session.add_all(
                [
                    Classroom(
                        id="class-p1",
                        program_id="p1",
                        course_id="course",
                        course_version_id="version-1",
                        teacher_id="teacher-1",
                        name="Turma P1",
                        start_date=date(2026, 1, 1),
                        end_date=date(2026, 12, 31),
                        status="active",
                    ),
                    Classroom(
                        id="class-p2",
                        program_id="p2",
                        course_id="course",
                        course_version_id="version-1",
                        teacher_id="teacher-2",
                        name="Turma P2",
                        start_date=date(2026, 1, 1),
                        end_date=date(2026, 12, 31),
                        status="active",
                    ),
                ]
            )
            session.commit()

        logged_in = client.post(
            "/auth/login",
            json={"cpf": CPF, "password": PASSWORD},
        )
        assert logged_in.status_code == 200
        token = logged_in.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # A JWT role is valid, but it does not grant global admin or program scope.
        assert client.get("/auth/me", headers=headers).status_code == 200
        assert client.get("/admin/hierarchy", headers=headers).status_code == 403
        assert client.get("/operations/scopes", headers=headers).json() == {"scopes": []}
        assert (
            client.post(
                "/operations/class-p1/search",
                headers=headers,
                json={"query": "Teacher"},
            ).status_code
            == 403
        )

        with Session(app.state.database.engine) as session:
            session.add(
                ProgramMembership(
                    user_id=operator_id,
                    program_id="p1",
                    role="program_operator",
                    status="active",
                )
            )
            session.commit()

        scopes = client.get("/operations/scopes", headers=headers)
        in_scope = client.post(
            "/operations/class-p1/search",
            headers=headers,
            json={"query": "Teacher"},
        )
        out_of_scope = client.post(
            "/operations/class-p2/search",
            headers=headers,
            json={"query": "Teacher"},
        )

    assert scopes.status_code == 200
    assert [item["class_id"] for item in scopes.json()["scopes"]] == ["class-p1"]
    assert in_scope.status_code == 200
    assert out_of_scope.status_code == 403


def test_student_can_delete_account_events_sessions_and_revoke_access() -> None:
    client, app = make_client()
    with client:
        registered = client.post("/auth/register", json=registration_payload()).json()
        headers = {"Authorization": f"Bearer {registered['access_token']}"}
        created_event = client.post(
            "/events",
            headers=headers,
            json={
                "event_id": "delete-account:page-viewed",
                "event_type": "page_viewed",
                "course_id": "_app",
                "session_id": "delete-account",
                "occurred_at": "2026-09-20T12:00:00Z",
                "payload": {"page_id": "settings"},
            },
        )
        with Session(app.state.database.engine) as session:
            user_id = registered["user"]["id"]
            session.add(Course(id="former-creator-course", title="Histórico", author="TDS", content={"sections": []}, active=False))
            session.flush()
            session.add(CourseVersion(id="former-version", course_id="former-creator-course", creator_user_id=user_id, version_number=1, revision=1, status="archived", content={"sections": []}))
            session.flush()
            session.add(CourseVersionTransition(id="former-transition", version_id="former-version", to_status="archived", actor_user_id=user_id, actor_role="creator"))
            session.commit()
        deleted = client.delete("/auth/me", headers=headers)
        access_after_delete = client.get("/auth/me", headers=headers)
        refresh_after_delete = client.post(
            "/auth/refresh",
            json={"refresh_token": registered["refresh_token"]},
        )

        with Session(app.state.database.engine) as session:
            assert session.scalar(select(func.count()).select_from(User)) == 0
            assert session.scalar(select(func.count()).select_from(SessionToken)) == 0
            assert session.get(CourseVersion, "former-version").creator_user_id is None
            assert session.get(CourseVersionTransition, "former-transition").actor_user_id is None
            assert (
                session.scalar(select(func.count()).select_from(LearningEventRecord))
                == 0
            )

    assert created_event.status_code == 201
    assert deleted.status_code == 204
    assert deleted.content == b""
    assert access_after_delete.status_code == 401
    assert refresh_after_delete.status_code == 401


def test_application_refuses_to_start_without_auth_secrets() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)

    with pytest.raises(RuntimeError, match="JWT_SECRET"):
        with TestClient(app):
            pass


def test_validation_errors_do_not_echo_sensitive_input() -> None:
    client, _ = make_client()
    marker = "sensitive-value-must-not-return"
    with client:
        response = client.post(
            "/auth/register",
            json={
                "name": "Pessoa de Teste",
                "cpf": {"invalid": marker},
                "phone": "61999990000",
                "password": {"invalid": marker},
            },
        )

    assert response.status_code == 422
    assert marker not in response.text
    assert "input" not in response.text
