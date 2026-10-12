from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, require_roles
from .database import Database
from .context_memberships import active_student_binding
from .models import (
    ClassEnrollment, Classroom, Course, CourseVersion, CourseVersionTransition, Enrollment,
    LearningEventRecord, MediaAsset, MediaEventRecord, ProgramMembership,
)

router = APIRouter(prefix="/events", tags=["events"])
EventType = Literal[
    "lesson_started",
    "lesson_completed",
    "study_activity",
    "page_viewed",
    "resource_opened",
    "feature_used",
    "screen_engagement",
    "video_started",
    "video_checkpoint",
    "video_completed",
    "video_followup_completed",
    "video_saved",
]
student_claims = require_roles("student")
TELEMETRY_PAYLOAD_KEYS = {
    "page_viewed": "page_id",
    "resource_opened": "resource_id",
    "feature_used": "feature_id",
    "screen_engagement": "page_id",
}
VIDEO_EVENT_TYPES = {
    "video_started",
    "video_checkpoint",
    "video_completed",
    "video_followup_completed",
    "video_saved",
}
STABLE_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,79}$")
VERSIONED_EVENT_TYPES = {"lesson_started", "lesson_completed", "study_activity"}
COURSE_CONTEXT_KEYS = {"course_version_id", "class_id"}
COURSE_CONTEXT_IDENTIFIER = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,35}$")


class EventCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: str = Field(min_length=1, max_length=180)
    event_type: EventType
    course_id: str = Field(min_length=1, max_length=120)
    session_id: str = Field(min_length=1, max_length=160)
    occurred_at: datetime
    active_seconds: int | None = Field(default=None, ge=1, le=60)
    payload: dict[str, str] = Field(default_factory=dict)

    @field_validator("occurred_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at deve conter fuso horário")
        normalized = value.astimezone(timezone.utc)
        if normalized > datetime.now(timezone.utc) + timedelta(minutes=5):
            raise ValueError("occurred_at não pode estar no futuro")
        return normalized

    @model_validator(mode="after")
    def require_activity_duration(self) -> "EventCreate":
        duration_types = {"study_activity", "screen_engagement"}
        if self.event_type in duration_types and self.active_seconds is None:
            raise ValueError("evento de duração exige active_seconds")
        if self.event_type not in duration_types and self.active_seconds is not None:
            raise ValueError("active_seconds não permitido neste evento")
        expected_key = TELEMETRY_PAYLOAD_KEYS.get(self.event_type)
        if self.event_type in VIDEO_EVENT_TYPES:
            expected = {"media_id", "module_id"}
            if self.event_type == "video_checkpoint":
                expected.update({"checkpoint", "position_seconds"})
            elif self.event_type == "video_completed":
                expected.add("position_seconds")
            elif self.event_type == "video_followup_completed":
                expected.add("followup_type")
            if set(self.payload) != expected:
                raise ValueError(f"{self.event_type} possui payload inválido")
            if not all(
                STABLE_IDENTIFIER.fullmatch(self.payload[key])
                for key in ("media_id", "module_id")
            ):
                raise ValueError("media_id/module_id deve ser identificador estável")
            if self.event_type == "video_checkpoint" and self.payload["checkpoint"] not in {"25", "50", "75"}:
                raise ValueError("checkpoint deve ser 25, 50 ou 75")
            if "position_seconds" in self.payload and (
                not self.payload["position_seconds"].isdigit()
                or len(self.payload["position_seconds"]) > 8
            ):
                raise ValueError("position_seconds deve ser inteiro estável")
            if self.event_type == "video_followup_completed" and self.payload["followup_type"] not in {"quiz", "reflection", "activity"}:
                raise ValueError("followup_type inválido")
        elif self.event_type in VERSIONED_EVENT_TYPES:
            if set(self.payload) - COURSE_CONTEXT_KEYS:
                raise ValueError("Evento de estudo aceita apenas course_version_id e class_id")
            if "class_id" in self.payload and "course_version_id" not in self.payload:
                raise ValueError("class_id exige course_version_id")
            if any(not COURSE_CONTEXT_IDENTIFIER.fullmatch(value) for value in self.payload.values()):
                raise ValueError("Contexto do curso exige identificadores estáveis de até 36 caracteres")
        elif expected_key is None and self.payload:
            raise ValueError("payload é exclusivo de eventos de telemetria")
        if expected_key is not None:
            if set(self.payload) != {expected_key}:
                raise ValueError(f"{self.event_type} exige apenas {expected_key}")
            if not STABLE_IDENTIFIER.fullmatch(self.payload[expected_key]):
                raise ValueError(f"{expected_key} deve ser um identificador estável")
        return self


class EventResponse(BaseModel):
    event_id: str
    event_type: EventType | Literal["assessment_completed"]
    course_id: str
    session_id: str
    occurred_at: datetime
    active_seconds: int | None
    payload: dict[str, object]
    sync_status: str
    validated_seconds: int


class EventPage(BaseModel):
    events: list[EventResponse]
    offset: int
    limit: int


def event_claims(
    payload: EventCreate,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, str]:
    # Preserve the legacy catalog/media policy. Only explicit cohort learning
    # uses contextual authorization while the additive flag is enabled.
    if claims["role"] == "student":
        return claims
    if request.app.state.settings.journey_traceability_enabled and payload.event_type in TELEMETRY_PAYLOAD_KEYS:
        # Authenticated account analytics does not grant academic permissions.
        return claims
    if (
        request.app.state.settings.learning_context_enabled
        and payload.event_type in VERSIONED_EVENT_TYPES
        and "class_id" in payload.payload
        and "course_version_id" in payload.payload
    ):
        # This is not a grant: create_event still resolves active relational
        # enrollment before inserting, and retries must match owner and content.
        return claims
    raise HTTPException(status_code=403, detail="Acesso não autorizado para esta função.")


@router.post("", response_model=EventResponse, status_code=201)
def create_event(
    payload: EventCreate,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(event_claims),
) -> EventResponse:
    request.state.trace_id = payload.event_id
    request.state.attempt = "new"
    if payload.event_type == "screen_engagement" and not request.app.state.settings.journey_traceability_enabled:
        raise HTTPException(status_code=404, detail="Tempo de tela ainda não habilitado.")
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        existing = session.get(LearningEventRecord, payload.event_id)
        if existing is not None:
            if existing.user_id != claims["sub"] or not _same_event(existing, payload):
                request.state.attempt = "conflict"
                raise HTTPException(status_code=409, detail="event_id em conflito.")
            request.state.attempt = "retry"
            response.status_code = 200
            return _serialize(existing)

        media = None
        if payload.event_type in VIDEO_EVENT_TYPES:
            media, enrollment = _resolve_media_event(
                session, claims["sub"], payload
            )
        elif "course_version_id" in payload.payload:
            enrollment = _resolve_course_version_event(session, claims["sub"], payload)
        else:
            enrollment = _resolve_enrollment(session, claims["sub"], payload)
        validated_seconds = _validated_seconds(
            session,
            user_id=claims["sub"],
            payload=payload,
        )
        record = LearningEventRecord(
            event_id=payload.event_id,
            user_id=claims["sub"],
            enrollment_id=enrollment.id if enrollment is not None else None,
            course_id=payload.course_id,
            event_type=payload.event_type,
            session_id=payload.session_id,
            occurred_at=payload.occurred_at,
            payload=payload.payload,
            active_seconds=payload.active_seconds or 0,
            validated_seconds=validated_seconds,
            sync_status="pending",
        )
        session.add(record)
        if media is not None and enrollment is not None:
            session.add(
                MediaEventRecord(
                    event_id=payload.event_id,
                    media_id=media.id,
                    user_id=claims["sub"],
                    enrollment_id=enrollment.id,
                    course_id=media.course_id,
                    module_id=media.module_id,
                    session_id=payload.session_id,
                    event_type=payload.event_type,
                    checkpoint_percent=(
                        int(payload.payload["checkpoint"])
                        if payload.event_type == "video_checkpoint"
                        else None
                    ),
                    position_seconds=(
                        int(payload.payload["position_seconds"])
                        if "position_seconds" in payload.payload
                        else None
                    ),
                    qualified=_qualified_video_event(
                        session,
                        media=media,
                        user_id=claims["sub"],
                        session_id=payload.session_id,
                        event_type=payload.event_type,
                        occurred_at=payload.occurred_at,
                        position_seconds=(
                            int(payload.payload["position_seconds"])
                            if "position_seconds" in payload.payload
                            else None
                        ),
                    ),
                    occurred_at=payload.occurred_at,
                )
            )
        try:
            session.commit()
        except IntegrityError as error:
            session.rollback()
            existing = session.get(LearningEventRecord, payload.event_id)
            if (
                existing is not None
                and existing.user_id == claims["sub"]
                and _same_event(existing, payload)
            ):
                request.state.attempt = "retry"
                response.status_code = 200
                return _serialize(existing)
            request.state.attempt = "conflict"
            raise HTTPException(status_code=409, detail="event_id em conflito.") from error
        return _serialize(record)


@router.get("", response_model=EventPage)
def list_events(
    request: Request,
    course_id: str | None = Query(default=None, min_length=1, max_length=120),
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    claims: dict[str, str] = Depends(student_claims),
) -> EventPage:
    database: Database = request.app.state.database
    statement = select(LearningEventRecord).where(
        LearningEventRecord.user_id == claims["sub"]
    )
    if course_id is not None:
        statement = statement.where(LearningEventRecord.course_id == course_id)
    statement = statement.order_by(
        LearningEventRecord.occurred_at.desc(),
        LearningEventRecord.event_id,
    ).offset(offset).limit(limit)
    with Session(database.engine) as session:
        records = session.scalars(statement).all()
        return EventPage(
            events=[_serialize(record) for record in records],
            offset=offset,
            limit=limit,
        )


def _same_event(record: LearningEventRecord, payload: EventCreate) -> bool:
    occurred_at = record.occurred_at
    if occurred_at.tzinfo is None:
        occurred_at = occurred_at.replace(tzinfo=timezone.utc)
    return (
        record.course_id == payload.course_id
        and record.event_type == payload.event_type
        and record.session_id == payload.session_id
        and occurred_at.astimezone(timezone.utc) == payload.occurred_at
        and record.active_seconds == (payload.active_seconds or 0)
        and record.payload == payload.payload
    )


def _serialize(record: LearningEventRecord) -> EventResponse:
    occurred_at = record.occurred_at
    if occurred_at.tzinfo is None:
        occurred_at = occurred_at.replace(tzinfo=timezone.utc)
    return EventResponse(
        event_id=record.event_id,
        event_type=record.event_type,
        course_id=record.course_id,
        session_id=record.session_id,
        occurred_at=occurred_at,
        active_seconds=record.active_seconds or None,
        payload=record.payload,
        sync_status=record.sync_status,
        validated_seconds=record.validated_seconds,
    )


def _resolve_enrollment(
    session: Session,
    user_id: str,
    payload: EventCreate,
) -> Enrollment | None:
    statement = select(Enrollment).where(
        Enrollment.user_id == user_id,
        Enrollment.course_id == payload.course_id,
        Enrollment.status == "active",
    )
    if payload.event_type == "study_activity":
        # Serializa o cálculo por matrícula no PostgreSQL para que dois eventos
        # concorrentes não validem o mesmo intervalo antes do commit.
        statement = statement.with_for_update()
    records = session.scalars(statement).all()
    if payload.event_type == "study_activity" and len(records) > 1:
        raise HTTPException(
            status_code=422,
            detail="Atividade possui mais de uma matrícula ativa para o curso.",
        )
    return records[0] if len(records) == 1 else None


def _resolve_course_version_event(
    session: Session,
    user_id: str,
    payload: EventCreate,
) -> Enrollment | None:
    version = session.get(CourseVersion, payload.payload["course_version_id"])
    if version is None or version.course_id != payload.course_id or version.status not in {"published", "archived"}:
        raise HTTPException(status_code=404, detail="Versão de curso publicada não encontrada.")
    class_id = payload.payload.get("class_id")
    if class_id is not None or version.status == "archived":
        # The class enrollment identifies the exact program/course enrollment;
        # never attach this evidence to an arbitrary parallel enrollment.
        statement = select(Enrollment).join(
            ClassEnrollment,
            (ClassEnrollment.enrollment_id == Enrollment.id)
            & (ClassEnrollment.user_id == Enrollment.user_id)
            & (ClassEnrollment.program_id == Enrollment.program_id)
            & (ClassEnrollment.course_id == Enrollment.course_id),
        ).join(
            Classroom,
            (Classroom.id == ClassEnrollment.class_id)
            & (Classroom.program_id == ClassEnrollment.program_id)
            & (Classroom.course_id == ClassEnrollment.course_id),
        ).join(
            ProgramMembership,
            (ProgramMembership.user_id == Enrollment.user_id)
            & (ProgramMembership.program_id == Enrollment.program_id),
        ).where(
            Enrollment.user_id == user_id,
            Enrollment.course_id == payload.course_id,
            Enrollment.status == "active",
            ClassEnrollment.status == "active",
            ProgramMembership.status == "active",
            Classroom.course_version_id == version.id,
            active_student_binding(),
        )
        if class_id is not None:
            statement = statement.where(Classroom.id == class_id)
        if payload.event_type == "study_activity":
            statement = statement.with_for_update(of=Enrollment)
        records = session.scalars(statement).unique().all()
        if not records:
            if class_id is None and _was_public_when_recorded(session, version.id, payload.occurred_at):
                # Offline catalog evidence may arrive after a newer publication.
                # Explicit class claims must still pass the exact lineage above.
                return _resolve_enrollment(session, user_id, payload)
            raise HTTPException(status_code=403, detail="Versão/turma sem matrícula ativa autorizada.")
        if len(records) > 1:
            raise HTTPException(status_code=422, detail="Informe class_id para identificar a matrícula desta versão.")
        return records[0]
    course = session.get(Course, payload.course_id)
    if course is None or not course.active:
        raise HTTPException(status_code=404, detail="Curso publicado não encontrado.")
    return _resolve_enrollment(session, user_id, payload)


def _was_public_when_recorded(
    session: Session,
    version_id: str,
    occurred_at: datetime,
) -> bool:
    """Use audited UTC publication windows, never infer them from creation."""
    transitions = session.scalars(select(CourseVersionTransition).where(
        CourseVersionTransition.version_id == version_id,
        CourseVersionTransition.to_status.in_({"published", "archived"}),
    ).order_by(CourseVersionTransition.occurred_at)).all()
    published_at: datetime | None = None
    event_time = occurred_at.astimezone(timezone.utc)
    for transition in transitions:
        timestamp = transition.occurred_at
        timestamp = timestamp.replace(tzinfo=timezone.utc) if timestamp.tzinfo is None else timestamp.astimezone(timezone.utc)
        if transition.to_status == "published":
            published_at = timestamp
        elif transition.from_status == "published" and published_at is not None:
            # Half-open interval: publication permits access; archive ends it.
            return published_at <= event_time < timestamp
    return False


def _resolve_media_event(
    session: Session,
    user_id: str,
    payload: EventCreate,
) -> tuple[MediaAsset, Enrollment]:
    media = session.get(MediaAsset, payload.payload["media_id"])
    if media is None or media.status != "published":
        raise HTTPException(status_code=404, detail="Mídia publicada não encontrada.")
    if media.course_id != payload.course_id or media.module_id != payload.payload["module_id"]:
        raise HTTPException(status_code=422, detail="Curso/módulo não corresponde à mídia.")
    if "position_seconds" in payload.payload:
        position = int(payload.payload["position_seconds"])
        if position > media.duration_seconds + 5:
            raise HTTPException(status_code=422, detail="Posição incompatível com a duração.")
        if payload.event_type == "video_checkpoint":
            checkpoint = int(payload.payload["checkpoint"])
            minimum = media.duration_seconds * checkpoint / 100 - 5
            if position < minimum:
                raise HTTPException(status_code=422, detail="Checkpoint incompatível com a posição.")
            previous_percent = {25: None, 50: 25, 75: 50}[checkpoint]
            previous_type = "video_started" if previous_percent is None else "video_checkpoint"
            previous = session.scalar(select(MediaEventRecord).where(
                MediaEventRecord.media_id == media.id,
                MediaEventRecord.user_id == user_id,
                MediaEventRecord.session_id == payload.session_id,
                MediaEventRecord.event_type == previous_type,
                *(
                    [MediaEventRecord.checkpoint_percent == previous_percent]
                    if previous_percent is not None else []
                ),
                MediaEventRecord.occurred_at < payload.occurred_at,
            ).order_by(MediaEventRecord.occurred_at.desc()))
            if previous is None or (
                previous.position_seconds is not None
                and previous.position_seconds >= position
            ):
                raise HTTPException(status_code=422, detail="Sequência de checkpoint inválida.")
    enrollment = session.scalar(
        select(Enrollment).where(
            Enrollment.user_id == user_id,
            Enrollment.program_id == media.program_id,
            Enrollment.course_id == media.course_id,
            Enrollment.status == "active",
        )
    )
    if enrollment is None:
        raise HTTPException(status_code=403, detail="Acesso/matrícula da mídia não autorizado.")
    return media, enrollment


def _qualified_video_event(
    session: Session,
    *,
    media: MediaAsset,
    user_id: str,
    session_id: str,
    event_type: str,
    occurred_at: datetime,
    position_seconds: int | None,
) -> bool:
    if event_type == "video_completed":
        records = session.scalars(
            select(MediaEventRecord).where(
                MediaEventRecord.media_id == media.id,
                MediaEventRecord.user_id == user_id,
                MediaEventRecord.session_id == session_id,
                MediaEventRecord.event_type.in_({"video_started", "video_checkpoint"}),
                MediaEventRecord.occurred_at < occurred_at,
            ).order_by(MediaEventRecord.occurred_at)
        ).all()
        started = [item for item in records if item.event_type == "video_started"]
        checkpoints = {
            item.checkpoint_percent: item
            for item in records
            if item.event_type == "video_checkpoint"
        }
        if not started or set(checkpoints) != {25, 50, 75}:
            return False
        sequence = [started[0], checkpoints[25], checkpoints[50], checkpoints[75]]
        times = [
            item.occurred_at.replace(tzinfo=timezone.utc)
            if item.occurred_at.tzinfo is None
            else item.occurred_at.astimezone(timezone.utc)
            for item in sequence
        ]
        if times != sorted(times) or len(set(times)) != 4:
            return False
        return (
            position_seconds is not None
            and position_seconds >= media.duration_seconds * 0.9
            and position_seconds <= media.duration_seconds + 5
        )
    if event_type == "video_followup_completed":
        return session.scalar(
            select(MediaEventRecord.event_id).where(
                MediaEventRecord.media_id == media.id,
                MediaEventRecord.user_id == user_id,
                MediaEventRecord.event_type == "video_completed",
                MediaEventRecord.qualified.is_(True),
                MediaEventRecord.occurred_at < occurred_at,
            )
        ) is not None
    return event_type == "video_saved"


def _validated_seconds(
    session: Session,
    *,
    user_id: str,
    payload: EventCreate,
) -> int:
    if payload.event_type != "study_activity" or payload.active_seconds is None:
        return 0
    interval_end = payload.occurred_at
    interval_start = interval_end - timedelta(seconds=payload.active_seconds)
    candidates = session.scalars(
        select(LearningEventRecord).where(
            LearningEventRecord.user_id == user_id,
            LearningEventRecord.course_id == payload.course_id,
            LearningEventRecord.event_type == "study_activity",
            LearningEventRecord.occurred_at > interval_start,
            LearningEventRecord.occurred_at
            <= interval_end + timedelta(seconds=60),
        )
    ).all()
    overlaps: list[tuple[datetime, datetime]] = []
    for record in candidates:
        existing_end = record.occurred_at
        if existing_end.tzinfo is None:
            existing_end = existing_end.replace(tzinfo=timezone.utc)
        existing_start = existing_end - timedelta(seconds=record.active_seconds)
        start = max(interval_start, existing_start)
        end = min(interval_end, existing_end)
        if end > start:
            overlaps.append((start, end))
    covered = 0.0
    cursor: datetime | None = None
    for start, end in sorted(overlaps):
        effective_start = max(start, cursor) if cursor is not None else start
        if end > effective_start:
            covered += (end - effective_start).total_seconds()
        cursor = max(cursor, end) if cursor is not None else end
    return max(0, payload.active_seconds - round(covered))
