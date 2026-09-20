from __future__ import annotations

from datetime import date
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, require_roles
from .database import Database
from .models import (
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Enrollment,
    ProgramCourse,
    ProgramMembership,
)

admin_router = APIRouter(prefix="/admin/classes", tags=["admin", "classes"])
router = APIRouter(prefix="/classes", tags=["classes"])
admin_claims = require_roles("admin")
ClassStatus = Literal["planned", "active", "closed"]


class ClassroomCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)
    teacher_id: str = Field(min_length=1, max_length=36)
    name: str = Field(min_length=2, max_length=240)
    start_date: date
    end_date: date
    status: ClassStatus = "planned"

    @model_validator(mode="after")
    def valid_date_range(self) -> "ClassroomCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date deve ser igual ou posterior a start_date")
        return self


class ClassroomResponse(ClassroomCreate):
    id: str


class ClassroomDetail(ClassroomResponse):
    student_ids: list[str]
    monitor_ids: list[str]


@admin_router.post("", response_model=ClassroomResponse, status_code=201)
def create_classroom(
    payload: ClassroomCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> ClassroomResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        if session.get(ProgramCourse, (payload.program_id, payload.course_id)) is None:
            raise HTTPException(
                status_code=422,
                detail="Curso não é ofertado por este programa.",
            )
        teacher = session.get(
            ProgramMembership, (payload.teacher_id, payload.program_id)
        )
        if teacher is None or teacher.status != "active" or teacher.role != "teacher":
            raise HTTPException(
                status_code=422,
                detail="Professor não possui vínculo ativo neste programa.",
            )
        record = Classroom(
            id=str(uuid4()),
            program_id=payload.program_id,
            course_id=payload.course_id,
            teacher_id=payload.teacher_id,
            name=payload.name.strip(),
            start_date=payload.start_date,
            end_date=payload.end_date,
            status=payload.status,
        )
        session.add(record)
        _commit(session, "Não foi possível criar a turma.")
        return _serialize(record)


@admin_router.post("/{class_id}/students/{user_id}", status_code=201)
def add_student(
    class_id: str,
    user_id: str,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> dict[str, str]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        enrollment = session.scalar(
            select(Enrollment).where(
                Enrollment.user_id == user_id,
                Enrollment.program_id == classroom.program_id,
                Enrollment.course_id == classroom.course_id,
                Enrollment.status == "active",
            )
        )
        if enrollment is None:
            raise HTTPException(
                status_code=422,
                detail="Estudante não possui matrícula ativa para esta turma.",
            )
        if session.get(ClassEnrollment, (class_id, user_id)) is not None:
            raise HTTPException(status_code=409, detail="Estudante já está na turma.")
        session.add(
            ClassEnrollment(
                class_id=class_id,
                user_id=user_id,
                enrollment_id=enrollment.id,
                program_id=classroom.program_id,
                course_id=classroom.course_id,
                status="active",
            )
        )
        _commit(session, "Não foi possível adicionar o estudante.")
        return {"class_id": class_id, "user_id": user_id, "status": "active"}


@admin_router.post("/{class_id}/monitors/{user_id}", status_code=201)
def add_monitor(
    class_id: str,
    user_id: str,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> dict[str, str]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        monitor = session.get(
            ProgramMembership, (user_id, classroom.program_id)
        )
        if monitor is None or monitor.status != "active" or monitor.role != "monitor":
            raise HTTPException(
                status_code=422,
                detail="Monitor não possui vínculo ativo neste programa.",
            )
        if session.get(ClassMonitor, (class_id, user_id)) is not None:
            raise HTTPException(status_code=409, detail="Monitor já está na turma.")
        session.add(
            ClassMonitor(
                class_id=class_id,
                user_id=user_id,
                program_id=classroom.program_id,
            )
        )
        _commit(session, "Não foi possível adicionar o monitor.")
        return {"class_id": class_id, "user_id": user_id}


@router.get("/{class_id}", response_model=ClassroomDetail)
def class_detail(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> ClassroomDetail:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        is_monitor = session.get(ClassMonitor, (class_id, claims["sub"])) is not None
        if (
            claims["role"] != "admin"
            and classroom.teacher_id != claims["sub"]
            and not is_monitor
        ):
            raise HTTPException(
                status_code=403,
                detail="Acesso não autorizado para esta turma.",
            )
        student_ids = session.scalars(
            select(ClassEnrollment.user_id)
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.status == "active",
            )
            .order_by(ClassEnrollment.user_id)
        ).all()
        monitor_ids = session.scalars(
            select(ClassMonitor.user_id)
            .where(ClassMonitor.class_id == class_id)
            .order_by(ClassMonitor.user_id)
        ).all()
        base = _serialize(classroom)
        return ClassroomDetail(
            **base.model_dump(),
            student_ids=list(student_ids),
            monitor_ids=list(monitor_ids),
        )


def _classroom(session: Session, class_id: str) -> Classroom:
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Turma não encontrada.")
    return classroom


def _serialize(record: Classroom) -> ClassroomResponse:
    return ClassroomResponse(
        id=record.id,
        program_id=record.program_id,
        course_id=record.course_id,
        teacher_id=record.teacher_id,
        name=record.name,
        start_date=record.start_date,
        end_date=record.end_date,
        status=record.status,
    )


def _commit(session: Session, detail: str) -> None:
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(status_code=409, detail=detail) from error
