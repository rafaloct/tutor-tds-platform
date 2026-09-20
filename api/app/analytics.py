from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from .auth import access_claims
from .database import Database
from .models import ClassEnrollment, ClassMonitor, Classroom, LearningEventRecord

router = APIRouter(prefix="/analytics", tags=["analytics"])
TelemetryEventType = Literal["page_viewed", "resource_opened", "feature_used"]
TELEMETRY_KEYS = {
    "page_viewed": "page_id",
    "resource_opened": "resource_id",
    "feature_used": "feature_id",
}


class UsageCount(BaseModel):
    course_id: str
    event_type: TelemetryEventType
    target_id: str
    count: int
    unique_users: int
    last_occurred_at: datetime


class UsageSummary(BaseModel):
    period_start: datetime
    period_end: datetime
    items: list[UsageCount]


@router.get("/usage", response_model=UsageSummary)
def usage_summary(
    request: Request,
    days: Annotated[int, Query(ge=1, le=90)] = 30,
    user_id: Annotated[str | None, Query(max_length=36)] = None,
    class_id: Annotated[str | None, Query(max_length=36)] = None,
    course_id: Annotated[str | None, Query(max_length=120)] = None,
    claims: dict[str, str] = Depends(access_claims),
) -> UsageSummary:
    period_end = datetime.now(timezone.utc)
    period_start = period_end - timedelta(days=days)
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        visible_users = _visible_user_ids(
            session,
            claims=claims,
            user_id=user_id,
            class_id=class_id,
        )
        statement = select(LearningEventRecord).where(
            LearningEventRecord.event_type.in_(TELEMETRY_KEYS),
            LearningEventRecord.occurred_at >= period_start,
            LearningEventRecord.occurred_at <= period_end,
        )
        if visible_users is not None:
            if not visible_users:
                return UsageSummary(
                    period_start=period_start,
                    period_end=period_end,
                    items=[],
                )
            statement = statement.where(LearningEventRecord.user_id.in_(visible_users))
        if course_id is not None:
            statement = statement.where(LearningEventRecord.course_id == course_id)

        grouped: dict[tuple[str, str, str], dict[str, object]] = {}
        for record in session.scalars(statement).yield_per(500):
            key_name = TELEMETRY_KEYS[record.event_type]
            target_id = record.payload.get(key_name)
            if not isinstance(target_id, str):
                continue
            key = (record.course_id, record.event_type, target_id)
            current = grouped.setdefault(
                key,
                {"count": 0, "users": set(), "last": record.occurred_at},
            )
            current["count"] = int(current["count"]) + 1
            users = current["users"]
            assert isinstance(users, set)
            users.add(record.user_id)
            last = current["last"]
            assert isinstance(last, datetime)
            if record.occurred_at > last:
                current["last"] = record.occurred_at

        items = [
            UsageCount(
                course_id=course_id,
                event_type=event_type,
                target_id=target_id,
                count=int(values["count"]),
                unique_users=len(values["users"]),  # type: ignore[arg-type]
                last_occurred_at=values["last"],  # type: ignore[arg-type]
            )
            for (course_id, event_type, target_id), values in grouped.items()
        ]
        items.sort(
            key=lambda item: (
                item.course_id,
                item.event_type,
                -item.count,
                item.target_id,
            )
        )
        return UsageSummary(
            period_start=period_start,
            period_end=period_end,
            items=items,
        )


def _visible_user_ids(
    session: Session,
    *,
    claims: dict[str, str],
    user_id: str | None,
    class_id: str | None,
) -> set[str] | None:
    viewer_id = claims["sub"]
    role = claims["role"]
    if role == "student":
        if user_id is not None and user_id != viewer_id:
            raise HTTPException(status_code=403, detail="Analytics não autorizado.")
        if class_id is not None:
            active_class = session.scalar(
                select(ClassEnrollment.class_id).where(
                    ClassEnrollment.class_id == class_id,
                    ClassEnrollment.user_id == viewer_id,
                    ClassEnrollment.status == "active",
                )
            )
            if active_class is None:
                raise HTTPException(status_code=403, detail="Analytics não autorizado.")
        return {viewer_id}

    if role == "admin":
        if class_id is not None:
            return _class_student_ids(session, class_id, user_id)
        return {user_id} if user_id is not None else None

    if role not in {"teacher", "monitor"} or class_id is None:
        raise HTTPException(
            status_code=422,
            detail="Professor ou monitor deve informar class_id.",
        )
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Turma não encontrada.")
    is_monitor = session.get(ClassMonitor, (class_id, viewer_id)) is not None
    if classroom.teacher_id != viewer_id and not is_monitor:
        raise HTTPException(status_code=403, detail="Analytics não autorizado.")
    return _class_student_ids(session, class_id, user_id)


def _class_student_ids(
    session: Session, class_id: str, user_id: str | None
) -> set[str]:
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Turma não encontrada.")
    student_ids = set(
        session.scalars(
            select(ClassEnrollment.user_id).where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.status == "active",
            )
        ).all()
    )
    if user_id is not None:
        if user_id not in student_ids:
            raise HTTPException(
                status_code=404,
                detail="Estudante ativo não encontrado nesta turma.",
            )
        return {user_id}
    return student_ids
