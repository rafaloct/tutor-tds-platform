from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import Base, Course, CourseVersion


def make_client() -> tuple[TestClient, object]:
    app = create_app(
        database_url="sqlite+pysqlite:///:memory:",
        settings=Settings(
            database_url="sqlite+pysqlite:///:memory:",
            allowed_origins=(),
            jwt_secret="j" * 32,
            cpf_pepper="p" * 32,
        ),
    )
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def add_course(
    session: Session,
    *,
    course_id: str,
    title: str,
    active: bool = True,
    version_status: str | None = "published",
    content: dict | None = None,
    version_number: int = 1,
) -> None:
    session.add(
        Course(
            id=course_id,
            title=title,
            author="TDS",
            active=active,
            content=content or {"sections": [{"id": "private", "messages": []}]},
        )
    )
    if version_status is not None:
        session.add(
            CourseVersion(
                id=f"version-{course_id}",
                course_id=course_id,
                version_number=version_number,
                revision=1,
                status=version_status,
                content={},
            )
        )


def test_public_catalog_only_returns_active_published_safe_projection() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        add_course(
            session,
            course_id="safe",
            title="Curso público",
            content={
                "sections": [{"id": "never-public", "messages": [{"content": "private"}]}],
                "summary": "Resumo público.",
                "thumbnailUrl": "https://cdn.example.test/cover.webp",
                "downloadUrl": "https://cdn.example.test/internal.pdf",
                "public_workload_text": "80h",
                "public_audience_text": "Público informado.",
                "user_id": "must-not-leak",
            },
            version_number=3,
        )
        add_course(session, course_id="inactive", title="Inativo", active=False)
        add_course(session, course_id="draft", title="Rascunho", version_status="draft")
        add_course(session, course_id="unversioned", title="Sem versão", version_status=None)
        session.commit()

    with client:
        response = client.get("/public/courses")

    assert response.status_code == 200
    assert response.headers["cache-control"] == "public, max-age=60, stale-while-revalidate=300"
    payload = response.json()
    assert payload["total"] == 1
    assert payload["offset"] == 0
    assert payload["limit"] == 50
    assert payload["courses"] == [
        {
            "slug": "safe",
            "title": "Curso público",
            "summary": "Resumo público.",
            "status": "published",
            "published_version_label": "v3",
            "cover_public_url": "https://cdn.example.test/cover.webp",
            "public_workload_text": "80h",
            "public_audience_text": "Público informado.",
            "updated_at": payload["courses"][0]["updated_at"],
        }
    ]
    serialized = response.text.lower()
    for forbidden in (
        "sections",
        "messages",
        "downloadurl",
        "user_id",
        "membership_id",
        "enrollment_id",
        "cpf",
        "phone",
        "baseline",
        "progress",
        "presence",
        "course_version_id",
    ):
        assert forbidden not in serialized


def test_public_detail_hides_inactive_draft_and_missing_equally() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        add_course(session, course_id="published", title="Publicado")
        add_course(session, course_id="inactive", title="Inativo", active=False)
        add_course(session, course_id="draft", title="Rascunho", version_status="draft")
        session.commit()

    with client:
        ok = client.get("/public/courses/published")
        inactive = client.get("/public/courses/inactive")
        draft = client.get("/public/courses/draft")
        missing = client.get("/public/courses/missing")

    assert ok.status_code == 200
    assert ok.json()["slug"] == "published"
    for response in (inactive, draft, missing):
        assert response.status_code == 404
        assert response.json() == {"detail": "Curso não encontrado."}


def test_public_catalog_pagination_is_bounded_and_sorted() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        add_course(session, course_id="z", title="Zulu")
        add_course(session, course_id="a", title="Alpha")
        add_course(session, course_id="m", title="Mike")
        session.commit()

    with client:
        response = client.get("/public/courses?offset=1&limit=1")
        too_large = client.get("/public/courses?limit=101")

    assert response.status_code == 200
    assert response.json()["total"] == 3
    assert [item["slug"] for item in response.json()["courses"]] == ["m"]
    assert too_large.status_code == 422


def test_public_projection_omits_untrusted_or_implicit_metadata() -> None:
    client, app = make_client()
    with Session(app.state.database.engine) as session:
        add_course(
            session,
            course_id="minimal",
            title="Mínimo",
            content={
                "sections": [],
                "thumbnailUrl": "http://insecure.example.test/cover.png",
                "audience": "Não é campo público canônico",
                "workload": "Não inferir",
                "faq": [{"question": "Não expor"}],
                "materials": [{"url": "https://example.test/not-canonical"}],
            },
        )
        session.commit()

    with client:
        response = client.get("/public/courses/minimal")

    assert response.status_code == 200
    payload = response.json()
    assert set(payload) == {
        "slug",
        "title",
        "status",
        "published_version_label",
        "updated_at",
    }


def test_public_openapi_declares_the_safe_projection() -> None:
    client, _ = make_client()

    with client:
        schema = client.get("/openapi.json").json()

    catalog = schema["paths"]["/public/courses"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]
    detail = schema["paths"]["/public/courses/{slug}"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]
    assert catalog == {"$ref": "#/components/schemas/PublicCourseCatalog"}
    assert detail == {"$ref": "#/components/schemas/PublicCourseProjection"}
    projection = schema["components"]["schemas"]["PublicCourseProjection"]
    assert set(projection["properties"]) == {
        "slug",
        "title",
        "status",
        "published_version_label",
        "updated_at",
        "summary",
        "cover_public_url",
        "public_workload_text",
        "public_audience_text",
    }
