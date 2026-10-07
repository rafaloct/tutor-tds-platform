from __future__ import annotations

import hashlib
import json
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, require_roles
from .database import Database
from .evidence import _staff
from .learning_context import LearningContext, resolve_student_context
from .models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    Classroom,
    Course,
    CourseVersion,
    Enrollment,
    LearningEventRecord,
)

router = APIRouter(prefix="/assessment-attempts", tags=["assessment-sync"])
content_router = APIRouter(prefix="/assessment-contents", tags=["assessment-sync"])
context_router = APIRouter(tags=["dynamic-activity"])
student_claims = require_roles("student")
AttemptMode = Literal["quiz", "exam"]
AttemptOrigin = Literal["practice", "published_block"]
PUBLISHED_CONTENT_PREFIX = "published-block:"
MAX_PUBLISHED_OPTIONS = 20

CONTEXT_FIELDS = (
    "organization_id",
    "program_id",
    "class_id",
    "membership_id",
    "enrollment_id",
    "legacy_enrollment_id",
    "course_version_id",
    "section_id",
    "section_version_id",
    "block_id",
    "block_version_id",
)
EVENT_CONTEXT_FIELDS = (
    "organization_id",
    "program_id",
    "class_id",
    "course_version_id",
    "section_id",
    "section_version_id",
    "block_id",
    "block_version_id",
)


class AssessmentQuestionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    question: str = Field(min_length=1, max_length=1_000)
    options: list[str] = Field(min_length=2, max_length=8)
    correct_index: int = Field(ge=0, le=7)
    explanation: str = Field(default="", max_length=2_000)
    topic: str = Field(min_length=1, max_length=240)

    @field_validator("question", "topic")
    @classmethod
    def meaningful_text(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("texto obrigatório")
        if any(ord(character) < 32 and character not in "\n\t" for character in normalized):
            raise ValueError("texto contém controles inválidos")
        return normalized

    @field_validator("explanation")
    @classmethod
    def safe_explanation(cls, value: str) -> str:
        normalized = value.strip()
        if any(ord(character) < 32 and character not in "\n\t" for character in normalized):
            raise ValueError("texto contém controles inválidos")
        return normalized

    @field_validator("options")
    @classmethod
    def structured_options(cls, value: list[str]) -> list[str]:
        normalized = [item.strip() for item in value]
        if any(not item or len(item) > 500 for item in normalized):
            raise ValueError("alternativas devem ter 1 a 500 caracteres")
        return normalized

    @model_validator(mode="after")
    def valid_correct_index(self) -> "AssessmentQuestionInput":
        if self.correct_index >= len(self.options):
            raise ValueError("correct_index fora das alternativas")
        return self


class AssessmentContentUpsert(BaseModel):
    model_config = ConfigDict(extra="forbid")

    course_id: str = Field(min_length=1, max_length=120)
    topic: str = Field(min_length=1, max_length=240)
    mode: AttemptMode
    title: str = Field(min_length=1, max_length=240)
    duration_seconds: int = Field(ge=0, le=86_400)
    questions: list[AssessmentQuestionInput] = Field(min_length=1, max_length=100)

    @field_validator("topic", "title")
    @classmethod
    def labels(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized or any(ord(character) < 32 for character in normalized):
            raise ValueError("rótulo inválido")
        return normalized

    @model_validator(mode="after")
    def duration_for_mode(self) -> "AssessmentContentUpsert":
        if self.mode == "exam" and self.duration_seconds < 60:
            raise ValueError("simulado deve ter duração mínima de 60 segundos")
        if self.mode == "quiz" and self.duration_seconds != 0:
            raise ValueError("quiz sem cronômetro deve usar duration_seconds zero")
        return self


class AssessmentQuestionPublic(BaseModel):
    question: str
    options: list[str]
    topic: str


class AssessmentAnswerKeyItem(BaseModel):
    correct_index: int
    explanation: str


class PublishedBlockAnswerKeyItem(BaseModel):
    correct_indices: list[int]
    explanation: str
    graded: bool


class AssessmentContentResponse(BaseModel):
    assessment_content_id: str
    course_id: str
    topic: str
    mode: AttemptMode
    title: str
    duration_seconds: int
    questions: list[AssessmentQuestionPublic]
    answer_key: list[AssessmentAnswerKeyItem | PublishedBlockAnswerKeyItem] | None
    created_at: datetime


class AssessmentAttemptUpsert(BaseModel):
    model_config = ConfigDict(extra="forbid")

    course_id: str = Field(min_length=1, max_length=120)
    origin: AttemptOrigin = "practice"
    assessment_content_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    )
    topic: str = Field(min_length=1, max_length=240)
    mode: AttemptMode
    organization_id: str | None = Field(default=None, min_length=1, max_length=36)
    program_id: str | None = Field(default=None, min_length=1, max_length=36)
    class_id: str | None = Field(default=None, min_length=1, max_length=36)
    membership_id: str | None = Field(default=None, min_length=1, max_length=36)
    enrollment_id: str | None = Field(default=None, min_length=1, max_length=36)
    legacy_enrollment_id: str | None = Field(default=None, min_length=1, max_length=36)
    course_version_id: str | None = Field(default=None, min_length=1, max_length=36)
    section_id: str | None = Field(default=None, min_length=1, max_length=120)
    section_version_id: str | None = Field(default=None, min_length=1, max_length=36)
    block_id: str | None = Field(default=None, min_length=1, max_length=180)
    block_version_id: str | None = Field(default=None, min_length=1, max_length=36)
    revision: int = Field(ge=1, le=2_147_483_647)
    answers: dict[str, int] = Field(default_factory=dict, max_length=500)
    marked: list[int] = Field(default_factory=list, max_length=500)
    current_index: int = Field(ge=0, le=999)
    remaining_seconds: int = Field(ge=0, le=86_400)
    completed: bool
    score: int = Field(ge=0, le=1_000)
    updated_at: datetime

    @field_validator("topic")
    @classmethod
    def structured_topic(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized or any(ord(character) < 32 for character in normalized):
            raise ValueError("topic deve ser um rótulo curto sem controles")
        return normalized

    @field_validator("answers")
    @classmethod
    def structured_answers(cls, value: dict[str, int]) -> dict[str, int]:
        for question, answer in value.items():
            if (
                not question.isdigit()
                or len(question) > 3
                or str(int(question)) != question
            ):
                raise ValueError("answers usa índices inteiros canônicos")
            if not 0 <= int(question) <= 999 or not 0 <= answer <= 19:
                raise ValueError("índice de questão ou alternativa fora do limite")
        return dict(sorted(value.items(), key=lambda item: int(item[0])))

    @field_validator("marked")
    @classmethod
    def structured_marked(cls, value: list[int]) -> list[int]:
        if any(item < 0 or item > 999 for item in value):
            raise ValueError("marked contém índice fora do limite")
        if len(set(value)) != len(value):
            raise ValueError("marked não aceita índices duplicados")
        return sorted(value)

    @model_validator(mode="after")
    def consistent_state(self) -> "AssessmentAttemptUpsert":
        if self.updated_at.tzinfo is None or self.updated_at.utcoffset() is None:
            raise ValueError("updated_at deve conter fuso horário")
        self.updated_at = self.updated_at.astimezone(timezone.utc)
        if not self.completed and self.score != 0:
            raise ValueError("tentativa incompleta deve ter score zero")
        if self.completed and self.remaining_seconds != 0:
            raise ValueError("tentativa concluída deve ter remaining_seconds zero")
        context = [getattr(self, field) for field in CONTEXT_FIELDS]
        if self.origin == "practice" and any(value is not None for value in context):
            raise ValueError("tentativa de prática não aceita linhagem contextual")
        if self.origin == "published_block":
            if any(value is None for value in context):
                raise ValueError("bloco publicado exige LearningContext e linhagem completos")
            if self.mode != "quiz":
                raise ValueError("bloco publicado usa mode quiz")
            if self.current_index != 0 or self.remaining_seconds != 0:
                raise ValueError("bloco publicado possui uma questão sem cronômetro")
        return self


class AssessmentAttemptResponse(AssessmentAttemptUpsert):
    attempt_id: str


class AssessmentAttemptPage(BaseModel):
    attempts: list[AssessmentAttemptResponse]
    total: int
    limit: int
    offset: int


@content_router.put(
    "/{content_id}",
    response_model=AssessmentContentResponse,
)
def register_assessment_content(
    payload: AssessmentContentUpsert,
    request: Request,
    response: Response,
    content_id: str = Path(
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    ),
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentContentResponse:
    database: Database = request.app.state.database
    owner_id = claims["sub"]
    if content_id.startswith(PUBLISHED_CONTENT_PREFIX):
        raise HTTPException(
            status_code=422,
            detail={"code": "assessment_content_namespace_reserved"},
        )
    with Session(database.engine) as session:
        _require_course_access(session, owner_id, payload.course_id)
        digest, questions, answer_key = _content_parts(payload)
        existing = session.get(AssessmentContentRecord, content_id)
        if existing is not None:
            if existing.owner_id != owner_id:
                raise HTTPException(404, "Conteúdo de avaliação não encontrado.")
            if existing.content_digest != digest:
                raise HTTPException(
                    status_code=409,
                    detail={"code": "assessment_content_immutable"},
                )
            return _content_response(existing, include_answer_key=False)
        record = AssessmentContentRecord(
            id=content_id,
            origin="practice",
            owner_id=owner_id,
            course_id=payload.course_id,
            topic=payload.topic,
            mode=payload.mode,
            title=payload.title,
            duration_seconds=payload.duration_seconds,
            questions=questions,
            answer_key=answer_key,
            content_digest=digest,
        )
        session.add(record)
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            concurrent = session.get(AssessmentContentRecord, content_id)
            if concurrent is None or concurrent.owner_id != owner_id:
                raise HTTPException(404, "Conteúdo de avaliação não encontrado.")
            if concurrent.content_digest != digest:
                raise HTTPException(
                    status_code=409,
                    detail={"code": "assessment_content_immutable"},
                )
            return _content_response(concurrent, include_answer_key=False)
        response.status_code = 201
        return _content_response(record, include_answer_key=False)


@content_router.get(
    "/{content_id}",
    response_model=AssessmentContentResponse,
)
def get_assessment_content_preview(
    request: Request,
    content_id: str = Path(
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    ),
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentContentResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        record = _owned_content(session, content_id, claims["sub"])
        if record.origin != "practice":
            raise HTTPException(404, "Conteúdo de avaliação não encontrado.")
        return _content_response(record, include_answer_key=False)


@router.put(
    "/{attempt_id}",
    response_model=AssessmentAttemptResponse,
)
def upsert_attempt(
    payload: AssessmentAttemptUpsert,
    request: Request,
    response: Response,
    attempt_id: str = Path(
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    ),
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentAttemptResponse:
    database: Database = request.app.state.database
    owner_id = claims["sub"]
    if payload.score != 0:
        raise HTTPException(422, "score é calculado pelo servidor; envie zero.")
    if payload.origin == "published_block":
        server_time = datetime.now(timezone.utc)
        if payload.updated_at > server_time + timedelta(minutes=5):
            raise HTTPException(
                status_code=422,
                detail={
                    "code": "future_updated_at",
                    "server_time": server_time.isoformat().replace("+00:00", "Z"),
                    "max_future_seconds": 300,
                },
            )
    with Session(database.engine) as session:
        existing = session.get(AssessmentAttemptRecord, attempt_id)
        if existing is not None and existing.owner_id != owner_id:
            raise HTTPException(404, "Tentativa não encontrada.")
        if existing is not None and (
            existing.origin != payload.origin
            or (
                payload.origin == "practice"
                and (
                    existing.course_id != payload.course_id
                    or existing.assessment_content_id
                    != payload.assessment_content_id
                    or existing.topic != payload.topic
                    or existing.mode != payload.mode
                )
            )
        ):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "attempt_identity_conflict",
                    "current_revision": existing.revision,
                },
            )

        if payload.origin == "practice":
            _require_legacy_student(claims)
            _require_course_access(session, owner_id, payload.course_id)
            content = _require_attempt_content(session, owner_id, payload)
            context: dict[str, str | None] = {
                field: None for field in CONTEXT_FIELDS
            }
        else:
            _require_dynamic_activity(request)
            if payload.assessment_content_id is not None:
                raise HTTPException(
                    status_code=422,
                    detail={"code": "published_block_content_is_server_owned"},
                )
            context = _resolve_published_context(session, owner_id, payload)
            content = _published_block_content(
                session, owner_id, payload, context
            )
            _validate_attempt_against_content(payload, content)
            if payload.completed and set(payload.answers) != {"0"}:
                raise HTTPException(
                    422, "Conclusão do bloco publicado exige uma resposta."
                )
        values = _values(payload, content, context)
        if payload.origin == "published_block":
            expected_attempt_id = _published_attempt_id(owner_id, values)
            if attempt_id != expected_attempt_id:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": "canonical_attempt_id_required",
                        "expected_attempt_id": expected_attempt_id,
                    },
                )

        if existing is None:
            if payload.origin == "published_block":
                contextual = _published_attempt_for_context(
                    session, owner_id, values
                )
                if contextual is not None:
                    _published_attempt_conflict(contextual)
            if payload.revision != 1:
                _revision_conflict(current_revision=0)
            record = AssessmentAttemptRecord(
                attempt_id=attempt_id,
                owner_id=owner_id,
                **values,
            )
            session.add(record)
            _record_completion_evidence(
                session, attempt_id, owner_id, values, content
            )
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                concurrent = session.get(AssessmentAttemptRecord, attempt_id)
                if concurrent is None or concurrent.owner_id != owner_id:
                    if payload.origin == "published_block":
                        contextual = _published_attempt_for_context(
                            session, owner_id, values
                        )
                        if contextual is not None:
                            _published_attempt_conflict(contextual)
                    raise HTTPException(404, "Tentativa não encontrada.")
                if concurrent.revision == payload.revision and _same_state(concurrent, values):
                    return _attempt_response(concurrent)
                _revision_conflict(current_revision=concurrent.revision)
            response.status_code = 201
            return _attempt_response(record)

        if not _same_identity(existing, values):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "attempt_identity_conflict",
                    "current_revision": existing.revision,
                },
            )
        if existing.revision == payload.revision:
            if _same_state(existing, values):
                return _attempt_response(existing)
            _revision_conflict(current_revision=existing.revision)
        if existing.completed:
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "completed_attempt",
                    "current_revision": existing.revision,
                },
            )
        if payload.revision != existing.revision + 1:
            _revision_conflict(current_revision=existing.revision)
        existing_updated_at = existing.updated_at
        if existing_updated_at.tzinfo is None or existing_updated_at.utcoffset() is None:
            existing_updated_at = existing_updated_at.replace(tzinfo=timezone.utc)
        if payload.updated_at < existing_updated_at.astimezone(timezone.utc):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "updated_at_conflict",
                    "current_revision": existing.revision,
                    "current_updated_at": existing_updated_at.isoformat(),
                },
            )

        statement = (
            update(AssessmentAttemptRecord)
            .where(
                AssessmentAttemptRecord.attempt_id == attempt_id,
                AssessmentAttemptRecord.owner_id == owner_id,
                AssessmentAttemptRecord.revision == existing.revision,
            )
            .values(**values)
            .execution_options(synchronize_session=False)
        )
        result = session.execute(statement)
        if result.rowcount != 1:
            session.rollback()
            concurrent = session.get(AssessmentAttemptRecord, attempt_id)
            if (
                concurrent is not None
                and concurrent.owner_id == owner_id
                and concurrent.revision == payload.revision
                and _same_state(concurrent, values)
            ):
                return _attempt_response(concurrent)
            _revision_conflict(current_revision=concurrent.revision if concurrent else 0)
        _record_completion_evidence(
            session, attempt_id, owner_id, values, content
        )
        session.commit()
        record = session.get(AssessmentAttemptRecord, attempt_id)
        if record is None:
            raise HTTPException(409, "Tentativa não pôde ser recuperada após atualização.")
        return _attempt_response(record)


@router.get(
    "/{attempt_id}/content",
    response_model=AssessmentContentResponse,
)
def get_attempt_content(
    request: Request,
    attempt_id: str = Path(
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    ),
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentContentResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        attempt = session.get(AssessmentAttemptRecord, attempt_id)
        if (
            attempt is None
            or attempt.owner_id != claims["sub"]
            or attempt.origin != "practice"
        ):
            raise HTTPException(404, "Tentativa não encontrada.")
        if attempt.assessment_content_id is None:
            raise HTTPException(
                status_code=409,
                detail={"code": "legacy_attempt_without_content"},
            )
        content = _owned_content(
            session, attempt.assessment_content_id, claims["sub"]
        )
        if content.origin != "practice":
            raise HTTPException(
                status_code=409,
                detail={"code": "published_block_content_is_server_owned"},
            )
        return _content_response(content, include_answer_key=attempt.completed)


@router.get("/{attempt_id}", response_model=AssessmentAttemptResponse)
def get_attempt(
    request: Request,
    attempt_id: str = Path(
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    ),
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentAttemptResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        record = session.get(AssessmentAttemptRecord, attempt_id)
        if (
            record is None
            or record.owner_id != claims["sub"]
            or record.origin != "practice"
        ):
            raise HTTPException(404, "Tentativa não encontrada.")
        return _attempt_response(record)


@router.get("", response_model=AssessmentAttemptPage)
def list_attempts(
    request: Request,
    course_id: str | None = Query(default=None, min_length=1, max_length=120),
    mode: AttemptMode | None = None,
    completed: bool | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentAttemptPage:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        filters = [
            AssessmentAttemptRecord.owner_id == claims["sub"],
            AssessmentAttemptRecord.origin == "practice",
        ]
        if course_id is not None:
            filters.append(AssessmentAttemptRecord.course_id == course_id)
        if mode is not None:
            filters.append(AssessmentAttemptRecord.mode == mode)
        if completed is not None:
            filters.append(AssessmentAttemptRecord.completed.is_(completed))
        total = session.scalar(
            select(func.count()).select_from(AssessmentAttemptRecord).where(*filters)
        ) or 0
        records = session.scalars(
            select(AssessmentAttemptRecord)
            .where(*filters)
            .order_by(
                AssessmentAttemptRecord.updated_at.desc(),
                AssessmentAttemptRecord.attempt_id,
            )
            .offset(offset)
            .limit(limit)
        ).all()
        return AssessmentAttemptPage(
            attempts=[_attempt_response(record) for record in records],
            total=total,
            limit=limit,
            offset=offset,
        )


@context_router.get(
    "/classes/{class_id}/assessment-attempts",
    response_model=AssessmentAttemptPage,
)
def list_own_published_attempts(
    class_id: str,
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentAttemptPage:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        context = resolve_student_context(session, class_id, claims["sub"]).context
        return _contextual_page(
            session, context, claims["sub"], limit=limit, offset=offset
        )


@context_router.get(
    "/classes/{class_id}/assessment-attempts/{attempt_id}",
    response_model=AssessmentAttemptResponse,
)
def get_own_published_attempt(
    class_id: str,
    attempt_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentAttemptResponse:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        context = resolve_student_context(session, class_id, claims["sub"]).context
        return _attempt_response(
            _contextual_attempt(session, context, claims["sub"], attempt_id)
        )


@context_router.get(
    "/classes/{class_id}/assessment-attempts/{attempt_id}/content",
    response_model=AssessmentContentResponse,
)
def get_own_published_attempt_content(
    class_id: str,
    attempt_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentContentResponse:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        context = resolve_student_context(session, class_id, claims["sub"]).context
        attempt = _contextual_attempt(
            session, context, claims["sub"], attempt_id
        )
        return _contextual_content(session, attempt)


@context_router.get(
    "/classes/{class_id}/students/{owner_id}/assessment-attempts",
    response_model=AssessmentAttemptPage,
)
def list_student_published_attempts(
    class_id: str,
    owner_id: str,
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentAttemptPage:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        classroom = _staff_classroom(session, class_id, claims)
        return _staff_contextual_page(
            session, classroom, owner_id, limit=limit, offset=offset
        )


@context_router.get(
    "/classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}",
    response_model=AssessmentAttemptResponse,
)
def get_student_published_attempt(
    class_id: str,
    owner_id: str,
    attempt_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentAttemptResponse:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        classroom = _staff_classroom(session, class_id, claims)
        return _attempt_response(
            _staff_contextual_attempt(
                session, classroom, owner_id, attempt_id
            )
        )


@context_router.get(
    "/classes/{class_id}/students/{owner_id}/assessment-attempts/{attempt_id}/content",
    response_model=AssessmentContentResponse,
)
def get_student_published_attempt_content(
    class_id: str,
    owner_id: str,
    attempt_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> AssessmentContentResponse:
    _require_dynamic_activity(request)
    with Session(request.app.state.database.engine) as session:
        classroom = _staff_classroom(session, class_id, claims)
        attempt = _staff_contextual_attempt(
            session, classroom, owner_id, attempt_id
        )
        return _contextual_content(session, attempt)


def _require_course_access(session: Session, owner_id: str, course_id: str) -> None:
    course = session.get(Course, course_id)
    enrollment = session.scalar(
        select(Enrollment.id).where(
            Enrollment.user_id == owner_id,
            Enrollment.course_id == course_id,
            Enrollment.status == "active",
        )
    )
    if course is None or not course.active or enrollment is None:
        raise HTTPException(403, "Matrícula ativa no curso é obrigatória.")


def _require_legacy_student(claims: dict[str, str]) -> None:
    if claims["role"] != "student":
        raise HTTPException(403, "Acesso não autorizado para esta função.")


def _require_dynamic_activity(request: Request) -> None:
    settings = request.app.state.settings
    if not (
        settings.learning_context_enabled and settings.dynamic_activity_enabled
    ):
        raise HTTPException(
            404, "Atividades dinâmicas contextuais não habilitadas neste ambiente."
        )


def _resolve_published_context(
    session: Session,
    owner_id: str,
    payload: AssessmentAttemptUpsert,
) -> dict[str, str | None]:
    snapshot = resolve_student_context(session, payload.class_id or "", owner_id)
    context = snapshot.context
    expected = {
        "organization_id": context.organization_id,
        "program_id": context.program_id,
        "class_id": context.cohort_id,
        "membership_id": context.membership_id,
        "enrollment_id": context.enrollment_id,
        "legacy_enrollment_id": context.legacy_enrollment_id,
        "course_version_id": context.course_version_id,
        "section_id": payload.section_id,
        "section_version_id": payload.section_version_id,
        "block_id": payload.block_id,
        "block_version_id": payload.block_version_id,
    }
    supplied = {field: getattr(payload, field) for field in CONTEXT_FIELDS}
    relational_fields = CONTEXT_FIELDS[:7]
    if payload.course_id != context.course_id or any(
        supplied[field] != expected[field] for field in relational_fields
    ):
        raise HTTPException(
            status_code=409,
            detail={"code": "learning_context_conflict"},
        )
    return expected


def _published_block_content(
    session: Session,
    owner_id: str,
    payload: AssessmentAttemptUpsert,
    context: dict[str, str | None],
) -> AssessmentContentRecord:
    version = session.get(CourseVersion, context["course_version_id"])
    if (
        version is None
        or version.course_id != payload.course_id
        or version.status not in {"published", "archived"}
    ):
        raise HTTPException(409, "A edição fixada da turma não está disponível.")
    sections = version.content.get("sections")
    if not isinstance(sections, list):
        raise HTTPException(409, "Snapshot publicado possui estrutura inválida.")
    section = next(
        (
            item
            for item in sections
            if isinstance(item, dict) and item.get("id") == payload.section_id
        ),
        None,
    )
    if section is None:
        raise HTTPException(404, "Bloco publicado não encontrado.")
    if section.get("version_id") != payload.section_version_id:
        raise HTTPException(
            status_code=409,
            detail={"code": "published_block_snapshot_conflict"},
        )
    messages = section.get("messages")
    if not isinstance(messages, list):
        raise HTTPException(409, "Snapshot publicado possui estrutura inválida.")
    block = next(
        (
            item
            for item in messages
            if isinstance(item, dict) and item.get("id") == payload.block_id
        ),
        None,
    )
    if block is None:
        raise HTTPException(404, "Bloco publicado não encontrado.")
    if block.get("version_id") != payload.block_version_id:
        raise HTTPException(
            status_code=409,
            detail={"code": "published_block_snapshot_conflict"},
        )
    block_type = block.get("type")
    options = block.get("options")
    if block_type not in {"question", "quiz"} or not isinstance(options, list):
        raise HTTPException(422, "O bloco publicado não é uma atividade suportada.")
    labels = [
        option.get("label") if isinstance(option, dict) else None
        for option in options
    ]
    if not 2 <= len(labels) <= MAX_PUBLISHED_OPTIONS or any(
        not isinstance(label, str) or not label.strip() for label in labels
    ):
        raise HTTPException(409, "Snapshot publicado possui alternativas inválidas.")
    topic = section.get("title")
    question = block.get("content")
    if (
        not isinstance(topic, str)
        or not topic.strip()
        or not isinstance(question, str)
        or not question.strip()
    ):
        raise HTTPException(409, "Snapshot publicado possui texto inválido.")
    normalized_topic = topic.strip()
    if payload.topic != normalized_topic:
        raise HTTPException(
            status_code=409,
            detail={"code": "published_block_identity_conflict"},
        )

    correct_indices = [
        index
        for index, option in enumerate(options)
        if isinstance(option, dict) and option.get("isCorrect") is True
    ]
    if block_type == "quiz" and not correct_indices:
        raise HTTPException(409, "Quiz publicado não possui gabarito válido.")
    answer_key: list[dict[str, object]] = [
        {
            "correct_indices": correct_indices if block_type == "quiz" else [],
            "explanation": (
                block.get("explanation")
                if isinstance(block.get("explanation"), str)
                else ""
            ),
            "graded": block_type == "quiz",
        }
    ]
    questions: list[dict[str, object]] = [
        {"question": question.strip(), "options": labels, "topic": normalized_topic}
    ]
    canonical = {
        "origin": "published_block",
        "course_id": payload.course_id,
        **context,
        "topic": normalized_topic,
        "mode": "quiz",
        "title": question.strip()[:240],
        "duration_seconds": 0,
        "questions": questions,
        "answer_key": answer_key,
    }
    serialized = json.dumps(
        canonical, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    digest = hashlib.sha256(serialized.encode()).hexdigest()
    identity = hashlib.sha256(
        json.dumps(
            [
                owner_id,
                context["course_version_id"],
                context["section_id"],
                context["section_version_id"],
                context["block_id"],
                context["block_version_id"],
            ],
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    content_id = f"published-block:{identity}"
    existing = session.get(AssessmentContentRecord, content_id)
    if existing is not None:
        if (
            existing.owner_id != owner_id
            or existing.course_id != payload.course_id
            or existing.origin != "published_block"
            or existing.content_digest != digest
        ):
            raise HTTPException(
                status_code=409,
                detail={"code": "published_block_content_conflict"},
            )
        return existing
    record = AssessmentContentRecord(
        id=content_id,
        origin="published_block",
        owner_id=owner_id,
        course_id=payload.course_id,
        topic=normalized_topic,
        mode="quiz",
        title=question.strip()[:240],
        duration_seconds=0,
        questions=questions,
        answer_key=answer_key,
        content_digest=digest,
    )
    try:
        with session.begin_nested():
            session.add(record)
            session.flush()
    except IntegrityError:
        existing = session.get(AssessmentContentRecord, content_id)
        if (
            existing is None
            or existing.owner_id != owner_id
            or existing.course_id != payload.course_id
            or existing.origin != "published_block"
            or existing.content_digest != digest
        ):
            raise HTTPException(
                status_code=409,
                detail={"code": "published_block_content_conflict"},
            )
        return existing
    return record


def _values(
    payload: AssessmentAttemptUpsert,
    content: AssessmentContentRecord,
    context: dict[str, str | None],
) -> dict[str, object]:
    return {
        "course_id": payload.course_id,
        "assessment_content_id": content.id,
        "origin": payload.origin,
        **context,
        "topic": content.topic,
        "mode": payload.mode,
        "revision": payload.revision,
        "answers": payload.answers,
        "marked": payload.marked,
        "current_index": payload.current_index,
        "remaining_seconds": payload.remaining_seconds,
        "completed": payload.completed,
        "score": _score(payload.answers, content.answer_key) if payload.completed else 0,
        "updated_at": payload.updated_at,
    }


def _published_attempt_id(
    owner_id: str,
    values: dict[str, object],
) -> str:
    identity = [
        "published_block",
        owner_id,
        values["organization_id"],
        values["program_id"],
        values["class_id"],
        values["membership_id"],
        values["enrollment_id"],
        values["legacy_enrollment_id"],
        values["course_id"],
        values["course_version_id"],
        values["section_id"],
        values["section_version_id"],
        values["block_id"],
        values["block_version_id"],
    ]
    digest = hashlib.sha256(
        json.dumps(
            identity,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    return f"attempt:published:{digest[:48]}"


def _published_attempt_for_context(
    session: Session,
    owner_id: str,
    values: dict[str, object],
) -> AssessmentAttemptRecord | None:
    return session.scalar(
        select(AssessmentAttemptRecord)
        .where(
            AssessmentAttemptRecord.owner_id == owner_id,
            AssessmentAttemptRecord.origin == "published_block",
            AssessmentAttemptRecord.enrollment_id == values["enrollment_id"],
            AssessmentAttemptRecord.course_version_id
            == values["course_version_id"],
            AssessmentAttemptRecord.section_id == values["section_id"],
            AssessmentAttemptRecord.section_version_id
            == values["section_version_id"],
            AssessmentAttemptRecord.block_id == values["block_id"],
            AssessmentAttemptRecord.block_version_id
            == values["block_version_id"],
        )
        .limit(1)
    )


def _published_attempt_conflict(record: AssessmentAttemptRecord) -> None:
    raise HTTPException(
        status_code=409,
        detail={
            "code": "published_block_attempt_exists",
            "attempt_id": record.attempt_id,
            "current_revision": record.revision,
        },
    )


def _same_state(
    record: AssessmentAttemptRecord,
    values: dict[str, object],
) -> bool:
    record_updated_at = record.updated_at
    if record_updated_at.tzinfo is None or record_updated_at.utcoffset() is None:
        record_updated_at = record_updated_at.replace(tzinfo=timezone.utc)
    return all(
        getattr(record, key) == value
        for key, value in values.items()
        if key != "updated_at"
    ) and record_updated_at.astimezone(timezone.utc) == values["updated_at"]


def _same_identity(
    record: AssessmentAttemptRecord,
    values: dict[str, object],
) -> bool:
    identity_fields = (
        "course_id",
        "assessment_content_id",
        "origin",
        *CONTEXT_FIELDS,
        "topic",
        "mode",
    )
    return all(getattr(record, field) == values[field] for field in identity_fields)


def _attempt_response(record: AssessmentAttemptRecord) -> AssessmentAttemptResponse:
    updated_at = record.updated_at
    if updated_at.tzinfo is None or updated_at.utcoffset() is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    return AssessmentAttemptResponse(
        attempt_id=record.attempt_id,
        course_id=record.course_id,
        assessment_content_id=record.assessment_content_id,
        origin=record.origin,
        organization_id=record.organization_id,
        program_id=record.program_id,
        class_id=record.class_id,
        membership_id=record.membership_id,
        enrollment_id=record.enrollment_id,
        legacy_enrollment_id=record.legacy_enrollment_id,
        course_version_id=record.course_version_id,
        section_id=record.section_id,
        section_version_id=record.section_version_id,
        block_id=record.block_id,
        block_version_id=record.block_version_id,
        topic=record.topic,
        mode=record.mode,
        revision=record.revision,
        answers=record.answers,
        marked=record.marked,
        current_index=record.current_index,
        remaining_seconds=record.remaining_seconds,
        completed=record.completed,
        score=record.score,
        updated_at=updated_at,
    )


def _record_completion_evidence(
    session: Session,
    attempt_id: str,
    owner_id: str,
    values: dict[str, object],
    content: AssessmentContentRecord,
) -> None:
    if values["origin"] != "published_block" or not values["completed"]:
        return
    evidence_digest = hashlib.sha256(
        json.dumps(
            [owner_id, attempt_id, "published_block_completed_v1"],
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    event_id = f"assessment-completed:{evidence_digest}"
    payload = {
        "schema_version": "published-block-completion-v1",
        "origin": "published_block",
        "course_id": values["course_id"],
        "attempt_id": attempt_id,
        "assessment_content_digest": content.content_digest,
        "score": values["score"],
        "graded": any(
            isinstance(item, dict) and item.get("graded") is True
            for item in content.answer_key
        ),
        **{field: values[field] for field in EVENT_CONTEXT_FIELDS},
    }
    occurred_at = values["updated_at"]
    expected = LearningEventRecord(
        event_id=event_id,
        user_id=owner_id,
        enrollment_id=values["legacy_enrollment_id"],
        course_id=values["course_id"],
        event_type="assessment_completed",
        session_id=f"assessment:{evidence_digest}",
        occurred_at=occurred_at,
        payload=payload,
        active_seconds=0,
        validated_seconds=0,
        sync_status="pending",
    )
    existing = session.get(LearningEventRecord, event_id)
    if existing is None:
        session.add(expected)
        return
    existing_time = existing.occurred_at
    if existing_time.tzinfo is None or existing_time.utcoffset() is None:
        existing_time = existing_time.replace(tzinfo=timezone.utc)
    if not (
        existing.user_id == owner_id
        and existing.enrollment_id == values["legacy_enrollment_id"]
        and existing.course_id == values["course_id"]
        and existing.event_type == "assessment_completed"
        and existing.session_id == expected.session_id
        and existing_time.astimezone(timezone.utc) == occurred_at
        and existing.payload == payload
        and existing.active_seconds == 0
        and existing.validated_seconds == 0
    ):
        raise HTTPException(
            status_code=409,
            detail={"code": "assessment_completion_evidence_conflict"},
        )


def _staff_classroom(
    session: Session, class_id: str, claims: dict[str, str]
) -> Classroom:
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(404, "Turma não encontrada.")
    # Attempts expose answers and scores. Existing classroom policy reserves
    # the full pedagogical view to the assigned teacher/admin; monitors keep
    # their narrower exception workflow.
    _staff(session, classroom, claims, monitor=False)
    return classroom


def _context_matches(
    record: AssessmentAttemptRecord, context: LearningContext
) -> bool:
    return (
        record.origin == "published_block"
        and record.organization_id == context.organization_id
        and record.program_id == context.program_id
        and record.class_id == context.cohort_id
        and record.membership_id == context.membership_id
        and record.enrollment_id == context.enrollment_id
        and record.legacy_enrollment_id == context.legacy_enrollment_id
        and record.course_id == context.course_id
        and record.course_version_id == context.course_version_id
    )


def _contextual_attempt(
    session: Session,
    context: LearningContext,
    owner_id: str,
    attempt_id: str,
) -> AssessmentAttemptRecord:
    record = session.get(AssessmentAttemptRecord, attempt_id)
    if (
        record is None
        or record.owner_id != owner_id
        or record.origin != "published_block"
        or record.class_id != context.cohort_id
    ):
        raise HTTPException(404, "Tentativa contextual não encontrada.")
    if not _context_matches(record, context):
        raise HTTPException(
            status_code=409,
            detail={"code": "stored_learning_context_conflict"},
        )
    return record


def _contextual_page(
    session: Session,
    context: LearningContext,
    owner_id: str,
    *,
    limit: int,
    offset: int,
) -> AssessmentAttemptPage:
    filters = (
        AssessmentAttemptRecord.owner_id == owner_id,
        AssessmentAttemptRecord.origin == "published_block",
        AssessmentAttemptRecord.organization_id == context.organization_id,
        AssessmentAttemptRecord.program_id == context.program_id,
        AssessmentAttemptRecord.class_id == context.cohort_id,
        AssessmentAttemptRecord.membership_id == context.membership_id,
        AssessmentAttemptRecord.enrollment_id == context.enrollment_id,
        AssessmentAttemptRecord.legacy_enrollment_id == context.legacy_enrollment_id,
        AssessmentAttemptRecord.course_id == context.course_id,
        AssessmentAttemptRecord.course_version_id == context.course_version_id,
    )
    total = session.scalar(
        select(func.count()).select_from(AssessmentAttemptRecord).where(*filters)
    ) or 0
    records = session.scalars(
        select(AssessmentAttemptRecord)
        .where(*filters)
        .order_by(
            AssessmentAttemptRecord.updated_at.desc(),
            AssessmentAttemptRecord.attempt_id,
        )
        .offset(offset)
        .limit(limit)
    ).all()
    return AssessmentAttemptPage(
        attempts=[_attempt_response(record) for record in records],
        total=total,
        limit=limit,
        offset=offset,
    )


def _staff_contextual_attempt(
    session: Session,
    classroom: Classroom,
    owner_id: str,
    attempt_id: str,
) -> AssessmentAttemptRecord:
    record = session.get(AssessmentAttemptRecord, attempt_id)
    if (
        record is None
        or record.owner_id != owner_id
        or record.origin != "published_block"
        or record.class_id != classroom.id
        or record.organization_id is None
        or record.program_id != classroom.program_id
        or record.course_id != classroom.course_id
    ):
        raise HTTPException(404, "Tentativa contextual não encontrada.")
    return record


def _staff_contextual_page(
    session: Session,
    classroom: Classroom,
    owner_id: str,
    *,
    limit: int,
    offset: int,
) -> AssessmentAttemptPage:
    filters = (
        AssessmentAttemptRecord.owner_id == owner_id,
        AssessmentAttemptRecord.origin == "published_block",
        AssessmentAttemptRecord.class_id == classroom.id,
        AssessmentAttemptRecord.program_id == classroom.program_id,
        AssessmentAttemptRecord.course_id == classroom.course_id,
    )
    total = session.scalar(
        select(func.count()).select_from(AssessmentAttemptRecord).where(*filters)
    ) or 0
    records = session.scalars(
        select(AssessmentAttemptRecord)
        .where(*filters)
        .order_by(
            AssessmentAttemptRecord.updated_at.desc(),
            AssessmentAttemptRecord.attempt_id,
        )
        .offset(offset)
        .limit(limit)
    ).all()
    return AssessmentAttemptPage(
        attempts=[_attempt_response(record) for record in records],
        total=total,
        limit=limit,
        offset=offset,
    )


def _contextual_content(
    session: Session, attempt: AssessmentAttemptRecord
) -> AssessmentContentResponse:
    if attempt.assessment_content_id is None:
        raise HTTPException(409, "Tentativa contextual sem conteúdo imutável.")
    content = session.get(
        AssessmentContentRecord, attempt.assessment_content_id
    )
    if content is None or content.owner_id != attempt.owner_id:
        raise HTTPException(409, "Conteúdo contextual não pôde ser conferido.")
    if content.origin != "published_block":
        raise HTTPException(409, "Conteúdo contextual possui origem inválida.")
    return _content_response(content, include_answer_key=attempt.completed)


def _content_parts(
    payload: AssessmentContentUpsert,
) -> tuple[str, list[dict[str, object]], list[dict[str, object]]]:
    questions = [
        {
            "question": item.question,
            "options": item.options,
            "topic": item.topic,
        }
        for item in payload.questions
    ]
    answer_key = [
        {
            "correct_index": item.correct_index,
            "explanation": item.explanation,
        }
        for item in payload.questions
    ]
    canonical = {
        "course_id": payload.course_id,
        "topic": payload.topic,
        "mode": payload.mode,
        "title": payload.title,
        "duration_seconds": payload.duration_seconds,
        "questions": questions,
        "answer_key": answer_key,
    }
    serialized = json.dumps(
        canonical,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    return hashlib.sha256(serialized.encode()).hexdigest(), questions, answer_key


def _owned_content(
    session: Session, content_id: str, owner_id: str
) -> AssessmentContentRecord:
    content = session.get(AssessmentContentRecord, content_id)
    if content is None or content.owner_id != owner_id:
        raise HTTPException(404, "Conteúdo de avaliação não encontrado.")
    return content


def _require_attempt_content(
    session: Session,
    owner_id: str,
    payload: AssessmentAttemptUpsert,
) -> AssessmentContentRecord:
    if payload.assessment_content_id is None:
        raise HTTPException(
            status_code=422,
            detail={"code": "assessment_content_required"},
        )
    content = _owned_content(session, payload.assessment_content_id, owner_id)
    if content.origin != "practice":
        raise HTTPException(
            status_code=409,
            detail={"code": "published_block_content_is_server_owned"},
        )
    if (
        content.course_id != payload.course_id
        or content.topic != payload.topic
        or content.mode != payload.mode
    ):
        raise HTTPException(
            status_code=409,
            detail={"code": "assessment_content_identity_conflict"},
        )
    _validate_attempt_against_content(payload, content)
    return content


def _validate_attempt_against_content(
    payload: AssessmentAttemptUpsert,
    content: AssessmentContentRecord,
) -> None:
    question_count = len(content.questions)
    if payload.current_index >= question_count:
        raise HTTPException(422, "current_index fora do conteúdo versionado.")
    if any(index >= question_count for index in payload.marked):
        raise HTTPException(422, "marked referencia questão inexistente.")
    for raw_index, answer in payload.answers.items():
        index = int(raw_index)
        if index >= question_count or answer >= len(content.questions[index]["options"]):
            raise HTTPException(422, "answers referencia questão/alternativa inexistente.")
    if payload.remaining_seconds > content.duration_seconds and content.mode == "exam":
        raise HTTPException(422, "remaining_seconds excede a duração versionada.")


def _score(
    answers: dict[str, int], answer_key: list[dict[str, object]]
) -> int:
    score = 0
    for index, item in enumerate(answer_key):
        if item.get("graded") is False:
            continue
        selected = answers.get(str(index))
        if "correct_indices" in item:
            if selected in item["correct_indices"]:
                score += 1
        elif selected == item["correct_index"]:
            score += 1
    return score


def _content_response(
    record: AssessmentContentRecord,
    *,
    include_answer_key: bool,
) -> AssessmentContentResponse:
    created_at = record.created_at
    if created_at.tzinfo is None or created_at.utcoffset() is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    return AssessmentContentResponse(
        assessment_content_id=record.id,
        course_id=record.course_id,
        topic=record.topic,
        mode=record.mode,
        title=record.title,
        duration_seconds=record.duration_seconds,
        questions=[AssessmentQuestionPublic.model_validate(item) for item in record.questions],
        answer_key=(
            [
                (
                    PublishedBlockAnswerKeyItem.model_validate(item)
                    if "correct_indices" in item
                    else AssessmentAnswerKeyItem.model_validate(item)
                )
                for item in record.answer_key
            ]
            if include_answer_key
            else None
        ),
        created_at=created_at,
    )


def _revision_conflict(*, current_revision: int) -> None:
    raise HTTPException(
        status_code=409,
        detail={
            "code": "revision_conflict",
            "current_revision": current_revision,
            "expected_revision": current_revision + 1,
        },
    )
