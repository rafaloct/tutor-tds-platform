from __future__ import annotations

import json
from pathlib import Path

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.course_seed import import_courses
from app.models import Base, Course, CourseVersion


def test_import_courses_is_idempotent_and_refuses_silent_updates(tmp_path: Path) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    source = tmp_path / "courses"
    source.mkdir()
    path = source / "course.json"
    path.write_text(
        json.dumps(
            {
                "id": "course-1",
                "title": "Primeiro título",
                "author": "TDS",
                "sections": [],
                "downloadUrl": "https://example.test/course.pdf",
            }
        ),
        encoding="utf-8",
    )

    assert import_courses(engine, [source]) == 1
    assert import_courses(engine, [source]) == 1
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["title"] = "Título atualizado"
    path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(ValueError, match="nova versão"):
        import_courses(engine, [source])

    with Session(engine) as session:
        courses = session.scalars(select(Course)).all()
        assert len(courses) == 1
        assert courses[0].title == "Primeiro título"
        assert courses[0].content["sections"] == []
        assert len(session.scalars(select(CourseVersion)).all()) == 1
    engine.dispose()


def test_import_courses_rejects_invalid_content(tmp_path: Path) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    path = tmp_path / "invalid.json"
    path.write_text('{"id": "broken"}', encoding="utf-8")

    with pytest.raises(ValueError, match="title"):
        import_courses(engine, [path])
    engine.dispose()
