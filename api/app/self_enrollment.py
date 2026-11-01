"""Spontaneous enrollment into open classes behind SELF_ENROLLMENT_ENABLED.

Open classes (enrollment_policy='open') accept self-service enrollment: the same
membership -> enrollment -> class enrollment -> cohort membership chain used by
staff commands, persisted in one transaction with an operator-style receipt.
Managed classes keep the staff-only path unchanged.
"""
from __future__ import annotations

import hashlib
import hmac
import json
from datetime import date, datetime, timezone
from typing import Literal
from uuid import NAMESPACE_URL, uuid4, uuid5

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .context_memberships import bind_membership, bind_student, membership_id
from .course_editor import latest_published_version
from .learning_context import LearningContextSnapshot, resolve_student_context
from .models import (
    ClassEnrollment,
    Classroom,
    Course,
    Enrollment,
    ExternalSyncRequest,
    OperatorCommandReceipt,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)
from .operator_operations import revision, snapshot

router = APIRouter(tags=["self-enrollment"])

OPEN_CLASS_END = date(2100, 12, 31)
RESPONSIBLE_ROLES = ("teacher", "coordinator", "admin", "program_operator")
LEARNPRESS_KIND = "learnpress_enroll"


class OpenClassItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    program_id: str
    course_id: str
    course_title: str
    course_version_id: str | None
    name: str
    start_date: date
    end_date: date
    status: str
    enrollment_policy: Literal["open"]
    viewer_enrolled: bool


class OpenClassPage(BaseModel):
    classes: list[OpenClassItem]


def _enabled(request: Request) -> None:
    if not request.app.state.settings.self_enrollment_enabled:
        raise HTTPException(status_code=404, detail="Auto-matrícula indisponível.")


def _open_class(session: Session, course_id: str) -> Classroom | None:
    return session.scalar(
        select(Classroom)
        .where(
            Classroom.course_id == course_id,
            Classroom.enrollment_policy == "open",
            Classroom.status != "closed",
        )
        .order_by(Classroom.id)
        .limit(1)
    )


def _responsible(session: Session, program_id: str) -> str | None:
    members = session.scalars(
        select(ProgramMembership)
        .where(
            ProgramMembership.program_id == program_id,
            ProgramMembership.status == "active",
        )
        .order_by(ProgramMembership.user_id)
    ).all()
    for role in RESPONSIBLE_ROLES:
        for member in members:
            if member.role == role:
                return member.user_id
    return None


def _provision_open_class(session: Session, course: Course, today: date) -> Classroom:
    """Create the single open class for the course, or return an existing one.

    The partial unique index on classes(course_id) where the class is open and
    not closed makes concurrent provisioning converge to one row.
    """
    version = latest_published_version(session, course.id)
    if version is None:
        raise HTTPException(
            status_code=409, detail="Curso não possui edição publicada."
        )
    offerings = session.scalars(
        select(ProgramCourse)
        .where(ProgramCourse.course_id == course.id)
        .order_by(ProgramCourse.program_id)
    ).all()
    for offering in offerings:
        responsible = _responsible(session, offering.program_id)
        if responsible is None:
            continue
        classroom = Classroom(
            id=str(uuid4()),
            program_id=offering.program_id,
            course_id=course.id,
            course_version_id=version.id,
            teacher_id=responsible,
            name=f"Turma Aberta — {course.title}"[:240],
            start_date=today,
            end_date=OPEN_CLASS_END,
            status="active",
            enrollment_policy="open",
        )
        session.add(classroom)
        try:
            with session.begin_nested():
                session.flush()
        except IntegrityError:
            existing = _open_class(session, course.id)
            if existing is None:
                raise HTTPException(
                    status_code=409,
                    detail="Turma aberta concorrente indisponível; tente novamente.",
                ) from None
            return existing
        bind_membership(session, classroom.id, responsible, "teacher")
        return classroom
    if not offerings:
        raise HTTPException(
            status_code=409, detail="Curso não é ofertado por nenhum programa."
        )
    raise HTTPException(
        status_code=409,
        detail="Nenhum programa ofertante possui responsável para a turma aberta.",
    )


def _enrollment_chain(session: Session, classroom: Classroom, user_id: str) -> None:
    member = session.get(ProgramMembership, (user_id, classroom.program_id))
    if member is None:
        session.add(
            ProgramMembership(
                user_id=user_id,
                program_id=classroom.program_id,
                role="student",
                status="active",
            )
        )
        session.flush()
    elif member.status != "active":
        raise HTTPException(
            status_code=409,
            detail="Vínculo de programa inativo exige revisão pela equipe.",
        )
    enrollment = session.scalar(
        select(Enrollment).where(
            Enrollment.user_id == user_id,
            Enrollment.program_id == classroom.program_id,
            Enrollment.course_id == classroom.course_id,
        )
    )
    if enrollment is None:
        enrollment = Enrollment(
            id=str(uuid4()),
            user_id=user_id,
            program_id=classroom.program_id,
            course_id=classroom.course_id,
            status="active",
        )
        session.add(enrollment)
        session.flush()
    elif enrollment.status != "active":
        raise HTTPException(
            status_code=409,
            detail="Matrícula inativa exige revisão pela equipe.",
        )
    link = session.get(ClassEnrollment, (classroom.id, user_id))
    if link is None:
        link = ClassEnrollment(
            class_id=classroom.id,
            user_id=user_id,
            enrollment_id=enrollment.id,
            program_id=classroom.program_id,
            course_id=classroom.course_id,
            status="active",
        )
        session.add(link)
        session.flush()
    elif link.enrollment_id != enrollment.id or (
        link.course_version_id not in {None, classroom.course_version_id}
    ):
        raise HTTPException(status_code=409, detail="Linhagem divergente.")
    else:
        link.status = "active"
    if link.context_id is None or link.course_version_id != classroom.course_version_id:
        try:
            bind_student(session, classroom, link)
        except ValueError:
            raise HTTPException(
                status_code=409, detail="Edição ou vínculo inconsistente."
            ) from None


def _receipt(
    session: Session,
    request: Request,
    classroom: Classroom,
    user_id: str,
) -> None:
    receipt_id = str(
        uuid5(
            NAMESPACE_URL,
            f"tds:self-enroll:{json.dumps([classroom.id, user_id], separators=(',', ':'))}",
        )
    )
    if session.get(OperatorCommandReceipt, receipt_id) is not None:
        return
    secret = request.app.state.settings.require_auth_secrets()[0]
    body = {
        "action": "enroll",
        "actor": user_id,
        "class_id": classroom.id,
        "course_id": classroom.course_id,
        "program_id": classroom.program_id,
        "reason": "self_enroll_open_class",
        "subject": user_id,
    }
    digest = hmac.new(
        secret.encode(),
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode(),
        hashlib.sha256,
    ).hexdigest()
    person = session.get(User, user_id)
    program = session.get(Program, classroom.program_id)
    session.add(
        OperatorCommandReceipt(
            id=receipt_id,
            actor_id=user_id,
            subject_id=user_id,
            program_id=classroom.program_id,
            class_id=classroom.id,
            revision=revision(session, classroom.program_id, user_id) + 1,
            action="enroll",
            reason="self_enroll_open_class",
            request_hash=digest,
            result=snapshot(session, classroom, program, person),
            occurred_at=datetime.now(timezone.utc),
        )
    )


def _enqueue_sync(
    session: Session,
    request: Request,
    classroom: Classroom,
    user_id: str,
) -> None:
    if not request.app.state.settings.learnpress_sync_enabled:
        return
    natural = session.scalar(
        select(ExternalSyncRequest.id).where(
            ExternalSyncRequest.kind == LEARNPRESS_KIND,
            ExternalSyncRequest.user_id == user_id,
            ExternalSyncRequest.course_id == classroom.course_id,
        )
    )
    if natural is not None:
        return
    session.add(
        ExternalSyncRequest(
            id=f"{LEARNPRESS_KIND}:{classroom.course_id}:{user_id}",
            kind=LEARNPRESS_KIND,
            user_id=user_id,
            class_id=classroom.id,
            course_id=classroom.course_id,
            payload={"course_slug": classroom.course_id},
        )
    )


@router.get("/open-classes", response_model=OpenClassPage)
def open_classes(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> OpenClassPage:
    _enabled(request)
    with Session(request.app.state.database.engine) as session:
        rows = session.execute(
            select(Classroom, Course.title)
            .join(Course, Course.id == Classroom.course_id)
            .where(
                Classroom.enrollment_policy == "open",
                Classroom.status != "closed",
            )
            .order_by(Course.title, Classroom.id)
        ).all()
        enrolled = set(
            session.scalars(
                select(ClassEnrollment.class_id).where(
                    ClassEnrollment.user_id == claims["sub"],
                    ClassEnrollment.status == "active",
                )
            )
        )
        return OpenClassPage(
            classes=[
                OpenClassItem(
                    id=classroom.id,
                    program_id=classroom.program_id,
                    course_id=classroom.course_id,
                    course_title=title,
                    course_version_id=classroom.course_version_id,
                    name=classroom.name,
                    start_date=classroom.start_date,
                    end_date=classroom.end_date,
                    status=classroom.status,
                    enrollment_policy="open",
                    viewer_enrolled=classroom.id in enrolled,
                )
                for classroom, title in rows
            ]
        )


@router.post(
    "/courses/{course_id}/self-enroll",
    response_model=LearningContextSnapshot,
)
def self_enroll(
    course_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> LearningContextSnapshot:
    _enabled(request)
    user_id = claims["sub"]
    with Session(request.app.state.database.engine) as session:
        course = session.get(Course, course_id)
        if course is None or not course.active:
            raise HTTPException(status_code=404, detail="Curso não encontrado.")
        classroom = _open_class(session, course.id)
        if classroom is None:
            classroom = _provision_open_class(
                session, course, datetime.now(timezone.utc).date()
            )
        if classroom.status == "closed":
            raise HTTPException(status_code=409, detail="Turma aberta encerrada.")
        try:
            _enrollment_chain(session, classroom, user_id)
            _receipt(session, request, classroom, user_id)
            _enqueue_sync(session, request, classroom, user_id)
            session.commit()
        except IntegrityError:
            session.rollback()
            raise HTTPException(
                status_code=409,
                detail="Conflito de matrícula. Consulte novamente.",
            ) from None
        return resolve_student_context(session, classroom.id, user_id)
