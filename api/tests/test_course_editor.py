from __future__ import annotations

from copy import deepcopy
from datetime import date
import json
from pathlib import Path

from alembic import command
from alembic.config import Config
from fastapi import FastAPI, Header
from fastapi.testclient import TestClient
import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import access_claims
from app.course_editor import ensure_legacy_course_version, legacy_version_id, router
from app.database import Database
from app.models import Classroom, Course, CourseVersion, CourseVersionTransition, Institution, Program, ProgramCourse, ProgramMembership, User


@pytest.fixture
def editor(tmp_path: Path):
    database = Database(f"sqlite+pysqlite:///{(tmp_path / 'editor.db').as_posix()}")
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", str(database.engine.url))
    command.upgrade(config, "head")
    app = FastAPI()
    app.state.database = database
    app.include_router(router)

    def claims(x_user: str = Header(default="creator")):
        return {"sub": x_user, "role": "admin" if x_user == "admin" else "teacher" if x_user == "global_teacher" else "student"}

    app.dependency_overrides[access_claims] = claims
    with Session(database.engine) as session:
        session.add(Institution(id="institution", name="TDS"))
        session.flush()
        session.add_all([Program(id="p1", institution_id="institution", name="Um"), Program(id="p2", institution_id="institution", name="Dois")])
        for index, identity in enumerate(("creator", "teacher", "other", "coordinator", "outsider", "student", "global_teacher", "inactive", "admin")):
            session.add(User(id=identity, name=identity, cpf_digest=str(index).zfill(64), phone="61999990000", password_digest="digest", role="admin" if identity == "admin" else "student"))
        session.flush()
        for identity, program, role, status in (("creator", "p1", "creator", "active"), ("teacher", "p1", "teacher", "active"), ("other", "p1", "creator", "active"), ("coordinator", "p1", "coordinator", "active"), ("outsider", "p2", "coordinator", "active"), ("student", "p1", "student", "active"), ("inactive", "p1", "coordinator", "inactive")):
            session.add(ProgramMembership(user_id=identity, program_id=program, role=role, status=status))
        session.commit()
    with TestClient(app) as client:
        yield client, database.engine
    database.dispose()


def headers(user: str):
    return {"X-User": user}


def create(client, user="creator", identity="course"):
    response = client.post("/courses", headers=headers(user), json={"course_id": identity, "program_id": "p1", "title": "Curso", "author": "TDS"})
    assert response.status_code == 201, response.text
    return response.json()


def save(client, view, user="creator", content="Primeira mensagem"):
    return client.patch(f"/courses/{view['course_id']}", headers=headers(user), json={"version_id": view["version_id"], "expected_revision": view["revision"], "title": view["title"], "author": view["author"], "sections": [{"id": "module", "title": "Módulo", "messages": [{"id": "content", "type": "bot", "content": content}]}]})


def action(client, view, verb, user="creator"):
    return client.post(f"/courses/{view['course_id']}/{verb}", headers=headers(user), json={"version_id": view["version_id"], "expected_revision": view["revision"]})


def publish(client):
    draft = save(client, create(client)).json()
    review = action(client, draft, "submit").json()
    response = action(client, review, "publish", "coordinator")
    assert response.status_code == 200, response.text
    return response.json()


def test_context_requires_active_program_role_and_drafts_do_not_leak(editor):
    client, _ = editor
    for user in ("student", "global_teacher", "inactive"):
        assert client.get("/editor/context", headers=headers(user)).json() == {"programs": []}
        assert client.post("/courses", headers=headers(user), json={"course_id": "forbidden", "program_id": "p1", "title": "Curso", "author": "TDS"}).status_code == 403
    program = client.get("/editor/context").json()["programs"][0]
    assert program == {"id": "p1", "name": "Um", "role": "creator", "can_create": True, "can_publish": False}
    draft = create(client)
    assert draft["can_edit"] and not draft["can_publish"]
    assert client.get("/editor/courses?program_id=p1", headers=headers("other")).json()["courses"] == []
    for user in ("other", "outsider", "student", "inactive", "global_teacher"):
        assert client.get("/editor/courses/course", headers=headers(user)).status_code == 404
        assert save(client, draft, user).status_code == 404
    assert client.get("/editor/courses?program_id=p1", headers=headers("outsider")).status_code == 403
    assert len(client.get("/editor/courses?program_id=p1", headers=headers("coordinator")).json()["courses"]) == 1
    assert create(client, "teacher", "teacher-course")["can_edit"]


def test_review_publish_archive_and_audit(editor):
    client, engine = editor
    initial = create(client)
    assert action(client, initial, "submit").status_code == 422
    assert action(client, initial, "publish", "coordinator").status_code == 403
    draft = save(client, initial).json()
    review = action(client, draft, "submit").json()
    assert review["status"] == "in_review" and not review["can_edit"]
    assert save(client, review).status_code == 403
    assert action(client, review, "publish").status_code == 403
    published = action(client, review, "publish", "coordinator").json()
    with Session(engine) as session:
        course = session.get(Course, "course")
        assert course.active and course.content["sections"] == published["sections"]
    archived = action(client, published, "archive", "coordinator").json()
    assert archived["status"] == "archived" and archived["can_fork"]
    with Session(engine) as session:
        assert not session.get(Course, "course").active
        history = session.scalars(select(CourseVersionTransition).order_by(CourseVersionTransition.occurred_at)).all()
        assert [row.to_status for row in history] == ["draft", "in_review", "published", "archived"]
        assert [row.actor_user_id for row in history] == ["creator", "creator", "coordinator", "coordinator"]
        assert all(row.occurred_at for row in history)


def test_revision_conflict_and_component_versions(editor):
    client, _ = editor
    initial = create(client)
    first = save(client, initial).json()
    assert save(client, initial, content="stale").status_code == 409
    assert action(client, initial, "submit").status_code == 409
    second = save(client, first, content="Segunda mensagem").json()
    assert second["sections"][0]["id"] == first["sections"][0]["id"]
    assert second["sections"][0]["version_id"] != first["sections"][0]["version_id"]
    assert second["sections"][0]["messages"][0]["id"] == "content"
    assert second["sections"][0]["messages"][0]["version_id"] != first["sections"][0]["messages"][0]["version_id"]
    third = save(client, second, content="Segunda mensagem").json()
    assert third["sections"] == second["sections"]


def test_fork_keeps_classroom_pinned_and_snapshot_immutable(editor):
    client, engine = editor
    published = publish(client)
    original = deepcopy(published["sections"])
    with Session(engine) as session:
        session.add(Classroom(id="class", program_id="p1", course_id="course", course_version_id=published["version_id"], teacher_id="teacher", name="Turma", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1)))
        session.commit()
    fork = client.post("/courses/course/versions", json={"source_version_id": published["version_id"]}).json()
    assert fork["version_number"] == 2 and fork["sections"] == original
    assert fork["version_id"] != published["version_id"]
    updated = save(client, fork, content="Nova versão").json()
    review = action(client, updated, "submit").json()
    published2 = action(client, review, "publish", "coordinator").json()
    with Session(engine) as session:
        classroom = session.get(Classroom, "class")
        old = session.get(CourseVersion, classroom.course_version_id)
        assert old.id == published["version_id"] and old.status == "archived"
        assert old.content["sections"] == original
        assert session.get(Course, "course").content["sections"] == published2["sections"]
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("UPDATE course_versions SET content = '{}' WHERE id = :id"), {"id": published["version_id"]})
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("UPDATE course_versions SET status = 'draft' WHERE id = :id"), {"id": published["version_id"]})
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("DELETE FROM course_version_transitions"))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("UPDATE course_version_transitions SET actor_role = 'fake'"))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("DELETE FROM course_versions WHERE id = :id"), {"id": published["version_id"]})


def test_coordinator_can_publish_own_draft_but_not_other_program_projection(editor):
    client, engine = editor
    draft = save(client, create(client, "coordinator"), "coordinator").json()
    review = action(client, draft, "submit", "coordinator").json()
    assert action(client, review, "publish", "coordinator").status_code == 200
    fork = client.post("/courses/course/versions", json={"source_version_id": review["version_id"]}).json()
    review2 = action(client, fork, "submit").json()
    with Session(engine) as session:
        session.add(ProgramCourse(program_id="p2", course_id="course"))
        session.commit()
    assert action(client, review2, "publish", "coordinator").status_code == 403
    assert action(client, review2, "publish", "admin").status_code == 200


def test_seed_versioning_is_idempotent_and_keeps_public_payload(editor):
    _, engine = editor
    with Session(engine) as session:
        course = Course(id="legacy", title="Legado", author="TDS", active=True, content={"sections": [{"id": "module", "title": "Módulo", "messages": [{"type": "bot", "content": "Preservar"}]}], "downloadUrl": "https://example.test/a.pdf"})
        session.add(course)
        version = ensure_legacy_course_version(session, course)
        assert version.id == legacy_version_id("legacy")
        assert ensure_legacy_course_version(session, course).id == version.id
        assert "id" not in course.content["sections"][0]["messages"][0]
        assert version.content["sections"][0]["messages"][0]["id"]
        assert version.content["downloadUrl"] == "https://example.test/a.pdf"
        session.commit()


def test_validation_duplicate_ids_and_wrong_course_version(editor):
    client, _ = editor
    first = create(client)
    second = create(client, identity="another")
    assert client.patch("/courses/another", json={"version_id": first["version_id"], "expected_revision": 1, "title": "Title", "author": "Author", "sections": []}).status_code == 404
    duplicate = {"id": "same", "title": "Module", "messages": [{"type": "bot", "content": "A"}]}
    assert client.patch("/courses/another", json={"version_id": second["version_id"], "expected_revision": 1, "title": "Title", "author": "Author", "sections": [duplicate, duplicate]}).status_code == 422


def test_backfill_real_catalog_preserves_courses_and_snapshot_ids(tmp_path):
    url = f"sqlite+pysqlite:///{(tmp_path / 'catalog.db').as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", url)
    command.upgrade(config, "20260920_0014")
    engine = create_engine(url)
    sources = sorted((Path(__file__).resolve().parents[2] / "cartilhas_app/assets/data/lessons").glob("*.json"))
    originals = {}
    with engine.begin() as connection:
        for source in sources:
            payload = json.loads(source.read_text(encoding="utf-8"))
            originals[payload["id"]] = payload
            content = {key: value for key, value in payload.items() if key not in {"id", "title", "author"}}
            connection.execute(text("INSERT INTO courses (id, title, author, content, active) VALUES (:id, :title, :author, :content, 1)"), {"id": payload["id"], "title": payload["title"], "author": payload["author"], "content": json.dumps(content)})
    command.upgrade(config, "head")
    with Session(engine) as session:
        versions = session.scalars(select(CourseVersion)).all()
        courses = session.scalars(select(Course)).all()
        assert len(versions) == len(courses) == len(originals) == 9
        for course in courses:
            original = originals[course.id]
            version = session.get(CourseVersion, legacy_version_id(course.id))
            assert course.active and version.status == "published"
            assert course.title == version.content["title"] == original["title"]
            assert course.content["sections"] == original["sections"]
            snapshot = deepcopy(version.content)
            for section in snapshot["sections"]:
                assert section.pop("version_id")
                for message in section["messages"]:
                    assert message.pop("version_id")
                    assert message.pop("id")
            assert snapshot == original
    engine.dispose()


def test_actor_anonymization_preserves_audit_and_published_content(editor):
    client, engine = editor
    published = publish(client)
    with engine.connect() as connection:
        connection.execute(text("PRAGMA foreign_keys=ON"))
        connection.execute(text("DELETE FROM program_memberships WHERE user_id IN ('creator', 'coordinator')"))
        connection.execute(text("DELETE FROM users WHERE id IN ('creator', 'coordinator')"))
        connection.commit()
    with Session(engine) as session:
        version = session.get(CourseVersion, published["version_id"])
        assert version.creator_user_id is None and version.content["sections"] == published["sections"]
        transitions = session.scalars(select(CourseVersionTransition)).all()
        assert len(transitions) == 3 and all(row.actor_user_id is None for row in transitions)
        assert {row.actor_role for row in transitions} == {"creator", "coordinator"}


def test_published_versions_visible_across_linked_programs_without_draft_leak(editor):
    client, engine = editor
    published = publish(client)
    with Session(engine) as session:
        session.add(ProgramCourse(program_id="p2", course_id="course"))
        session.commit()
    listed = client.get("/editor/courses?program_id=p2", headers=headers("outsider")).json()["courses"]
    assert listed[0]["version_id"] == published["version_id"]
    fork = client.post("/courses/course/versions", headers=headers("outsider"), json={"source_version_id": published["version_id"]}).json()
    assert fork["program_id"] == "p2"
    assert client.get(f"/editor/courses/course?version_id={fork['version_id']}", headers=headers("coordinator")).status_code == 404
    assert client.get("/editor/courses?program_id=p1").json()["courses"][0]["version_id"] == published["version_id"]


@pytest.mark.parametrize("message", [
    {"type": "unsupported", "content": "Texto"},
    {"type": "bot", "content": " \n "},
    {"type": "question", "content": "Pergunta"},
    {"type": "quiz", "content": "Pergunta", "options": []},
    {"type": "question", "content": "Pergunta", "options": [{"label": "Única"}]},
    {"type": "quiz", "content": "Pergunta", "options": [{"label": "Única"}]},
    {"type": "quiz", "content": "Pergunta", "options": [{"label": "A"}, {"label": "B", "isCorrect": False}]},
    {"type": "user", "content": "Continuar?"},
    {"type": "user", "content": "Continuar?", "options": [{"label": "   "}]},
    {"type": "bot", "content": "Texto", "feedback": 123},
    {"type": "bot", "content": "Texto", "explanation": ["texto"]},
    {"type": "user", "content": "Continuar?", "options": [{"label": "Sim", "value": 1}]},
    {"type": "user", "content": "Continuar?", "options": [{"label": "Sim", "feedback": {"text": "ok"}}]},
    {"type": "user", "content": "Continuar?", "options": [{"label": "Sim", "isCorrect": "true"}]},
    {"type": "user", "content": "Continuar?", "options": [{"label": "Sim", "isCorrect": 1}]},
])
def test_incomplete_reader_content_can_save_but_cannot_submit(editor, message):
    client, engine = editor
    draft = create(client)
    response = client.patch("/courses/course", json={"version_id": draft["version_id"], "expected_revision": draft["revision"], "title": "Curso", "author": "TDS", "sections": [{"id": "module", "title": "Módulo", "messages": [message]}]})
    assert response.status_code == 200, response.text
    saved = response.json()
    rejected = action(client, saved, "submit")
    assert rejected.status_code == 422, rejected.text
    with Session(engine) as session:
        record = session.get(CourseVersion, saved["version_id"])
        assert record.status == "draft" and record.revision == saved["revision"]
        assert not session.get(Course, "course").active


def test_publish_revalidates_reviewed_content_before_changing_public_projection(editor):
    client, engine = editor
    draft = save(client, create(client)).json()
    # Simulate an older writer admitting a review before this validation existed.
    with Session(engine) as session:
        record = session.get(CourseVersion, draft["version_id"])
        content = deepcopy(record.content)
        content["sections"][0]["messages"][0]["type"] = "quiz"
        record.content = content
        record.status = "in_review"
        session.commit()
    rejected = action(client, draft, "publish", "coordinator")
    assert rejected.status_code == 422, rejected.text
    with Session(engine) as session:
        assert session.get(CourseVersion, draft["version_id"]).status == "in_review"
        assert not session.get(Course, "course").active


def test_reader_compatible_message_types_can_be_reviewed_and_published(editor):
    client, _ = editor
    draft = create(client)
    messages = [
        {"type": "bot", "content": "Introdução", "feedback": None, "explanation": "Detalhe"},
        {"type": "question", "content": "Qual opção?", "options": [{"label": "A", "value": "a"}, {"label": "B", "value": None}]},
        {"type": "quiz", "content": "Qual resposta?", "options": [{"label": "A", "isCorrect": True, "feedback": "Certo"}, {"label": "B", "isCorrect": False}]},
        {"type": "user", "content": "Continuar?", "options": [{"label": "Sim", "isCorrect": None, "feedback": None}]},
    ]
    response = client.patch("/courses/course", json={"version_id": draft["version_id"], "expected_revision": draft["revision"], "title": "Curso", "author": "TDS", "sections": [{"id": "module", "title": "Módulo", "messages": messages}]})
    assert response.status_code == 200, response.text
    review = action(client, response.json(), "submit")
    assert review.status_code == 200, review.text
    published = action(client, review.json(), "publish", "coordinator")
    assert published.status_code == 200, published.text
    assert [message["type"] for message in published.json()["sections"][0]["messages"]] == ["bot", "question", "quiz", "user"]
