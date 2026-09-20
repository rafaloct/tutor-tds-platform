from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import create_app
from app.models import Base, Course


def make_client() -> tuple[TestClient, object]:
    app = create_app(database_url="sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def test_health_reports_database_available() -> None:
    client, _ = make_client()
    with client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "available"}


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
