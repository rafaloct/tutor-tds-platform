from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import require_roles
from .database import Database
from .models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    Course,
    Enrollment,
)

router = APIRouter(prefix="/assessment-attempts", tags=["assessment-sync"])
content_router = APIRouter(prefix="/assessment-contents", tags=["assessment-sync"])
student_claims = require_roles("student")
AttemptMode = Literal["quiz", "exam"]


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


class AssessmentContentResponse(BaseModel):
    assessment_content_id: str
    course_id: str
    topic: str
    mode: AttemptMode
    title: str
    duration_seconds: int
    questions: list[AssessmentQuestionPublic]
    answer_key: list[AssessmentAnswerKeyItem] | None
    created_at: datetime


class AssessmentAttemptUpsert(BaseModel):
    model_config = ConfigDict(extra="forbid")

    course_id: str = Field(min_length=1, max_length=120)
    assessment_content_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=180,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9_.:-]*$",
    )
    topic: str = Field(min_length=1, max_length=240)
    mode: AttemptMode
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
    claims: dict[str, str] = Depends(student_claims),
) -> AssessmentAttemptResponse:
    database: Database = request.app.state.database
    owner_id = claims["sub"]
    if payload.score != 0:
        raise HTTPException(422, "score é calculado pelo servidor; envie zero.")
    with Session(database.engine) as session:
        existing = session.get(AssessmentAttemptRecord, attempt_id)
        if existing is None:
            _require_course_access(session, owner_id, payload.course_id)
            content = _require_attempt_content(session, owner_id, payload)
            if payload.revision != 1:
                _revision_conflict(current_revision=0)
            record = AssessmentAttemptRecord(
                attempt_id=attempt_id,
                owner_id=owner_id,
                **_values(payload, content),
            )
            session.add(record)
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                concurrent = session.get(AssessmentAttemptRecord, attempt_id)
                if concurrent is None or concurrent.owner_id != owner_id:
                    raise HTTPException(404, "Tentativa não encontrada.")
                if concurrent.revision == payload.revision and _same_state(
                    concurrent, payload, content
                ):
                    return _attempt_response(concurrent)
                _revision_conflict(current_revision=concurrent.revision)
            response.status_code = 201
            return _attempt_response(record)

        if existing.owner_id != owner_id:
            raise HTTPException(404, "Tentativa não encontrada.")
        if (
            existing.course_id != payload.course_id
            or existing.assessment_content_id != payload.assessment_content_id
            or existing.topic != payload.topic
            or existing.mode != payload.mode
        ):
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "attempt_identity_conflict",
                    "current_revision": existing.revision,
                },
            )
        _require_course_access(session, owner_id, payload.course_id)
        content = _require_attempt_content(session, owner_id, payload)
        if existing.revision == payload.revision:
            if _same_state(existing, payload, content):
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
            .values(**_values(payload, content))
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
                and _same_state(concurrent, payload, content)
            ):
                return _attempt_response(concurrent)
            _revision_conflict(current_revision=concurrent.revision if concurrent else 0)
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
        if attempt is None or attempt.owner_id != claims["sub"]:
            raise HTTPException(404, "Tentativa não encontrada.")
        if attempt.assessment_content_id is None:
            raise HTTPException(
                status_code=409,
                detail={"code": "legacy_attempt_without_content"},
            )
        content = _owned_content(
            session, attempt.assessment_content_id, claims["sub"]
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
        if record is None or record.owner_id != claims["sub"]:
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
        filters = [AssessmentAttemptRecord.owner_id == claims["sub"]]
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


def _values(
    payload: AssessmentAttemptUpsert,
    content: AssessmentContentRecord,
) -> dict[str, object]:
    return {
        "course_id": payload.course_id,
        "assessment_content_id": content.id,
        "topic": payload.topic,
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


def _same_state(
    record: AssessmentAttemptRecord,
    payload: AssessmentAttemptUpsert,
    content: AssessmentContentRecord,
) -> bool:
    record_updated_at = record.updated_at
    if record_updated_at.tzinfo is None or record_updated_at.utcoffset() is None:
        record_updated_at = record_updated_at.replace(tzinfo=timezone.utc)
    values = _values(payload, content)
    return all(
        getattr(record, key) == value
        for key, value in values.items()
        if key != "updated_at"
    ) and record_updated_at.astimezone(timezone.utc) == payload.updated_at


def _attempt_response(record: AssessmentAttemptRecord) -> AssessmentAttemptResponse:
    updated_at = record.updated_at
    if updated_at.tzinfo is None or updated_at.utcoffset() is None:
        updated_at = updated_at.replace(tzinfo=timezone.utc)
    return AssessmentAttemptResponse(
        attempt_id=record.attempt_id,
        course_id=record.course_id,
        assessment_content_id=record.assessment_content_id,
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
    if (
        content.course_id != payload.course_id
        or content.topic != payload.topic
        or content.mode != payload.mode
    ):
        raise HTTPException(
            status_code=409,
            detail={"code": "assessment_content_identity_conflict"},
        )
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
    return content


def _score(
    answers: dict[str, int], answer_key: list[dict[str, object]]
) -> int:
    return sum(
        answers.get(str(index)) == item["correct_index"]
        for index, item in enumerate(answer_key)
    )


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
            [AssessmentAnswerKeyItem.model_validate(item) for item in record.answer_key]
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
