from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .auth import access_claims
from .database import Database
from .models import (
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Enrollment,
    LearningEventRecord,
    ProgramCourse,
)

router = APIRouter(prefix="/users", tags=["hours"])


class HoursResponse(BaseModel):
    user_id: str
    program_id: str
    course_id: str
    planned_hours: float
    validated_hours: float
    active_usage: float


@router.get("/{user_id}/hours", response_model=HoursResponse)
def user_hours(
    user_id: str,
    request: Request,
    course_id: Annotated[str, Query(min_length=1, max_length=120)],
    program_id: Annotated[str | None, Query(max_length=36)] = None,
    claims: dict[str, str] = Depends(access_claims),
) -> HoursResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        enrollment = _enrollment(session, user_id, course_id, program_id)
        if not _can_view(session, claims, enrollment):
            raise HTTPException(
                status_code=403,
                detail="Acesso não autorizado à carga horária.",
            )
        offering = session.get(
            ProgramCourse, (enrollment.program_id, enrollment.course_id)
        )
        if offering is None:
            raise HTTPException(status_code=409, detail="Oferta de curso inconsistente.")
        active, validated = session.execute(
            select(
                func.coalesce(func.sum(LearningEventRecord.active_seconds), 0),
                func.coalesce(func.sum(LearningEventRecord.validated_seconds), 0),
            ).where(
                LearningEventRecord.enrollment_id == enrollment.id,
                LearningEventRecord.event_type == "study_activity",
            )
        ).one()
        return HoursResponse(
            user_id=user_id,
            program_id=enrollment.program_id,
            course_id=course_id,
            planned_hours=_hours(offering.planned_seconds),
            validated_hours=_hours(validated),
            active_usage=_hours(active),
        )


def _enrollment(
    session: Session,
    user_id: str,
    course_id: str,
    program_id: str | None,
) -> Enrollment:
    statement = select(Enrollment).where(
        Enrollment.user_id == user_id,
        Enrollment.course_id == course_id,
        Enrollment.status == "active",
    )
    if program_id is not None:
        statement = statement.where(Enrollment.program_id == program_id)
    records = session.scalars(statement).all()
    if not records:
        raise HTTPException(status_code=404, detail="Matrícula ativa não encontrada.")
    if len(records) > 1:
        raise HTTPException(
            status_code=409,
            detail="Informe program_id para selecionar a matrícula.",
        )
    return records[0]


def _can_view(
    session: Session,
    claims: dict[str, str],
    enrollment: Enrollment,
) -> bool:
    viewer_id = claims["sub"]
    if claims["role"] == "admin" or viewer_id == enrollment.user_id:
        return True
    class_ids = select(ClassEnrollment.class_id).where(
        ClassEnrollment.user_id == enrollment.user_id,
        ClassEnrollment.enrollment_id == enrollment.id,
        ClassEnrollment.status == "active",
    )
    if session.scalar(
        select(Classroom.id).where(
            Classroom.id.in_(class_ids),
            Classroom.teacher_id == viewer_id,
        )
    ) is not None:
        return True
    return (
        session.scalar(
            select(ClassMonitor.class_id).where(
                ClassMonitor.class_id.in_(class_ids),
                ClassMonitor.user_id == viewer_id,
            )
        )
        is not None
    )


def _hours(seconds: int) -> float:
    return round(seconds / 3600, 4)
