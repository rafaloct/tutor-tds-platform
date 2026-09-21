from __future__ import annotations

import argparse
import json
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from sqlalchemy import Engine
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import Course
from .course_editor import ensure_legacy_course_version, snapshot_content


def discover_json_files(sources: Iterable[Path]) -> list[Path]:
    files: set[Path] = set()
    for source in sources:
        if source.is_dir():
            files.update(source.glob("*.json"))
        elif source.is_file() and source.suffix.lower() == ".json":
            files.add(source)
    return sorted(files)


def import_courses(engine: Engine, sources: Iterable[Path]) -> int:
    files = discover_json_files(sources)
    if not files:
        raise ValueError("Nenhum arquivo JSON de curso foi encontrado.")

    courses = [_read_course(path) for path in files]
    with Session(engine) as session:
        for course in courses:
            existing = session.get(Course, course.id)
            if existing is not None:
                incoming = snapshot_content(course.id, course.title, course.author, course.content, legacy=True)
                current = snapshot_content(existing.id, existing.title, existing.author, existing.content, legacy=True)
                # Version metadata describes identity, not seed-owned content.
                for value in (incoming, current):
                    value.pop("version_id", None)
                    value.pop("course_version_id", None)
                    value.pop("version_number", None)
                if current != incoming:
                    raise ValueError(f"Curso {course.id} já existe com conteúdo diferente. Use uma nova versão pelo editor; importação cancelada.")
                ensure_legacy_course_version(session, existing)
            else:
                session.add(course)
                ensure_legacy_course_version(session, course)
        session.commit()
    return len(courses)


def _read_course(path: Path) -> Course:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Curso inválido em {path.name}.") from error

    if not isinstance(payload, dict):
        raise ValueError(f"Curso inválido em {path.name}.")
    for field in ("id", "title", "author"):
        if not isinstance(payload.get(field), str) or not payload[field].strip():
            raise ValueError(f"Campo {field} inválido em {path.name}.")
    if not isinstance(payload.get("sections"), list):
        raise ValueError(f"Campo sections inválido em {path.name}.")

    identity = {"id", "title", "author"}
    content: dict[str, Any] = {
        key: value for key, value in payload.items() if key not in identity
    }
    return Course(
        id=payload["id"].strip(),
        title=payload["title"].strip(),
        author=payload["author"].strip(),
        content=content,
        active=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Importa cartilhas JSON.")
    parser.add_argument("sources", nargs="+", type=Path)
    args = parser.parse_args()

    database = Database(Settings.from_environment().database_url)
    try:
        count = import_courses(database.engine, args.sources)
    finally:
        database.dispose()
    print(f"{count} curso(s) importado(s).")


if __name__ == "__main__":
    main()
