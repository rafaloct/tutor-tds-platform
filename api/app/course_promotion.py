"""Explicit, content-only course promotion. Import defaults to a read-only plan."""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
from typing import Any
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import Engine, select, text, update
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from .course_editor import snapshot_content, validate_publishable_content
from .database import Database
from .models import Course, CourseVersion, CourseVersionTransition, Program, ProgramCourse, ProgramMembership, User

MANIFEST_KEYS = {"schema_version", "course_id", "version_id", "version_number", "content", "sha256"}
CONTENT_KEYS = {"id", "title", "author", "sections", "downloadUrl", "thumbnailUrl"}
SECTION_KEYS = {"id", "version_id", "title", "messages"}
MESSAGE_KEYS = {"id", "version_id", "type", "content", "options", "feedback", "explanation", "experience"}
OPTION_KEYS = {"label", "value", "isCorrect", "feedback"}
IDENTIFIER = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$")
EXPERIENCE_IDENTIFIER = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
EXPERIENCE_KINDS = {"scenario", "reveal", "reflection", "action_challenge"}
DIGEST = re.compile(r"^[a-f0-9]{64}$")


def manifest_digest(manifest: dict[str, Any]) -> str:
    unsigned = {key: value for key, value in manifest.items() if key != "sha256"}
    canonical = json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _only_keys(value: Any, allowed: set[str], location: str) -> None:
    if not isinstance(value, dict) or set(value) - allowed:
        raise ValueError(f"{location}: campos fora do contrato de conteúdo; exportação/importação recusada.")


def verify_manifest(manifest: Any, expected_digest: str) -> dict[str, Any]:
    if not isinstance(manifest, dict) or set(manifest) != MANIFEST_KEYS:
        raise ValueError("Manifesto deve conter exclusivamente os campos do schema_version 1.")
    if type(manifest["schema_version"]) is not int or manifest["schema_version"] != 1:
        raise ValueError("schema_version não suportado.")
    if not isinstance(expected_digest, str) or not DIGEST.fullmatch(expected_digest):
        raise ValueError("expected_digest deve ser SHA256 hexadecimal minúsculo.")
    digest = manifest_digest(manifest)
    if not isinstance(manifest["sha256"], str) or not DIGEST.fullmatch(manifest["sha256"]) or not hmac.compare_digest(digest, manifest["sha256"]) or not hmac.compare_digest(digest, expected_digest):
        raise ValueError("SHA256 divergente do manifesto ou do digest esperado.")
    for field, maximum in (("course_id", 120), ("version_id", 36)):
        value = manifest[field]
        if not isinstance(value, str) or not IDENTIFIER.fullmatch(value) or len(value) > maximum:
            raise ValueError(f"{field} inválido.")
    if type(manifest["version_number"]) is not int or manifest["version_number"] < 1:
        raise ValueError("version_number deve ser inteiro positivo.")
    content = manifest["content"]
    _only_keys(content, CONTENT_KEYS, "Curso")
    if content.get("id") != manifest["course_id"]:
        raise ValueError("course_id difere do ID do snapshot.")
    for field in ("title", "author"):
        if not isinstance(content.get(field), str) or not content[field].strip() or len(content[field]) > 240:
            raise ValueError(f"{field} inválido no snapshot.")
    for field in ("downloadUrl", "thumbnailUrl"):
        if content.get(field) is not None and not isinstance(content[field], str):
            raise ValueError(f"{field} deve ser texto ou null.")
    try:
        validate_publishable_content(content)
        normalized = snapshot_content(manifest["course_id"], content["title"], content["author"], content)
    except HTTPException as error:
        raise ValueError(f"Snapshot não publicável: {error.detail}") from error
    if normalized != content:
        raise ValueError("IDs/version_ids de módulos ou conteúdos ausentes ou incompatíveis com o snapshot.")
    for section in content["sections"]:
        _only_keys(section, SECTION_KEYS, "Módulo")
        for message in section["messages"]:
            _only_keys(message, MESSAGE_KEYS, "Mensagem")
            if "experience" in message:
                _validate_experience(message)
            for option in message.get("options") or []:
                _only_keys(option, OPTION_KEYS, "Opção")
    return deepcopy(manifest)


def _validate_experience(message: dict[str, Any]) -> None:
    experience = message["experience"]
    _only_keys(
        experience,
        {"id", "kind", "objective", "required", "actionLabel", "ai"},
        "Experiência",
    )
    identity = experience.get("id")
    if (
        message["type"] != "bot"
        or not isinstance(identity, str)
        or len(identity) > 128
        or not EXPERIENCE_IDENTIFIER.fullmatch(identity)
    ):
        raise ValueError("Experiência exige ID estável e mensagem bot.")
    kind = experience.get("kind")
    if not isinstance(kind, str) or kind not in EXPERIENCE_KINDS:
        raise ValueError("Tipo de experiência inválido.")
    objective = experience.get("objective")
    if not isinstance(objective, str) or not objective.strip() or len(objective) > 2000:
        raise ValueError("Objetivo da experiência inválido.")
    if "required" in experience and type(experience["required"]) is not bool:
        raise ValueError("required da experiência deve ser booleano.")
    action_label = experience.get("actionLabel")
    if action_label is not None and (
        not isinstance(action_label, str) or not action_label.strip() or len(action_label) > 180
    ):
        raise ValueError("actionLabel da experiência inválido.")
    ai = experience.get("ai")
    if ai is not None:
        _only_keys(ai, {"starterPrompt"}, "Configuração de IA da experiência")
        starter_prompt = ai.get("starterPrompt")
        if (
            not isinstance(starter_prompt, str)
            or not starter_prompt.strip()
            or len(starter_prompt) > 1000
        ):
            raise ValueError("starterPrompt da experiência inválido.")


def export_manifest(engine: Engine, course_id: str, version_id: str) -> dict[str, Any]:
    with Session(engine) as session:
        version = session.get(CourseVersion, version_id)
        if version is None or version.course_id != course_id or version.status != "published":
            raise ValueError("Exportação exige versão publicada do curso informado.")
        manifest = {"schema_version": 1, "course_id": course_id, "version_id": version.id, "version_number": version.version_number, "content": deepcopy(version.content)}
        manifest["sha256"] = manifest_digest(manifest)
        return verify_manifest(manifest, manifest["sha256"])


def _database_name(session: Session) -> str:
    connection = session.connection()
    if connection.dialect.name == "postgresql":
        return connection.scalar(text("SELECT current_database()"))
    if connection.dialect.name == "sqlite":
        row = next(item for item in connection.exec_driver_sql("PRAGMA database_list").mappings() if item["name"] == "main")
        if not row["file"]:
            raise ValueError("Promoção requer SQLite em arquivo, não banco em memória.")
        return Path(row["file"]).resolve().as_posix()
    raise ValueError("Promoção suporta somente PostgreSQL e SQLite.")


def _reviewer_role(session: Session, actor: User, program_id: str) -> str:
    if actor.role == "admin":
        return "admin"
    membership = session.get(ProgramMembership, (actor.id, program_id))
    if membership is None or membership.status != "active" or membership.role not in {"coordinator", "admin"}:
        raise ValueError("Ator local sem autorização de publicação em todos os programas afetados.")
    return membership.role


def import_manifest(
    engine: Engine,
    manifest: dict[str, Any],
    *,
    expected_digest: str,
    expected_database_name: str,
    actor_user_id: str,
    program_id: str,
    apply: bool = False,
) -> dict[str, Any]:
    artifact = verify_manifest(manifest, expected_digest)
    with Session(engine) as session:
        try:
            # SQLite has no row locks; serialize writes before reading the plan.
            if apply and engine.dialect.name == "sqlite":
                session.execute(text("BEGIN IMMEDIATE"))
            actual_name = _database_name(session)
            expected_name = expected_database_name
            if engine.dialect.name == "sqlite" and expected_name:
                if not Path(expected_name).is_absolute():
                    raise ValueError("SQLite exige expected_database_name como caminho absoluto.")
                expected_name = Path(expected_name).resolve().as_posix()
                matches = os.path.normcase(actual_name) == os.path.normcase(expected_name)
            else:
                matches = actual_name == expected_name
            if not expected_name or not matches:
                raise ValueError("Nome do banco conectado diverge de expected_database_name.")
            actor = session.get(User, actor_user_id)
            if actor is None or session.get(Program, program_id) is None:
                raise ValueError("Ator e programa devem existir no banco de destino.")
            role = _reviewer_role(session, actor, program_id)
            course_query = select(Course).where(Course.id == artifact["course_id"])
            course = session.scalar(course_query.with_for_update() if apply else course_query)
            linked_programs = set(session.scalars(select(ProgramCourse.program_id).where(ProgramCourse.course_id == artifact["course_id"])))
            for linked_program in linked_programs:
                _reviewer_role(session, actor, linked_program)
            versions = session.scalars(select(CourseVersion).where(CourseVersion.course_id == artifact["course_id"])).all()
            existing = session.get(CourseVersion, artifact["version_id"])
            if existing is not None:
                if existing.course_id != artifact["course_id"] or existing.version_number != artifact["version_number"] or existing.content != artifact["content"]:
                    raise ValueError("Conflito: version_id existente identifica outro curso, número ou conteúdo.")
                if existing.status not in {"published", "archived"}:
                    raise ValueError("Conflito: version_id de destino ainda está em edição/revisão.")
            elif versions and artifact["version_number"] <= max(version.version_number for version in versions):
                raise ValueError("Conflito: número da versão deve ser maior que todas as versões de destino.")
            elif course is not None and not versions:
                raise ValueError("Curso de destino ainda não versionado; execute migração/seed antes de promover.")
            published = [version for version in versions if version.status == "published"]
            if len(published) > 1:
                raise ValueError("Destino inconsistente: mais de uma versão publicada para o curso.")
            plan = {
                "dry_run": not apply,
                "database_name": actual_name,
                "sha256": artifact["sha256"],
                "course_id": artifact["course_id"],
                "version_id": artifact["version_id"],
                "version_number": artifact["version_number"],
                "program_id": program_id,
                "actor_user_id": actor.id,
                "action": "publish" if existing is None else "link_existing" if program_id not in linked_programs else "already_present",
                "will_create_course": course is None,
                "will_link_program": program_id not in linked_programs,
                "will_archive_version_ids": [version.id for version in published] if existing is None else [],
            }
            if not apply or plan["action"] == "already_present":
                session.rollback()
                return plan
            content = artifact["content"]
            if course is None:
                course = Course(id=artifact["course_id"], title=content["title"], author=content["author"], content={}, active=False)
                session.add(course)
                session.flush()
            if program_id not in linked_programs:
                session.add(ProgramCourse(program_id=program_id, course_id=course.id))
            if existing is None:
                timestamp = datetime.now(timezone.utc)
                for previous in published:
                    result = session.execute(update(CourseVersion).where(CourseVersion.id == previous.id, CourseVersion.status == "published", CourseVersion.revision == previous.revision).values(status="archived", revision=previous.revision + 1, updated_at=timestamp))
                    if result.rowcount != 1:
                        raise ValueError("Conflito concorrente: refaça o dry-run antes de promover.")
                    session.add(CourseVersionTransition(id=str(uuid4()), version_id=previous.id, from_status="published", to_status="archived", actor_user_id=actor.id, actor_role=role, occurred_at=timestamp))
                imported = CourseVersion(id=artifact["version_id"], course_id=course.id, program_id=program_id, creator_user_id=actor.id, version_number=artifact["version_number"], revision=1, status="published", content=deepcopy(content), created_at=timestamp, updated_at=timestamp)
                session.add(imported)
                session.flush()
                session.add(CourseVersionTransition(id=str(uuid4()), version_id=imported.id, from_status=None, to_status="published", actor_user_id=actor.id, actor_role=role, occurred_at=timestamp))
                course.title = content["title"]
                course.author = content["author"]
                course.content = {key: deepcopy(value) for key, value in content.items() if key not in {"id", "title", "author"}}
                course.active = True
            session.commit()
            return plan
        except IntegrityError as error:
            session.rollback()
            raise ValueError("Conflito de integridade/concorrência; importação revertida integralmente.") from error


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Promove explicitamente snapshots de cursos sem clonar banco.")
    parser.add_argument("--database-url-env", default="DATABASE_URL", help="Nome da variável de ambiente com a URL; nunca é exportada.")
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export")
    export.add_argument("--course-id", required=True)
    export.add_argument("--version-id", required=True)
    export.add_argument("--output", required=True, type=Path)
    load = commands.add_parser("import")
    load.add_argument("manifest", type=Path)
    load.add_argument("--expected-digest", required=True)
    load.add_argument("--expected-database-name", required=True)
    load.add_argument("--actor-user-id", required=True)
    load.add_argument("--program-id", required=True)
    mode = load.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--dry-run", dest="apply", action="store_false")
    load.set_defaults(apply=False)
    args = parser.parse_args(argv)
    url = os.getenv(args.database_url_env)
    if not url:
        parser.error("Defina a variável de ambiente que contém a URL do banco.")
    try:
        database = Database(url)
    except (ValueError, SQLAlchemyError):
        parser.exit(2, "Promoção recusada: URL do banco inválida. Confira a variável de ambiente.\n")
    try:
        if args.command == "export":
            manifest = export_manifest(database.engine, args.course_id, args.version_id)
            # Refuse accidental replacement of a previously reviewed artifact.
            with args.output.open("x", encoding="utf-8", newline="\n") as stream:
                json.dump(manifest, stream, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)
                stream.write("\n")
            result = {"course_id": args.course_id, "version_id": args.version_id, "sha256": manifest["sha256"], "output": str(args.output)}
        else:
            if args.manifest.stat().st_size > 2_500_000:
                raise ValueError("Manifesto excede o limite de tamanho.")
            manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
            result = import_manifest(database.engine, manifest, expected_digest=args.expected_digest, expected_database_name=args.expected_database_name, actor_user_id=args.actor_user_id, program_id=args.program_id, apply=args.apply)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    except (ValueError, OSError) as error:
        parser.exit(2, f"Promoção recusada: {error}\n")
    except SQLAlchemyError:
        parser.exit(2, "Promoção recusada: falha no banco; confira conexão/migrações. Nenhuma credencial foi exibida.\n")
    finally:
        database.dispose()


if __name__ == "__main__":
    main()
