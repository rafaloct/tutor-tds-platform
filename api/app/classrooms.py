from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, require_roles
from .database import Database
from .models import (
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Enrollment,
    LearningEventRecord,
    ProgramCourse,
    ProgramMembership,
    User,
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


class ClassroomPage(BaseModel):
    classes: list[ClassroomResponse]


class StudentAlert(BaseModel):
    code: Literal[
        "inactive_7_days",
        "required_activity_pending",
        "below_expected_hours",
    ]


class StudentProgress(BaseModel):
    user_id: str
    name: str
    enrollment_id: str
    status: str
    planned_hours: float
    validated_hours: float
    progress_percent: float
    last_activity_at: datetime | None
    inactive_days: int
    alerts: list[StudentAlert]


class DashboardSummary(BaseModel):
    total_students: int
    inactive_students: int
    pending_students: int
    below_expected_students: int


class ClassroomDashboard(BaseModel):
    classroom: ClassroomResponse
    generated_at: datetime
    expected_progress_percent: float
    summary: DashboardSummary
    students: list[StudentProgress]


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


@router.get("", response_model=ClassroomPage)
def visible_classes(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> ClassroomPage:
    """Lista somente turmas relacionadas ao papel autenticado.

    Administradores veem todas; professores, as que lecionam; monitores, as
    atribuídas; estudantes, as matrículas ativas. A resposta não expõe a
    lista de participantes.
    """
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        statement = select(Classroom)
        user_id = claims["sub"]
        if claims["role"] != "admin":
            monitored = select(ClassMonitor.class_id).where(
                ClassMonitor.user_id == user_id
            )
            enrolled = select(ClassEnrollment.class_id).where(
                ClassEnrollment.user_id == user_id,
                ClassEnrollment.status == "active",
            )
            # Os vínculos no programa/turma são a autoridade do escopo. Isso
            # também permite que uma pessoa acumule papéis em programas
            # distintos sem ampliar seu papel global no token.
            statement = statement.where(
                or_(
                    Classroom.teacher_id == user_id,
                    Classroom.id.in_(monitored),
                    Classroom.id.in_(enrolled),
                )
            )
        records = session.scalars(
            statement.order_by(Classroom.start_date.desc(), Classroom.name)
        ).all()
        return ClassroomPage(classes=[_serialize(item) for item in records])


@router.get("/{class_id}/dashboard", response_model=ClassroomDashboard)
def class_dashboard(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> ClassroomDashboard:
    """Retorna a visão pedagógica por exceção para professor/monitor/admin."""
    now = datetime.now(timezone.utc)
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        _require_staff_access(session, classroom, claims)
        offering = session.get(
            ProgramCourse, (classroom.program_id, classroom.course_id)
        )
        if offering is None:
            raise HTTPException(status_code=409, detail="Oferta da turma inconsistente.")

        expected_percent = _expected_progress(classroom, now.date())
        memberships = session.execute(
            select(ClassEnrollment, User)
            .join(User, User.id == ClassEnrollment.user_id)
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.status == "active",
            )
            .order_by(User.name, User.id)
        ).all()
        students = [
            _student_progress(
                session,
                membership=membership,
                user=user,
                planned_seconds=offering.planned_seconds,
                expected_percent=expected_percent,
                now=now,
            )
            for membership, user in memberships
        ]
        return ClassroomDashboard(
            classroom=_serialize(classroom),
            generated_at=now,
            expected_progress_percent=expected_percent,
            summary=DashboardSummary(
                total_students=len(students),
                inactive_students=_alert_count(students, "inactive_7_days"),
                pending_students=_alert_count(
                    students, "required_activity_pending"
                ),
                below_expected_students=_alert_count(
                    students, "below_expected_hours"
                ),
            ),
            students=students,
        )


def _classroom(session: Session, class_id: str) -> Classroom:
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Turma não encontrada.")
    return classroom


def _require_staff_access(
    session: Session,
    classroom: Classroom,
    claims: dict[str, str],
) -> None:
    if claims["role"] == "admin" or classroom.teacher_id == claims["sub"]:
        return
    if session.get(ClassMonitor, (classroom.id, claims["sub"])) is not None:
        return
    raise HTTPException(
        status_code=403,
        detail="Acesso não autorizado para o painel desta turma.",
    )


def _student_progress(
    session: Session,
    *,
    membership: ClassEnrollment,
    user: User,
    planned_seconds: int,
    expected_percent: float,
    now: datetime,
) -> StudentProgress:
    validated, last_activity, completed = session.execute(
        select(
            func.coalesce(func.sum(LearningEventRecord.validated_seconds), 0),
            func.max(LearningEventRecord.occurred_at),
            func.count().filter(
                LearningEventRecord.event_type == "lesson_completed"
            ),
        ).where(
            LearningEventRecord.enrollment_id == membership.enrollment_id,
            or_(
                LearningEventRecord.event_type == "study_activity",
                LearningEventRecord.event_type == "lesson_completed",
            ),
        )
    ).one()
    validated_seconds = int(validated or 0)
    progress = (
        min(100.0, round(validated_seconds * 100 / planned_seconds, 2))
        if planned_seconds > 0
        else 0.0
    )
    reference = last_activity or membership.enrolled_at
    if reference.tzinfo is None:
        reference = reference.replace(tzinfo=timezone.utc)
    inactive_days = max(0, (now - reference.astimezone(timezone.utc)).days)
    codes: list[StudentAlert] = []
    if inactive_days >= 7:
        codes.append(StudentAlert(code="inactive_7_days"))
    if not completed:
        codes.append(StudentAlert(code="required_activity_pending"))
    if progress + 0.01 < expected_percent:
        codes.append(StudentAlert(code="below_expected_hours"))
    return StudentProgress(
        user_id=user.id,
        name=user.name,
        enrollment_id=membership.enrollment_id,
        status=membership.status,
        planned_hours=round(planned_seconds / 3600, 4),
        validated_hours=round(validated_seconds / 3600, 4),
        progress_percent=progress,
        last_activity_at=last_activity,
        inactive_days=inactive_days,
        alerts=codes,
    )


def _expected_progress(classroom: Classroom, today: date) -> float:
    if today < classroom.start_date:
        return 0.0
    if today >= classroom.end_date:
        return 100.0
    total_days = max(1, (classroom.end_date - classroom.start_date).days)
    elapsed_days = (today - classroom.start_date).days
    return round(elapsed_days * 100 / total_days, 2)


def _alert_count(students: list[StudentProgress], code: str) -> int:
    return sum(
        any(alert.code == code for alert in student.alerts) for student in students
    )


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
