from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import require_roles
from .database import Database
from .models import LearningEventRecord

router = APIRouter(prefix="/events", tags=["events"])
EventType = Literal["lesson_started", "lesson_completed"]
student_claims = require_roles("student")


class EventCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: str = Field(min_length=1, max_length=180)
    event_type: EventType
    course_id: str = Field(min_length=1, max_length=120)
    session_id: str = Field(min_length=1, max_length=160)
    occurred_at: datetime

    @field_validator("occurred_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("occurred_at deve conter fuso horário")
        return value.astimezone(timezone.utc)


class EventResponse(EventCreate):
    sync_status: str


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

        record = LearningEventRecord(
            event_id=payload.event_id,
            user_id=claims["sub"],
            course_id=payload.course_id,
            event_type=payload.event_type,
            session_id=payload.session_id,
            occurred_at=payload.occurred_at,
            payload={},
            sync_status="pending",
        )
        session.add(record)
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
        sync_status=record.sync_status,
    )
