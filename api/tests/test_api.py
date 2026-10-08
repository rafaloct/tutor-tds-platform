from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import create_app
from app.config import Settings
from app.models import Base, Course


def make_client(
    *,
    learning_context_enabled: bool = False,
    dynamic_activity_enabled: bool = False,
) -> tuple[TestClient, object]:
    app = create_app(
        database_url="sqlite+pysqlite:///:memory:",
        settings=Settings(
            database_url="sqlite+pysqlite:///:memory:",
            allowed_origins=(),
            jwt_secret="j" * 32,
            cpf_pepper="p" * 32,
            learning_context_enabled=learning_context_enabled,
            dynamic_activity_enabled=dynamic_activity_enabled,
        ),
    )
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def test_health_reports_database_available() -> None:
    client, _ = make_client()
    with client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "available"}
    assert len(response.headers["X-Request-ID"]) == 32


def test_live_reports_process_without_database_dependency() -> None:
    client, app = make_client()
    app.state.database.dispose()

    with client:
        response = client.get("/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert len(response.headers["X-Request-ID"]) == 32


@pytest.mark.parametrize(
    "public_base",
    [
        "http://ead.example/tutor-staging-api",
        "https://user:password@ead.example/tutor-staging-api",
        "https://ead.example/tutor-staging-api?redirect=evil",
        "https://ead.example/tutor-staging-api#fragment",
        "https://ead.example/tutor-staging-api/../admin",
        "https://ead.example/tutor-staging-api/%2e%2e/admin",
        "https://ead.example/tutor-staging-api//admin",
        "https://ead.example\\@attacker.invalid/tutor-staging-api",
        "https://ead .example/tutor-staging-api",
    ],
)
def test_public_api_base_rejects_unsafe_or_ambiguous_urls(public_base: str) -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="j" * 32,
        cpf_pepper="p" * 32,
        public_api_base_url=public_base,
    )

    with pytest.raises(RuntimeError, match="PUBLIC_API_BASE_URL"):
        settings.require_auth_secrets()


def test_courses_returns_only_active_records_in_app_contract() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        session.add_all(
            [
                Course(
                    id="z",
                    title="Zootecnia",
                    author="TDS",
                    active=True,
                    content={"sections": [], "downloadUrl": None},
                ),
                Course(
                    id="a",
                    title="Agricultura",
                    author="TDS",
                    active=True,
                    content={"sections": []},
                ),
                Course(
                    id="hidden",
                    title="Rascunho",
                    author="TDS",
                    active=False,
                    content={"sections": []},
                ),
            ]
        )
        session.commit()

    with client:
        response = client.get("/courses")
    assert response.status_code == 200
    courses = response.json()["courses"]
    assert [item["id"] for item in courses] == ["a", "z"]
    assert courses[0]["sections"] == []


def test_course_detail_hides_missing_and_inactive_records() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        session.add_all(
            [
                Course(
                    id="active",
                    title="Curso ativo",
                    author="TDS",
                    active=True,
                    content={"sections": [], "thumbnailUrl": "cover.png"},
                ),
                Course(
                    id="draft",
                    title="Rascunho",
                    author="TDS",
                    active=False,
                    content={"sections": []},
                ),
            ]
        )
        session.commit()

    with client:
        response = client.get("/courses/active")
        draft = client.get("/courses/draft")
        missing = client.get("/courses/missing")

    assert response.status_code == 200
    assert response.json()["thumbnailUrl"] == "cover.png"
    assert draft.status_code == 404
    assert missing.status_code == 404


def test_public_course_projection_hides_answer_keys_only_when_wave2b_is_enabled(
) -> None:
    content = {
        "sections": [
            {
                "id": "module",
                "title": "Módulo",
                "messages": [
                    {
                        "id": "quiz",
                        "type": "quiz",
                        "content": "Qual?",
                        "feedback": "Reservado",
                        "explanation": "Explicação",
                        "options": [
                            {
                                "id": "a",
                                "label": "A",
                                "value": "a",
                                "isCorrect": True,
                                "feedback": "Correta",
                            },
                            {"label": "B", "isCorrect": False},
                        ],
                    }
                ],
            }
        ]
    }
    protected_client, protected_app = make_client(
        learning_context_enabled=True,
        dynamic_activity_enabled=True,
    )
    legacy_client, legacy_app = make_client(
        learning_context_enabled=True,
        dynamic_activity_enabled=False,
    )
    for app in (protected_app, legacy_app):
        with Session(app.state.database.engine) as session:
            session.add(
                Course(
                    id="course",
                    title="Curso",
                    author="TDS",
                    active=True,
                    content=content,
                )
            )
            session.commit()

    with protected_client:
        listed = protected_client.get("/courses")
        detailed = protected_client.get("/courses/course")
        with Session(protected_app.state.database.engine) as session:
            stored_answer = session.get(Course, "course").content["sections"][0][
                "messages"
            ][0]["options"][0]["isCorrect"]
    assert listed.status_code == detailed.status_code == 200
    for projection in (listed.json()["courses"][0], detailed.json()):
        quiz = projection["sections"][0]["messages"][0]
        assert quiz["options"] == [
            {"id": "a", "label": "A"},
            {"label": "B"},
        ]
        assert not {"feedback", "explanation"} & set(quiz)
        assert not {"value", "isCorrect", "feedback"} & set(quiz["options"][0])
    assert stored_answer is True

    with legacy_client:
        legacy = legacy_client.get("/courses/course")
    legacy_quiz = legacy.json()["sections"][0]["messages"][0]
    assert legacy_quiz["feedback"] == "Reservado"
    assert legacy_quiz["options"][0]["isCorrect"] is True
