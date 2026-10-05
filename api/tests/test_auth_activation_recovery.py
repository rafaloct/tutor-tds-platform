from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
import pytest
from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import Session

from app.auth import AuthService, RegisterRequest, password_hash
from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    CPFActivationToken,
    User,
)

AUTH_TEST_VALUE = "-".join(("uma", "senha", "forte", "2026"))
ADMIN_CPF = "987.654.321-00"
STUDENT_CPF = "123.456.789-09"
OTHER_CPF = "529.982.247-25"


def make_client(
    *,
    activation_required: bool = True,
    login_limit: int = 10,
) -> tuple[TestClient, object]:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        cpf_activation_required=activation_required,
        auth_rate_limit_window_seconds=900,
        auth_login_attempt_limit=login_limit,
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def seed_user(app: object, *, cpf: str, role: str, user_id: str) -> None:
    with Session(app.state.database.engine) as session:
        service = AuthService(session, app.state.settings)
        session.add(
            User(
                id=user_id,
                cpf_digest=service._cpf_digest(cpf),
                phone="61999990000",
                name=role.title(),
                password_digest=password_hash.hash(AUTH_TEST_VALUE),
                role=role,
                activated_at=datetime.now(timezone.utc),
            )
        )
        session.commit()


def login(client: TestClient, cpf: str) -> dict[str, str]:
    response = client.post(
        "/auth/login",
        json={"cpf": cpf, "password": AUTH_TEST_VALUE},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def payload(cpf: str = STUDENT_CPF, token: str | None = None) -> dict[str, str]:
    value = {
        "name": "Pessoa de Teste",
        "cpf": cpf,
        "phone": "61999990000",
        "password": AUTH_TEST_VALUE,
    }
    if token is not None:
        value["activation_token"] = token
    return value


def issue_invite(
    client: TestClient,
    admin_headers: dict[str, str],
    *,
    cpf: str = STUDENT_CPF,
) -> str:
    response = client.post(
        "/auth/activation-invites",
        headers=admin_headers,
        json={"cpf": cpf, "expires_in_hours": 24},
    )
    assert response.status_code == 201
    token = response.json()["activation_token"]
    assert isinstance(token, str) and token
    return token


def test_activation_invite_is_required_and_valid_for_matching_cpf() -> None:
    client, app = make_client()
    seed_user(app, cpf=ADMIN_CPF, role="admin", user_id="admin-1")
    with client:
        admin_headers = login(client, ADMIN_CPF)
        rejected = client.post("/auth/register", json=payload())
        token = issue_invite(client, admin_headers)
        accepted = client.post("/auth/register", json=payload(token=token))

        with Session(app.state.database.engine) as session:
            created = session.scalar(
                select(User).where(User.name == "Pessoa de Teste")
            )
            activation = session.scalar(
                select(CPFActivationToken).where(
                    CPFActivationToken.used_at.is_not(None)
                )
            )
            assert created is not None and created.activated_at is not None
            assert activation is not None

    assert rejected.status_code == 403
    assert accepted.status_code == 201
    assert token not in accepted.text


def test_activation_invite_is_one_time_even_if_created_user_is_removed() -> None:
    client, app = make_client()
    seed_user(app, cpf=ADMIN_CPF, role="admin", user_id="admin-1")
    with client:
        token = issue_invite(client, login(client, ADMIN_CPF))
        with Session(app.state.database.engine) as session:
            service = AuthService(session, app.state.settings)
            first = service.register(RegisterRequest(**payload(token=token)))
            session.commit()
            session.delete(first)
            session.commit()
            with pytest.raises(HTTPException) as exc:
                service.register(RegisterRequest(**payload(token=token)))
            assert exc.value.status_code == 403


def test_activation_invite_rejects_wrong_cpf_and_expired_token() -> None:
    client, app = make_client()
    seed_user(app, cpf=ADMIN_CPF, role="admin", user_id="admin-1")
    with client:
        headers = login(client, ADMIN_CPF)
        wrong_cpf_token = issue_invite(client, headers, cpf=STUDENT_CPF)
        wrong_cpf = client.post(
            "/auth/register",
            json=payload(cpf=OTHER_CPF, token=wrong_cpf_token),
        )
        expired_token = issue_invite(client, headers, cpf=OTHER_CPF)
        with Session(app.state.database.engine) as session:
            service = AuthService(session, app.state.settings)
            digest = __import__("hashlib").sha256(expired_token.encode()).hexdigest()
            record = session.scalar(
                select(CPFActivationToken).where(
                    CPFActivationToken.token_digest == digest
                )
            )
            assert record is not None
            record.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
            session.commit()
        expired = client.post(
            "/auth/register",
            json=payload(cpf=OTHER_CPF, token=expired_token),
        )

    assert wrong_cpf.status_code == 403
    assert expired.status_code == 403


def test_activation_invite_issuance_requires_admin_role() -> None:
    client, app = make_client()
    seed_user(app, cpf=ADMIN_CPF, role="admin", user_id="admin-1")
    seed_user(app, cpf=STUDENT_CPF, role="student", user_id="student-1")
    with client:
        student_headers = login(client, STUDENT_CPF)
        student_attempt = client.post(
            "/auth/activation-invites",
            headers=student_headers,
            json={"cpf": OTHER_CPF, "expires_in_hours": 24},
        )
        admin_attempt = client.post(
            "/auth/activation-invites",
            headers=login(client, ADMIN_CPF),
            json={"cpf": OTHER_CPF, "expires_in_hours": 24},
        )

    assert student_attempt.status_code == 403
    assert admin_attempt.status_code == 201


def test_login_uses_shared_database_rate_limit() -> None:
    client, _ = make_client(activation_required=False, login_limit=2)
    with client:
        created = client.post("/auth/register", json=payload())
        first = client.post(
            "/auth/login",
            json={"cpf": STUDENT_CPF, "password": "senha-errada-0001"},
        )
        second = client.post(
            "/auth/login",
            json={"cpf": STUDENT_CPF, "password": "senha-errada-0002"},
        )
        limited = client.post(
            "/auth/login",
            json={"cpf": STUDENT_CPF, "password": AUTH_TEST_VALUE},
        )

    assert created.status_code == 201
    assert first.status_code == 401
    assert second.status_code == 401
    assert limited.status_code == 429
    assert int(limited.headers["Retry-After"]) >= 1


def test_openapi_exposes_activation_invites_and_registration_token() -> None:
    client, _ = make_client()
    with client:
        schema = client.get("/openapi.json").json()

    assert "/auth/activation-invites" in schema["paths"]
    register_schema = schema["components"]["schemas"]["RegisterRequest"]
    assert "activation_token" in register_schema["properties"]


def test_migrations_0025_0026_activate_legacy_users_and_create_rate_bucket(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "auth-recovery.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    engine = create_engine(database_url)

    command.upgrade(config, "20261003_0024")
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO users "
                "(id, cpf_digest, phone, name, password_digest, role) "
                "VALUES ('legacy-user', :cpf, '61999990000', 'Legacy', "
                "'digest', 'student')"
            ),
            {"cpf": "a" * 64},
        )

    command.upgrade(config, "20261003_0025")
    columns = {column["name"] for column in inspect(engine).get_columns("users")}
    assert "activated_at" in columns
    with engine.connect() as connection:
        assert connection.execute(
            text("SELECT activated_at FROM users WHERE id='legacy-user'")
        ).scalar_one() is not None

    command.upgrade(config, "20261003_0026")
    assert "cpf_activation_tokens" in inspect(engine).get_table_names()
    assert "auth_rate_limit_buckets" in inspect(engine).get_table_names()
    with engine.connect() as connection:
        assert (
            connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
            == "20261003_0026"
        )
    engine.dispose()
