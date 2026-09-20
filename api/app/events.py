from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import require_roles
from .database import Database
from .models import Enrollment, LearningEventRecord, MediaAsset, MediaEventRecord

router = APIRouter(prefix="/events", tags=["events"])
EventType = Literal[
    "lesson_started",
    "lesson_completed",
    "study_activity",
    "page_viewed",
    "resource_opened",
    "feature_used",
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
}
VIDEO_EVENT_TYPES = {
    "video_started",
    "video_checkpoint",
    "video_completed",
    "video_followup_completed",
    "video_saved",
}
STABLE_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,79}$")


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
        if self.event_type == "study_activity" and self.active_seconds is None:
            raise ValueError("study_activity exige active_seconds")
        if self.event_type != "study_activity" and self.active_seconds is not None:
            raise ValueError("active_seconds é exclusivo de study_activity")
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
        elif expected_key is None and self.payload:
            raise ValueError("payload é exclusivo de eventos de telemetria")
        if expected_key is not None:
            if set(self.payload) != {expected_key}:
                raise ValueError(f"{self.event_type} exige apenas {expected_key}")
            if not STABLE_IDENTIFIER.fullmatch(self.payload[expected_key]):
                raise ValueError(f"{expected_key} deve ser um identificador estável")
        return self


class EventResponse(EventCreate):
    sync_status: str
    validated_seconds: int


class EventPage(BaseModel):
    events: list[EventResponse]
    offset: int
    limit: int


@router.post("", response_model=EventResponse, status_code=201)
def create_event(
    payload: EventCreate,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(student_claims),
) -> EventResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        existing = session.get(LearningEventRecord, payload.event_id)
        if existing is not None:
            if existing.user_id != claims["sub"] or not _same_event(existing, payload):
                raise HTTPException(status_code=409, detail="event_id em conflito.")
            response.status_code = 200
            return _serialize(existing)

        media = None
        if payload.event_type in VIDEO_EVENT_TYPES:
            media, enrollment = _resolve_media_event(
                session, claims["sub"], payload
            )
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
                response.status_code = 200
                return _serialize(existing)
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
