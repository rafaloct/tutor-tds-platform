from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import Base, LearningEventRecord, User

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


def token_for(client: TestClient, *, cpf: str, name: str) -> str:
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
    return response.json()["access_token"]


def event_payload(
    *, event_id: str = "session-1:lesson_started", course_id: str = "course-1"
) -> dict[str, str]:
    return {
        "event_id": event_id,
        "event_type": "lesson_started",
        "course_id": course_id,
        "session_id": "session-1",
        "occurred_at": "2026-09-20T12:00:00Z",
    }


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_event_requires_access_token() -> None:
    client, _ = make_client()
    with client:
        response = client.post("/events", json=event_payload())
    assert response.status_code == 401


def test_event_uses_authenticated_user_and_is_idempotent() -> None:
    client, app = make_client()
    with client:
        token = token_for(client, cpf="123.456.789-09", name="Estudante Um")
        created = client.post("/events", json=event_payload(), headers=bearer(token))
        retried = client.post("/events", json=event_payload(), headers=bearer(token))

        with Session(app.state.database.engine) as session:
            assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 1
            record = session.scalar(select(LearningEventRecord))
            user = session.scalar(select(User).where(User.name == "Estudante Um"))
            assert record is not None
            assert user is not None
            assert record.user_id == user.id

    assert created.status_code == 201
    assert retried.status_code == 200
    assert "user_id" not in created.json()
    assert created.json()["sync_status"] == "pending"


def test_event_id_collision_between_users_is_rejected() -> None:
    client, _ = make_client()
    with client:
        first = token_for(client, cpf="123.456.789-09", name="Estudante Um")
        second = token_for(client, cpf="987.654.321-00", name="Estudante Dois")
        created = client.post("/events", json=event_payload(), headers=bearer(first))
        collision = client.post("/events", json=event_payload(), headers=bearer(second))

    assert created.status_code == 201
    assert collision.status_code == 409


def test_event_validation_rejects_unknown_type_and_client_user_id() -> None:
    client, _ = make_client()
    with client:
        token = token_for(client, cpf="123.456.789-09", name="Estudante Um")
        invalid_type = client.post(
            "/events",
            json=event_payload() | {"event_type": "unknown-sensitive-value"},
            headers=bearer(token),
        )
        injected_user = client.post(
            "/events",
            json=event_payload(event_id="second") | {"user_id": "attacker"},
            headers=bearer(token),
        )

    assert invalid_type.status_code == 422
    assert "unknown-sensitive-value" not in invalid_type.text
    assert injected_user.status_code == 422
    assert "attacker" not in injected_user.text


def test_telemetry_event_stores_only_a_stable_typed_target() -> None:
    client, app = make_client()
    payload = event_payload(event_id="session-1:page_viewed:1") | {
        "event_type": "page_viewed",
        "course_id": "_app",
        "payload": {"page_id": "study_hub"},
    }
    with client:
        token = token_for(client, cpf="123.456.789-09", name="Estudante Um")
        created = client.post("/events", json=payload, headers=bearer(token))
        retried = client.post("/events", json=payload, headers=bearer(token))
        free_text = client.post(
            "/events",
            json=payload
            | {
                "event_id": "invalid-free-text",
                "payload": {"page_id": "Meu CPF é 123.456.789-09"},
            },
            headers=bearer(token),
        )
        extra_field = client.post(
            "/events",
            json=payload
            | {
                "event_id": "invalid-extra-field",
                "payload": {"page_id": "study_hub", "name": "Pessoa"},
            },
            headers=bearer(token),
        )
        with Session(app.state.database.engine) as session:
            record = session.get(LearningEventRecord, payload["event_id"])

    assert created.status_code == 201
    assert retried.status_code == 200
    assert created.json()["payload"] == {"page_id": "study_hub"}
    assert record is not None
    assert record.payload == {"page_id": "study_hub"}
    assert free_text.status_code == 422
    assert "123.456.789-09" not in free_text.text
    assert extra_field.status_code == 422
    assert "Pessoa" not in extra_field.text


def test_list_events_is_isolated_filtered_and_bounded() -> None:
    client, _ = make_client()
    with client:
        first = token_for(client, cpf="123.456.789-09", name="Estudante Um")
        second = token_for(client, cpf="987.654.321-00", name="Estudante Dois")
        client.post(
            "/events",
            json=event_payload(event_id="first-a", course_id="course-a"),
            headers=bearer(first),
        )
        client.post(
            "/events",
            json=event_payload(event_id="first-b", course_id="course-b"),
            headers=bearer(first),
        )
        client.post(
            "/events",
            json=event_payload(event_id="second-a", course_id="course-a"),
            headers=bearer(second),
        )
        filtered = client.get(
            "/events?course_id=course-a&limit=1", headers=bearer(first)
        )
        excessive = client.get("/events?limit=101", headers=bearer(first))

    assert filtered.status_code == 200
    assert [event["event_id"] for event in filtered.json()["events"]] == [
        "first-a"
    ]
    assert excessive.status_code == 422


@pytest.mark.parametrize("role", ["teacher", "monitor", "admin"])
def test_non_student_roles_are_authenticated_but_cannot_use_student_events(
    role: str,
) -> None:
    client, app = make_client()
    with client:
        token_for(client, cpf="123.456.789-09", name="Pessoa da Equipe")
        with Session(app.state.database.engine) as session:
            user = session.scalar(select(User).where(User.name == "Pessoa da Equipe"))
            assert user is not None
            user.role = role
            session.commit()

        login = client.post(
            "/auth/login",
            json={"cpf": "123.456.789-09", "password": PASSWORD},
        )
        token = login.json()["access_token"]
        profile = client.get("/auth/me", headers=bearer(token))
        create = client.post(
            "/events", json=event_payload(), headers=bearer(token)
        )
        listing = client.get("/events", headers=bearer(token))

    assert login.status_code == 200
    assert profile.status_code == 200
    assert profile.json()["role"] == role
    assert create.status_code == 403
    assert listing.status_code == 403
