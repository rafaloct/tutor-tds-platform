from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, require_roles
from .database import Database
from .course_editor import latest_published_version, ensure_legacy_course_version
from .evidence import _active_student, _is_staff, _staff
from .context_memberships import active_student_binding, bind_membership, bind_student
from .classroom_policy import require_available_seat
from .models import (
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Course,
    CourseVersion,
    Enrollment,
    LearningEventRecord,
    MentorshipCase,
    ProgramCourse,
    ProgramMembership,
    SessionPresence,
    StudentBaseline,
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
    offer_municipality: str | None = Field(default=None, max_length=240)
    offer_location: str | None = Field(default=None, max_length=500)
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
    course_version_id: str | None = None


class ClassroomDetail(ClassroomResponse):
    student_ids: list[str]
    monitor_ids: list[str]


class ClassroomPage(BaseModel):
    classes: list[ClassroomResponse]


class EligibleStudent(BaseModel):
    user_id: str
    name: str


class EligibleStudentPage(BaseModel):
    students: list[EligibleStudent]
    next_offset: int | None


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
    context_enrollment_id: str | None = None
    status: str
    planned_hours: float
    validated_hours: float
    progress_percent: float
    last_activity_at: datetime | None
    inactive_days: int
    alerts: list[StudentAlert]
    baseline_linked: bool = False
    confirmed_sessions: int = 0
    open_mentorship_cases: int = 0


class DashboardSummary(BaseModel):
    total_students: int
    inactive_students: int
    pending_students: int
    below_expected_students: int
    baseline_linked_students: int = 0
    confirmed_participations: int = 0
    open_mentorship_cases: int = 0


class ClassroomDashboard(BaseModel):
    classroom: ClassroomResponse
    generated_at: datetime
    expected_progress_percent: float
    summary: DashboardSummary
    students: list[StudentProgress]


class MonitorExceptionItem(BaseModel):
    user_id: str
    name: str
    alerts: list[StudentAlert]


class MonitorExceptionsResponse(BaseModel):
    generated_at: datetime
    total_students: int
    attention_students: int
    students: list[MonitorExceptionItem]


def _class_lifecycle_enabled(request: Request) -> bool:
    settings = getattr(request.app.state, "settings", None)
    return bool(getattr(settings, "class_lifecycle_enabled", False))


@admin_router.post("", response_model=ClassroomResponse, status_code=201)
def create_classroom(
    payload: ClassroomCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> ClassroomResponse:
    if (
        _class_lifecycle_enabled(request)
        and payload.status != "planned"
    ):
        raise HTTPException(
            status_code=422,
            detail="Novas turmas devem iniciar em planned e ser ativadas pela coordenação.",
        )
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
        course = session.get(Course, payload.course_id)
        if course is None or not course.active:
            raise HTTPException(422, "Curso não está publicado para novas turmas.")
        version = latest_published_version(session, course.id)
        if version is None:
            # Compatibility for initial catalog imported before versioning.
            version = ensure_legacy_course_version(session, course)
        if version.status != "published":
            raise HTTPException(409, "Curso não possui versão publicada.")
        record = Classroom(
            id=str(uuid4()),
            program_id=payload.program_id,
            course_id=payload.course_id,
            course_version_id=version.id,
            teacher_id=payload.teacher_id,
            name=payload.name.strip(),
            offer_municipality=(
                payload.offer_municipality.strip()
                if payload.offer_municipality
                else None
            ),
            offer_location=(
                payload.offer_location.strip()
                if payload.offer_location
                else None
            ),
            start_date=payload.start_date,
            end_date=payload.end_date,
            status=payload.status,
        )
        session.add(record)
        session.flush()
        bind_membership(session, record.id, record.teacher_id, "teacher")
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
        classroom = session.scalar(
            select(Classroom).where(Classroom.id == class_id).with_for_update()
        )
        if classroom is None:
            raise HTTPException(status_code=404, detail="Turma não encontrada.")
        _require_open_classroom(classroom)
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
        require_available_seat(session, classroom)
        link = ClassEnrollment(
                class_id=class_id,
                user_id=user_id,
                enrollment_id=enrollment.id,
                program_id=classroom.program_id,
                course_id=classroom.course_id,
                status="active",
            )
        session.add(link)
        _bind_context(session, classroom, link, request)
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
        if (
            _class_lifecycle_enabled(request)
            and classroom.status != "planned"
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    "Equipe de turma iniciada deve ser alterada pelo fluxo "
                    "contextual da coordenação."
                ),
            )
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
        bind_membership(session, class_id, user_id, "monitor")
        _commit(session, "Não foi possível adicionar o monitor.")
        return {"class_id": class_id, "user_id": user_id}


@router.get("/{class_id}/eligible-students", response_model=EligibleStudentPage)
def eligible_students(
    class_id: str,
    request: Request,
    q: str = Query(default="", max_length=100),
    offset: int = Query(default=0, ge=0, le=100000),
    limit: int = Query(default=20, ge=1, le=50),
    claims: dict[str, str] = Depends(access_claims),
) -> EligibleStudentPage:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        _require_teacher_or_admin(session, classroom, claims)
        _require_open_classroom(classroom)
        existing = select(ClassEnrollment.user_id).where(
            ClassEnrollment.class_id == class_id,
            ClassEnrollment.status == "active",
        )
        statement = (
            select(User.id, User.name)
            .join(Enrollment, Enrollment.user_id == User.id)
            .where(
                Enrollment.program_id == classroom.program_id,
                Enrollment.course_id == classroom.course_id,
                Enrollment.status == "active",
                User.id.not_in(existing),
            )
        )
        if q.strip():
            statement = statement.where(
                User.name.icontains(q.strip(), autoescape=True)
            )
        records = session.execute(
            statement.order_by(User.name, User.id).offset(offset).limit(limit + 1)
        ).all()
        return EligibleStudentPage(
            students=[
                EligibleStudent(user_id=row.id, name=row.name)
                for row in records[:limit]
            ],
            next_offset=offset + limit if len(records) > limit else None,
        )


@router.put("/{class_id}/students/{user_id}")
def include_student(
    class_id: str,
    user_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, str]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        # Serializa inclusões concorrentes na turma em bancos com row locking.
        classroom = session.scalar(
            select(Classroom).where(Classroom.id == class_id).with_for_update()
        )
        if classroom is None:
            raise HTTPException(status_code=404, detail="Turma não encontrada.")
        _require_teacher_or_admin(session, classroom, claims)
        _require_open_classroom(classroom)
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
        membership = session.get(ClassEnrollment, (class_id, user_id))
        if membership is None:
            require_available_seat(session, classroom)
            membership = ClassEnrollment(
                    class_id=class_id,
                    user_id=user_id,
                    enrollment_id=enrollment.id,
                    program_id=classroom.program_id,
                    course_id=classroom.course_id,
                    status="active",
            )
            session.add(membership)
        elif membership.status != "active":
            require_available_seat(session, classroom)
            membership.status = "active"
        else:
            return {"class_id": class_id, "user_id": user_id, "status": "active"}
        _bind_context(session, classroom, membership, request)
        _commit(session, "Não foi possível incluir o estudante. Tente novamente.")
        return {"class_id": class_id, "user_id": user_id, "status": "active"}


def _bind_context(session, classroom, link, request):
    # Old servers/fixtures can still create unpinned links while the flag is off.
    # An enabled contextual journey must never guess an edition or write half a binding.
    enabled = getattr(getattr(request.app.state, "settings", None), "learning_context_enabled", False)
    if classroom.course_version_id is None and not enabled:
        return
    try:
        bind_student(session, classroom, link)
    except ValueError as error:
        raise HTTPException(409, "Matrícula contextual inconsistente; confira a edição da turma.") from error


def _require_open_classroom(classroom: Classroom) -> None:
    if classroom.status == "closed":
        raise HTTPException(
            status_code=409,
            detail="Esta turma está encerrada e não pode receber estudantes.",
        )


@router.get("/{class_id}", response_model=ClassroomDetail)
def class_detail(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> ClassroomDetail:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        _require_staff_access(session, classroom, claims)
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
    enrolled_only: bool = False,
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
        if enrolled_only:
            statement = statement.where(Classroom.id.in_(
                select(ClassEnrollment.class_id)
                .join(Classroom, Classroom.id == ClassEnrollment.class_id)
                .join(Enrollment, Enrollment.id == ClassEnrollment.enrollment_id)
                .join(ProgramMembership,
                      (ProgramMembership.user_id == ClassEnrollment.user_id)
                      & (ProgramMembership.program_id == ClassEnrollment.program_id))
                .where(ClassEnrollment.user_id == user_id,
                       ClassEnrollment.status == "active", Enrollment.status == "active",
                       ProgramMembership.status == "active", active_student_binding())
            ))
        elif claims["role"] != "admin":
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
        return ClassroomPage(classes=[_serialize(item) for item in records
            if (enrolled_only or _is_staff(session, item, user_id, claims["role"])
                or _active_student(session, item, user_id))])


@router.get("/{class_id}/course")
def classroom_course(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    """Read the class snapshot, never silently fall back to the public edition."""
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        if not _active_student(session, classroom, claims["sub"]):
            _staff(session, classroom, claims, monitor=True)
        version = session.get(CourseVersion, classroom.course_version_id) if classroom.course_version_id else None
        if version is None or version.course_id != classroom.course_id or version.status not in {"published", "archived"}:
            raise HTTPException(409, "A versão do curso desta turma precisa ser conferida pela equipe.")
        return {
            **version.content,
            "course_version_id": version.id,
            "version_id": version.id,
            "version_number": version.version_number,
            "legacy_progress_compatible": False,
            "class_id": classroom.id,
        }


@router.get("/{class_id}/dashboard", response_model=ClassroomDashboard)
def class_dashboard(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> ClassroomDashboard:
    """Retorna o dashboard pedagógico completo para professor/admin."""
    now = datetime.now(timezone.utc)
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        classroom = _classroom(session, class_id)
        _require_teacher_or_admin(session, classroom, claims)
        offering = session.get(
            ProgramCourse, (classroom.program_id, classroom.course_id)
        )
        if offering is None:
            raise HTTPException(status_code=409, detail="Oferta da turma inconsistente.")

        expected_percent = _expected_progress(classroom, now.date())
        roster = (
            select(ClassEnrollment, User)
            .join(Classroom, Classroom.id == ClassEnrollment.class_id)
            .join(User, User.id == ClassEnrollment.user_id)
            .join(Enrollment, Enrollment.id == ClassEnrollment.enrollment_id)
            .join(ProgramMembership, (ProgramMembership.user_id == ClassEnrollment.user_id) & (ProgramMembership.program_id == ClassEnrollment.program_id))
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.program_id == classroom.program_id,
                ClassEnrollment.course_id == classroom.course_id,
                ClassEnrollment.status == "active",
                Enrollment.user_id == ClassEnrollment.user_id,
                Enrollment.program_id == ClassEnrollment.program_id,
                Enrollment.course_id == ClassEnrollment.course_id,
                Enrollment.status == "active",
                ProgramMembership.status == "active",
                active_student_binding(),
            )
        )
        memberships = session.execute(roster.order_by(User.name, User.id)).all()
        aggregates = _followup_counts(session, classroom, roster.with_only_columns(ClassEnrollment.user_id, ClassEnrollment.enrollment_id).subquery()) if memberships else {}
        students = [
            _student_progress(
                session,
                classroom=classroom,
                membership=membership,
                user=user,
                planned_seconds=offering.planned_seconds,
                expected_percent=expected_percent,
                now=now,
                followup_counts=aggregates.get((membership.user_id, membership.enrollment_id), {}),
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
                baseline_linked_students=sum(student.baseline_linked for student in students),
                confirmed_participations=sum(student.confirmed_sessions for student in students),
                open_mentorship_cases=sum(student.open_mentorship_cases for student in students),
            ),
            students=students,
        )


@router.get(
    "/{class_id}/monitor-exceptions",
    response_model=MonitorExceptionsResponse,
)
def monitor_exceptions(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MonitorExceptionsResponse:
    """Retorna somente sinais acionáveis necessários ao acompanhamento do monitor."""
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
        roster = (
            select(ClassEnrollment, User)
            .join(Classroom, Classroom.id == ClassEnrollment.class_id)
            .join(User, User.id == ClassEnrollment.user_id)
            .join(Enrollment, Enrollment.id == ClassEnrollment.enrollment_id)
            .join(
                ProgramMembership,
                (ProgramMembership.user_id == ClassEnrollment.user_id)
                & (ProgramMembership.program_id == ClassEnrollment.program_id),
            )
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.program_id == classroom.program_id,
                ClassEnrollment.course_id == classroom.course_id,
                ClassEnrollment.status == "active",
                Enrollment.user_id == ClassEnrollment.user_id,
                Enrollment.program_id == ClassEnrollment.program_id,
                Enrollment.course_id == ClassEnrollment.course_id,
                Enrollment.status == "active",
                ProgramMembership.status == "active",
                active_student_binding(),
            )
        )
        memberships = session.execute(roster.order_by(User.name, User.id)).all()
        actionable_codes = {
            "inactive_7_days",
            "required_activity_pending",
            "below_expected_hours",
        }
        attention: list[MonitorExceptionItem] = []
        for membership, user in memberships:
            progress = _student_progress(
                session,
                classroom=classroom,
                membership=membership,
                user=user,
                planned_seconds=offering.planned_seconds,
                expected_percent=expected_percent,
                now=now,
                followup_counts={},
            )
            alerts = [
                alert for alert in progress.alerts if alert.code in actionable_codes
            ]
            if alerts:
                attention.append(
                    MonitorExceptionItem(
                        user_id=user.id,
                        name=user.name,
                        alerts=alerts,
                    )
                )

        return MonitorExceptionsResponse(
            generated_at=now,
            total_students=len(memberships),
            attention_students=len(attention),
            students=attention,
        )


def _followup_counts(session: Session, classroom: Classroom, eligible) -> dict:
    """Three grouped queries, independent of roster size; no private narratives."""
    result: dict = {}
    for model, field in ((StudentBaseline, "baseline_linked"), (SessionPresence, "confirmed_sessions"), (MentorshipCase, "open_mentorship_cases")):
        query = select(model.user_id, model.enrollment_id, func.count()).join(
            eligible, (eligible.c.user_id == model.user_id) & (eligible.c.enrollment_id == model.enrollment_id),
        ).where(model.class_id == classroom.id, model.program_id == classroom.program_id, model.course_id == classroom.course_id)
        if model is SessionPresence:
            query = query.where(model.status == "confirmed_present")
        elif model is MentorshipCase:
            query = query.where(model.status.in_(("open", "in_progress")))
        for user_id, enrollment_id, count in session.execute(query.group_by(model.user_id, model.enrollment_id)):
            result.setdefault((user_id, enrollment_id), {})[field] = bool(count) if model is StudentBaseline else count
    return result


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
    _staff(session, classroom, claims, monitor=True)


def _require_teacher_or_admin(
    session: Session,
    classroom: Classroom,
    claims: dict[str, str],
) -> None:
    """Actions that expose hours or change the classroom roster are not monitor exceptions."""
    if claims["role"] == "admin":
        return
    _staff(session, classroom, claims, monitor=False)


def _student_progress(
    session: Session,
    *,
    classroom: Classroom,
    membership: ClassEnrollment,
    user: User,
    planned_seconds: int,
    expected_percent: float,
    now: datetime,
    followup_counts: dict | None = None,
) -> StudentProgress:
    if followup_counts is None:
        eligible = select(ClassEnrollment.user_id, ClassEnrollment.enrollment_id).where(
            ClassEnrollment.class_id == classroom.id, ClassEnrollment.user_id == user.id).subquery()
        followup_counts = _followup_counts(session, classroom, eligible).get((user.id, membership.enrollment_id), {})
    validated, last_activity, completed = session.execute(
        select(
            func.coalesce(func.sum(LearningEventRecord.validated_seconds), 0),
            func.max(LearningEventRecord.occurred_at),
            func.count().filter(
                LearningEventRecord.event_type == "lesson_completed"
            ),
        ).where(
            LearningEventRecord.enrollment_id == membership.enrollment_id,
            LearningEventRecord.user_id == membership.user_id,
            LearningEventRecord.course_id == classroom.course_id,
            classroom.course_version_id is not None,
            LearningEventRecord.payload["class_id"].as_string() == classroom.id,
            LearningEventRecord.payload["course_version_id"].as_string() == classroom.course_version_id,
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
        context_enrollment_id=membership.context_id,
        status=membership.status,
        planned_hours=round(planned_seconds / 3600, 4),
        validated_hours=round(validated_seconds / 3600, 4),
        progress_percent=progress,
        last_activity_at=last_activity,
        inactive_days=inactive_days,
        alerts=codes,
        **followup_counts,
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
        course_version_id=record.course_version_id,
        teacher_id=record.teacher_id,
        name=record.name,
        offer_municipality=record.offer_municipality,
        offer_location=record.offer_location,
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
