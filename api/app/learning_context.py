"""Resolve persisted contextual enrollment, checking current and legacy lineage."""
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from .auth import access_claims
from .classrooms import StudentProgress, _expected_progress, _student_progress
from .evidence import _active_student, _staff
from .models import ClassEnrollment, Classroom, CohortMembership, CourseVersion, Program, ProgramCourse, User

router = APIRouter(tags=["learning-context"])


class LearningContext(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    user_id: str
    organization_id: str
    program_id: str
    cohort_id: str
    membership_id: str
    role: Literal["student"]
    course_id: str
    course_version_id: str
    enrollment_id: str
    legacy_enrollment_id: str
    permissions: tuple[str, ...]


class LearningContextSnapshot(BaseModel):
    context: LearningContext
    progress: StudentProgress
    resolved_at: datetime
    contract_version: Literal["cohort-enrollment-v2"] = "cohort-enrollment-v2"


def resolve_student_context(session: Session, class_id: str, user_id: str) -> LearningContextSnapshot:
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(404, "Turma não encontrada.")
    if not _active_student(session, classroom, user_id):
        raise HTTPException(403, "Matrícula e vínculo ativos são necessários.")
    version = session.get(CourseVersion, classroom.course_version_id) if classroom.course_version_id else None
    if version is None or version.course_id != classroom.course_id or version.status not in {"published", "archived"}:
        raise HTTPException(409, "A edição desta turma precisa ser conferida pela equipe.")
    membership = session.get(ClassEnrollment, (class_id, user_id))
    if not membership.context_id or not membership.membership_id or membership.course_version_id != version.id:
        raise HTTPException(409, "A matrícula contextual precisa ser reconciliada pela equipe.")
    persisted = session.get(CohortMembership, membership.membership_id)
    if (persisted is None or persisted.status != "active" or persisted.role != "student"
            or persisted.class_id != class_id or persisted.user_id != user_id):
        raise HTTPException(403, "Vínculo contextual inativo ou inconsistente.")
    program = session.get(Program, classroom.program_id)
    offering = session.get(ProgramCourse, (classroom.program_id, classroom.course_id))
    user = session.get(User, user_id)
    if program is None or offering is None or user is None:
        raise HTTPException(409, "A linhagem da matrícula precisa ser conferida pela equipe.")
    now = datetime.now(timezone.utc)
    context = LearningContext(
        user_id=user_id,
        organization_id=program.institution_id,
        program_id=program.id,
        cohort_id=classroom.id,
        membership_id=persisted.id,
        role="student",  # ClassEnrollment is the actual learner link, not User.role.
        course_id=classroom.course_id,
        course_version_id=version.id,
        enrollment_id=membership.context_id,
        legacy_enrollment_id=membership.enrollment_id,
        permissions=("content.read", "progress.read", "activity.record"),
    )
    return LearningContextSnapshot(
        context=context,
        progress=_student_progress(
            session, classroom=classroom, membership=membership, user=user,
            planned_seconds=offering.planned_seconds,
            expected_percent=_expected_progress(classroom, now.date()), now=now,
        ),
        resolved_at=now,
    )


def _require_enabled(request: Request) -> None:
    if not request.app.state.settings.learning_context_enabled:
        raise HTTPException(404, "Contexto de aprendizagem não habilitado neste ambiente.")


@router.get("/classes/{class_id}/learning-context", response_model=LearningContextSnapshot)
def own_context(class_id: str, request: Request, claims: dict = Depends(access_claims)):
    _require_enabled(request)
    with Session(request.app.state.database.engine) as session:
        return resolve_student_context(session, class_id, claims["sub"])


@router.get("/classes/{class_id}/students/{user_id}/learning-context", response_model=LearningContextSnapshot)
def observed_context(class_id: str, user_id: str, request: Request, claims: dict = Depends(access_claims)):
    _require_enabled(request)
    with Session(request.app.state.database.engine) as session:
        classroom = session.get(Classroom, class_id)
        if classroom is None:
            raise HTTPException(404, "Turma não encontrada.")
        _staff(session, classroom, claims, monitor=True)
        return resolve_student_context(session, class_id, user_id)
