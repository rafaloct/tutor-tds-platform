"""Program-scoped editorial workflow; public Course is a published projection."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import re
from typing import Any, Literal
from urllib.parse import urlsplit
from uuid import NAMESPACE_URL, uuid4, uuid5

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .models import Course, CourseVersion, CourseVersionTransition, MediaAsset, Program, ProgramCourse, ProgramMembership

router = APIRouter(tags=["course-editor"])
EDITOR_ROLES = {"teacher", "creator", "coordinator", "admin"}
REVIEWER_ROLES = {"coordinator", "admin"}


class CourseMaterial(BaseModel):
    """Public edition manifest; provider credentials and playback URLs never belong here."""
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, strict=True)
    id: str = Field(min_length=1, max_length=120, pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_-]*$")
    kind: Literal["pdf", "video", "link"]
    title: str = Field(min_length=1, max_length=240)
    url: str | None = Field(default=None, max_length=2000)
    media_id: str | None = Field(default=None, min_length=1, max_length=36, pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_-]*$")

    @model_validator(mode="after")
    def destination(self) -> "CourseMaterial":
        if self.kind == "video":
            if self.media_id is None or self.url is not None:
                raise ValueError("Vídeo requer somente media_id.")
        else:
            if self.url is None or self.media_id is not None:
                raise ValueError("PDF/link requer somente URL pública HTTPS.")
            parsed = urlsplit(self.url)
            host = parsed.hostname or ""
            public_host = re.fullmatch(r"(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}", host)
            if (parsed.scheme != "https" or not parsed.hostname or parsed.username is not None
                    or parsed.password is not None or "?" in self.url or "#" in self.url
                    or not public_host or host.split(".")[-1] in {"localhost", "local", "internal", "invalid", "test", "example", "home", "lan", "localdomain", "onion"}
                    or parsed.port not in {None, 443}
                    or any(char.isspace() or ord(char) < 32 for char in self.url)
                    or "\\" in self.url):
                raise ValueError("Use URL pública HTTPS sem credenciais, query ou fragmento.")
        return self


def _materials(section: dict[str, Any]) -> list[dict[str, Any]]:
    raw = section.get("materials", [])
    if not isinstance(raw, list) or len(raw) > 50:
        raise HTTPException(422, "Inclua até 50 materiais por módulo.")
    try:
        parsed = [CourseMaterial.model_validate(item).model_dump(exclude_none=True) for item in raw]
    except (ValidationError, ValueError) as error:
        raise HTTPException(422, "Material inválido: use id, kind, title e URL pública HTTPS ou media_id.") from error
    if len({item["id"] for item in parsed}) != len(parsed):
        raise HTTPException(422, "IDs de materiais devem ser únicos no módulo.")
    return parsed


def _validate_material_lineage(session: Session, record: CourseVersion) -> None:
    program = session.get(Program, record.program_id) if record.program_id else None
    for section in record.content.get("sections", []):
        for material in _materials(section):
            if material["kind"] != "video":
                continue
            media = session.scalar(select(MediaAsset).where(MediaAsset.id == material["media_id"]).with_for_update())
            if (program is None or media is None or media.status != "published"
                    or media.institution_id != program.institution_id
                    or media.program_id != record.program_id or media.course_id != record.course_id
                    or media.module_id != section["id"]):
                raise HTTPException(422, "Vídeo deve estar publicado e pertencer ao programa, curso e módulo desta edição.")


class CourseCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    course_id: str = Field(min_length=1, max_length=120, pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_-]*$")
    program_id: str = Field(min_length=1, max_length=36)
    title: str = Field(min_length=1, max_length=240)
    author: str = Field(min_length=1, max_length=240)


class VersionAction(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version_id: str = Field(min_length=1, max_length=36)
    expected_revision: int = Field(ge=1)


class DraftUpdate(VersionAction):
    title: str = Field(min_length=1, max_length=240)
    author: str = Field(min_length=1, max_length=240)
    sections: list[dict[str, Any]] = Field(max_length=500)
    downloadUrl: str | None = Field(default=None, max_length=2000)
    thumbnailUrl: str | None = Field(default=None, max_length=2000)

    @field_validator("title", "author")
    @classmethod
    def non_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Campo obrigatório.")
        return value.strip()


class VersionFork(BaseModel):
    model_config = ConfigDict(extra="forbid")
    source_version_id: str = Field(min_length=1, max_length=36)


def legacy_version_id(course_id: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"tds:course:{course_id}:legacy:v1"))


def snapshot_content(course_id: str, title: str, author: str, content: dict[str, Any], *, legacy: bool = False) -> dict[str, Any]:
    """Add identity without flattening any legacy Cartilha fields."""
    result = deepcopy(content)
    result.update(id=course_id, title=title, author=author)
    sections = result.setdefault("sections", [])
    if not isinstance(sections, list):
        raise HTTPException(422, "sections deve ser uma lista.")
    section_ids: set[str] = set()
    message_ids: set[str] = set()
    for section in sections:
        if not isinstance(section, dict):
            raise HTTPException(422, "Módulo inválido.")
        section_id = section.get("id")
        if not isinstance(section_id, str) or not section_id.strip() or len(section_id) > 120 or section_id in section_ids:
            raise HTTPException(422, "IDs de módulos devem ser únicos e não vazios.")
        section_ids.add(section_id)
        if "materials" in section:
            section["materials"] = _materials(section)
        if not isinstance(section.get("title"), str) or not section["title"].strip():
            raise HTTPException(422, "Título do módulo obrigatório.")
        messages = section.get("messages")
        if not isinstance(messages, list) or len(messages) > 5000:
            raise HTTPException(422, "Mensagens do módulo inválidas.")
        for position, message in enumerate(messages):
            if not isinstance(message, dict) or not isinstance(message.get("type"), str) or not message["type"].strip() or not isinstance(message.get("content"), str):
                raise HTTPException(422, "Mensagem requer type e content textuais.")
            if message.get("options") is not None:
                options = message["options"]
                if not isinstance(options, list) or any(not isinstance(option, dict) or not isinstance(option.get("label"), str) for option in options):
                    raise HTTPException(422, "Opções de mensagem inválidas.")
            identity = message.get("id")
            if not identity:
                identity = str(uuid5(NAMESPACE_URL, f"tds:{course_id}:{section_id}:message:{position}")) if legacy else str(uuid4())
            if not isinstance(identity, str) or len(identity) > 180 or identity in message_ids:
                raise HTTPException(422, "IDs de conteúdos devem ser únicos.")
            message_ids.add(identity)
            message["id"] = identity
            message["version_id"] = _component_version(course_id, message)
        section["version_id"] = _component_version(course_id, section)
    if len(json.dumps(result, ensure_ascii=False).encode()) > 2_000_000:
        raise HTTPException(422, "Curso excede o limite de 2 MB.")
    return result


def _component_version(course_id: str, payload: dict[str, Any]) -> str:
    value = {key: val for key, val in payload.items() if key != "version_id"}
    digest = hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()
    return str(uuid5(NAMESPACE_URL, f"tds:{course_id}:component:{digest}"))


def validate_publishable_content(content: dict[str, Any]) -> None:
    """Gate reader compatibility at review/publication, allowing partial drafts."""
    sections = content.get("sections")
    if not isinstance(sections, list) or not sections:
        raise HTTPException(422, "Inclua pelo menos um módulo antes da revisão/publicação.")
    for section_index, section in enumerate(sections, start=1):
        if not isinstance(section, dict) or not isinstance(section.get("messages"), list) or not section["messages"]:
            raise HTTPException(422, f"Módulo {section_index}: inclua pelo menos uma mensagem.")
        for message_index, message in enumerate(section["messages"], start=1):
            location = f"Módulo {section_index}, mensagem {message_index}"
            if not isinstance(message, dict) or not isinstance(message.get("type"), str) or message["type"] not in {"bot", "question", "quiz", "user"}:
                raise HTTPException(422, f"{location}: tipo deve ser bot, question, quiz ou user.")
            if not isinstance(message.get("content"), str) or not message["content"].strip():
                raise HTTPException(422, f"{location}: texto obrigatório.")
            for field in ("feedback", "explanation"):
                if message.get(field) is not None and not isinstance(message[field], str):
                    raise HTTPException(422, f"{location}: {field} deve ser texto.")
            options = message.get("options")
            minimum = 2 if message["type"] in {"question", "quiz"} else 1 if message["type"] == "user" else 0
            if options is None:
                options = []
            if not isinstance(options, list) or len(options) < minimum:
                raise HTTPException(422, f"{location}: inclua pelo menos {minimum} opção(ões).")
            for option in options:
                if not isinstance(option, dict) or not isinstance(option.get("label"), str) or not option["label"].strip():
                    raise HTTPException(422, f"{location}: cada opção exige rótulo não vazio.")
                for field in ("value", "feedback"):
                    if option.get(field) is not None and not isinstance(option[field], str):
                        raise HTTPException(422, f"{location}: {field} da opção deve ser texto.")
                if option.get("isCorrect") is not None and not isinstance(option["isCorrect"], bool):
                    raise HTTPException(422, f"{location}: isCorrect da opção deve ser booleano.")
            if message["type"] == "quiz" and not any(option.get("isCorrect") is True for option in options):
                raise HTTPException(422, f"{location}: quiz exige pelo menos uma alternativa correta.")


def latest_published_version(session: Session, course_id: str) -> CourseVersion | None:
    return session.scalar(select(CourseVersion).where(CourseVersion.course_id == course_id, CourseVersion.status == "published").order_by(CourseVersion.version_number.desc()).limit(1))


def ensure_legacy_course_version(session: Session, course: Course) -> CourseVersion:
    """Seed helper. Never replace any already-versioned content; caller commits."""
    existing = session.scalar(select(CourseVersion).where(CourseVersion.course_id == course.id).order_by(CourseVersion.version_number.desc()).limit(1))
    if existing is not None:
        return existing
    session.flush()
    record = CourseVersion(id=legacy_version_id(course.id), course_id=course.id, version_number=1, revision=1, status="published" if course.active else "archived", content=snapshot_content(course.id, course.title, course.author, course.content, legacy=True))
    session.add(record)
    session.flush()
    _audit(session, record, None, None, "seed")
    return record


def _role(session: Session, claims: dict[str, str], program_id: str | None) -> str | None:
    if claims["role"] == "admin":
        return "admin"
    if program_id is None:
        return None
    membership = session.get(ProgramMembership, (claims["sub"], program_id))
    return membership.role if membership is not None and membership.status == "active" else None


def _program_for(session: Session, version: CourseVersion, claims: dict[str, str]) -> str | None:
    if version.program_id is not None and (version.status not in {"published", "archived"} or _role(session, claims, version.program_id) in EDITOR_ROLES):
        return version.program_id
    links = session.scalars(select(ProgramCourse.program_id).where(ProgramCourse.course_id == version.course_id).order_by(ProgramCourse.program_id)).all()
    return next((identity for identity in links if _role(session, claims, identity) in EDITOR_ROLES), None)


def _capabilities(session: Session, version: CourseVersion, claims: dict[str, str]) -> dict[str, bool]:
    role = _role(session, claims, _program_for(session, version, claims))
    reviewer = role in REVIEWER_ROLES
    owner = role in EDITOR_ROLES and version.creator_user_id == claims["sub"]
    # Publishing changes the shared public projection; require authority in every
    # program offering that course, so a local coordinator cannot affect others.
    links = session.scalars(select(ProgramCourse.program_id).where(ProgramCourse.course_id == version.course_id)).all()
    can_release = reviewer and all(_role(session, claims, program_id) in REVIEWER_ROLES for program_id in links)
    return {
        "can_edit": version.status == "draft" and (owner or reviewer),
        "can_submit": version.status == "draft" and (owner or reviewer),
        "can_publish": version.status == "in_review" and can_release,
        "can_archive": version.status == "published" and can_release,
        "can_fork": version.status in {"published", "archived"} and role in EDITOR_ROLES,
    }


def _visible(session: Session, version: CourseVersion, claims: dict[str, str]) -> bool:
    role = _role(session, claims, _program_for(session, version, claims))
    return role in EDITOR_ROLES and (version.status in {"published", "archived"} or role in REVIEWER_ROLES or version.creator_user_id == claims["sub"])


def _view(session: Session, version: CourseVersion, claims: dict[str, str]) -> dict[str, Any]:
    return {**deepcopy(version.content), "course_id": version.course_id, "program_id": _program_for(session, version, claims), "version_id": version.id, "version_number": version.version_number, "revision": version.revision, "status": version.status, "created_at": version.created_at, "updated_at": version.updated_at, **_capabilities(session, version, claims)}


def _version(session: Session, course_id: str, version_id: str, claims: dict[str, str]) -> CourseVersion:
    record = session.get(CourseVersion, version_id)
    if record is None or record.course_id != course_id or not _visible(session, record, claims):
        raise HTTPException(404, "Versão não encontrada.")
    return record


def _audit(session: Session, version: CourseVersion, previous: str | None, actor: str | None, role: str) -> None:
    session.add(CourseVersionTransition(id=str(uuid4()), version_id=version.id, from_status=previous, to_status=version.status, actor_user_id=actor, actor_role=role))


def _commit(session: Session) -> None:
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(409, "Curso alterado por outra pessoa ou identificador já existente. Recarregue.") from error


def _cas(session: Session, record: CourseVersion, expected_revision: int, **changes: Any) -> None:
    result = session.execute(update(CourseVersion).where(CourseVersion.id == record.id, CourseVersion.revision == expected_revision, CourseVersion.status == record.status).values(**changes, revision=expected_revision + 1, updated_at=datetime.now(timezone.utc)), execution_options={"synchronize_session": False})
    if result.rowcount != 1:
        session.rollback()
        raise HTTPException(409, "Versão alterada por outra pessoa. Recarregue antes de salvar.")
    session.refresh(record)


@router.get("/editor/context")
def editor_context(request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        return {"programs": [{"id": program.id, "name": program.name, "role": role, "can_create": True, "can_publish": role in REVIEWER_ROLES} for program in session.scalars(select(Program).order_by(Program.name)) if (role := _role(session, claims, program.id)) in EDITOR_ROLES]}


@router.get("/editor/courses")
def editor_courses(request: Request, program_id: str = Query(min_length=1, max_length=36), claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        if _role(session, claims, program_id) not in EDITOR_ROLES:
            raise HTTPException(403, "Vínculo editorial não autorizado.")
        versions = session.scalars(select(CourseVersion).join(ProgramCourse, ProgramCourse.course_id == CourseVersion.course_id).where(ProgramCourse.program_id == program_id).order_by(CourseVersion.version_number.desc())).all()
        found: dict[str, dict[str, Any]] = {}
        for version in versions:
            if version.course_id not in found and (version.program_id in {None, program_id} or version.status in {"published", "archived"}) and _visible(session, version, claims):
                found[version.course_id] = _view(session, version, claims)
        return {"courses": list(found.values())}


@router.get("/editor/courses/{course_id}")
def editor_course(course_id: str, request: Request, version_id: str | None = None, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        if version_id is not None:
            record = _version(session, course_id, version_id, claims)
        else:
            record = next((version for version in session.scalars(select(CourseVersion).where(CourseVersion.course_id == course_id).order_by(CourseVersion.version_number.desc())) if _visible(session, version, claims)), None)
            if record is None:
                raise HTTPException(404, "Curso não encontrado.")
        result = _view(session, record, claims)
        result["versions"] = [{"version_id": item.id, "version_number": item.version_number, "status": item.status, "revision": item.revision} for item in session.scalars(select(CourseVersion).where(CourseVersion.course_id == course_id).order_by(CourseVersion.version_number.desc())) if _visible(session, item, claims)]
        return result


@router.post("/courses", status_code=201)
def create_course(payload: CourseCreate, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        role = _role(session, claims, payload.program_id)
        if role not in EDITOR_ROLES:
            raise HTTPException(403, "Vínculo editorial não autorizado.")
        if session.get(Program, payload.program_id) is None:
            raise HTTPException(404, "Programa não encontrado.")
        if session.get(Course, payload.course_id) is not None:
            raise HTTPException(409, "Identificador de curso já cadastrado.")
        course = Course(id=payload.course_id, title=payload.title, author=payload.author, content={"sections": []}, active=False)
        session.add(course)
        try:
            session.flush()
        except IntegrityError as error:
            raise HTTPException(409, "Identificador de curso já cadastrado.") from error
        session.add(ProgramCourse(program_id=payload.program_id, course_id=course.id))
        record = CourseVersion(id=str(uuid4()), course_id=course.id, program_id=payload.program_id, creator_user_id=claims["sub"], version_number=1, revision=1, status="draft", content=snapshot_content(course.id, payload.title, payload.author, {"sections": []}))
        session.add(record)
        session.flush()
        _audit(session, record, None, claims["sub"], role)
        _commit(session)
        return _view(session, record, claims)


@router.patch("/courses/{course_id}")
def update_course(course_id: str, payload: DraftUpdate, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        record = _version(session, course_id, payload.version_id, claims)
        if not _capabilities(session, record, claims)["can_edit"]:
            raise HTTPException(403, "Somente rascunhos autorizados podem ser editados.")
        content = deepcopy(record.content)
        content.update(payload.model_dump(exclude={"version_id", "expected_revision"}, exclude_unset=True))
        _cas(session, record, payload.expected_revision, content=snapshot_content(course_id, payload.title, payload.author, content))
        _commit(session)
        return _view(session, record, claims)


@router.post("/courses/{course_id}/versions", status_code=201)
def fork_course(course_id: str, payload: VersionFork, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        session.scalar(select(Course).where(Course.id == course_id).with_for_update())
        source = _version(session, course_id, payload.source_version_id, claims)
        if not _capabilities(session, source, claims)["can_fork"]:
            raise HTTPException(403, "Somente versões publicadas ou arquivadas podem originar rascunho.")
        number = session.scalar(select(func.max(CourseVersion.version_number)).where(CourseVersion.course_id == course_id)) + 1
        record = CourseVersion(id=str(uuid4()), course_id=course_id, program_id=_program_for(session, source, claims), creator_user_id=claims["sub"], source_version_id=source.id, version_number=number, revision=1, status="draft", content=deepcopy(source.content))
        session.add(record)
        try:
            session.flush()
        except IntegrityError as error:
            raise HTTPException(409, "Outra versão foi criada. Recarregue.") from error
        _audit(session, record, None, claims["sub"], _role(session, claims, record.program_id) or "admin")
        _commit(session)
        return _view(session, record, claims)


def _transition(course_id: str, payload: VersionAction, request: Request, claims: dict[str, str], action: str) -> dict[str, Any]:
    with Session(request.app.state.database.engine) as session:
        course = session.scalar(select(Course).where(Course.id == course_id).with_for_update())
        record = _version(session, course_id, payload.version_id, claims)
        if record.revision != payload.expected_revision:
            raise HTTPException(409, "Versão alterada por outra pessoa. Recarregue.")
        if not _capabilities(session, record, claims)[f"can_{action}"]:
            raise HTTPException(403, "Transição editorial não autorizada.")
        if action in {"submit", "publish"}:
            validate_publishable_content(record.content)
            _validate_material_lineage(session, record)
        role = _role(session, claims, _program_for(session, record, claims)) or "admin"
        previous = record.status
        target = {"submit": "in_review", "publish": "published", "archive": "archived"}[action]
        if action == "publish":
            latest_release = session.scalar(select(func.max(CourseVersion.version_number)).where(CourseVersion.course_id == course_id, CourseVersion.status.in_(["published", "archived"])))
            if latest_release is not None and latest_release >= record.version_number:
                raise HTTPException(409, "Uma versão mais recente já foi publicada.")
            published = latest_published_version(session, course_id)
            if published is not None:
                _cas(session, published, published.revision, status="archived")
                _audit(session, published, "published", claims["sub"], role)
            course.title = record.content["title"]
            course.author = record.content["author"]
            course.content = {key: deepcopy(value) for key, value in record.content.items() if key not in {"id", "title", "author"}}
            course.active = True
        elif action == "archive":
            course.active = False
        _cas(session, record, payload.expected_revision, status=target)
        _audit(session, record, previous, claims["sub"], role)
        _commit(session)
        return _view(session, record, claims)


@router.post("/courses/{course_id}/submit")
def submit_course(course_id: str, payload: VersionAction, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    return _transition(course_id, payload, request, claims, "submit")


@router.post("/courses/{course_id}/publish")
def publish_course(course_id: str, payload: VersionAction, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    return _transition(course_id, payload, request, claims, "publish")


@router.post("/courses/{course_id}/archive")
def archive_course(course_id: str, payload: VersionAction, request: Request, claims: dict[str, str] = Depends(access_claims)) -> dict[str, Any]:
    return _transition(course_id, payload, request, claims, "archive")
