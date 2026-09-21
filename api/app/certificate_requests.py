"""Human decisions only: approval never issues a certificate.

Unversioned legacy events count only for the deterministic original UUID5 edition
and a request without a class. A class request always requires exact class evidence.
Owner deletion removes private requests and their audit; departed reviewer IDs may
be nulled in other people's history without changing decisions, reasons or dates.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .course_editor import legacy_version_id
from .models import CertificateRequest, CertificateRequestTransition, ClassEnrollment, Classroom, Course, CourseVersion, CourseVersionTransition, Enrollment, Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User

router = APIRouter(prefix="/certificate-requests", tags=["certificate-requests"])


class RequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    enrollment_id: str = Field(min_length=1, max_length=36)
    course_version_id: str = Field(min_length=1, max_length=36)
    class_id: str | None = Field(default=None, min_length=1, max_length=36)


class RevisionAction(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_revision: int = Field(ge=1)


class ReviewCreate(RevisionAction):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    decision: Literal["approve", "reject"]
    reason: str = Field(min_length=3, max_length=500)


def _public_version(session: Session, version: CourseVersion) -> bool:
    if version.status == "published":
        course = session.get(Course, version.course_id)
        return course is not None and course.active
    return version.status == "archived" and session.scalar(select(CourseVersionTransition.id).where(CourseVersionTransition.version_id == version.id, CourseVersionTransition.to_status == "published").limit(1)) is not None


def _context(session: Session, user_id: str, enrollment_id: str, version_id: str, class_id: str | None):
    enrollment = session.get(Enrollment, enrollment_id)
    if enrollment is None or enrollment.user_id != user_id:
        raise HTTPException(404, "Matrícula não encontrada.")
    membership = session.get(ProgramMembership, (user_id, enrollment.program_id))
    if enrollment.status != "active" or membership is None or membership.status != "active":
        raise HTTPException(422, "Matrícula/vínculo de programa inativo.")
    version = session.get(CourseVersion, version_id)
    if version is None or version.course_id != enrollment.course_id or version.status not in {"published", "archived"}:
        raise HTTPException(422, "Edição não publicada ou incompatível com a matrícula.")
    classroom = None
    if class_id is not None:
        classroom = session.get(Classroom, class_id)
        link = session.get(ClassEnrollment, (class_id, user_id))
        if classroom is None or link is None or link.status != "active" or link.enrollment_id != enrollment.id or link.program_id != enrollment.program_id or link.course_id != enrollment.course_id or classroom.program_id != enrollment.program_id or classroom.course_id != enrollment.course_id or classroom.course_version_id != version.id:
            raise HTTPException(422, "Turma, matrícula e edição não correspondem a um vínculo ativo.")
    elif not _public_version(session, version):
        raise HTTPException(422, "Edição sem publicação pública comprovada.")
    offering = session.get(ProgramCourse, (enrollment.program_id, enrollment.course_id))
    program = session.get(Program, enrollment.program_id)
    institution = session.get(Institution, program.institution_id) if program else None
    user = session.get(User, user_id)
    if offering is None or program is None or institution is None or user is None:
        raise HTTPException(409, "Hierarquia acadêmica inconsistente.")
    return enrollment, version, classroom, offering, program, institution, user


def _eligibility(session: Session, enrollment: Enrollment, version_id: str, class_id: str | None, required_seconds: int) -> dict[str, Any]:
    event_version = LearningEventRecord.payload["course_version_id"].as_string()
    version_filter = event_version == version_id
    if version_id == legacy_version_id(enrollment.course_id) and class_id is None:
        version_filter = or_(version_filter, event_version.is_(None))
    filters = [LearningEventRecord.enrollment_id == enrollment.id, LearningEventRecord.user_id == enrollment.user_id, LearningEventRecord.course_id == enrollment.course_id, version_filter]
    if class_id is not None:
        filters.append(LearningEventRecord.payload["class_id"].as_string() == class_id)
    seconds = int(session.scalar(select(func.coalesce(func.sum(LearningEventRecord.validated_seconds), 0)).where(*filters, LearningEventRecord.event_type == "study_activity")) or 0)
    completed = session.scalar(select(LearningEventRecord.event_id).where(*filters, LearningEventRecord.event_type == "lesson_completed").limit(1)) is not None
    return {"required_seconds": required_seconds, "validated_seconds": seconds, "completed": completed, "eligible": completed and seconds >= required_seconds}


def _request_eligibility(session: Session, record: CertificateRequest) -> dict[str, Any]:
    enrollment = session.get(Enrollment, record.enrollment_id)
    if enrollment is None:
        return {"required_seconds": record.required_seconds, "validated_seconds": 0, "completed": False, "eligible": False}
    result = _eligibility(session, enrollment, record.course_version_id, record.class_id, record.required_seconds)
    try:
        context = _context(session, record.user_id, record.enrollment_id, record.course_version_id, record.class_id)
        if context[5].id != record.institution_id:
            result["eligible"] = False
    except HTTPException:
        result["eligible"] = False
    return result


def _reviewer_role(session: Session, record: CertificateRequest, user_id: str) -> str | None:
    user = session.get(User, user_id)
    if user is None:
        return None
    if user.role == "admin":
        return "admin"
    membership = session.get(ProgramMembership, (user_id, record.program_id))
    if membership is None or membership.status != "active":
        return None
    if membership.role in {"coordinator", "admin"}:
        return membership.role
    classroom = session.get(Classroom, record.class_id) if record.class_id else None
    if membership.role == "teacher" and classroom is not None and classroom.teacher_id == user_id and classroom.program_id == record.program_id:
        return "teacher"
    return None


def _view(session: Session, record: CertificateRequest) -> dict[str, Any]:
    result = {field: getattr(record, field) for field in ("id", "enrollment_id", "course_id", "course_version_id", "class_id", "program_id", "holder_name", "course_title", "program_name", "institution_name", "status", "revision", "requested_at", "reviewed_at", "review_reason")}
    classroom = session.get(Classroom, record.class_id) if record.class_id else None
    result["class_name"] = classroom.name if classroom else None
    for field in ("requested_at", "reviewed_at"):
        value = result[field]
        if value is not None:
            result[field] = value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
    return result | {"eligibility": _request_eligibility(session, record)}


def _visible(session: Session, identity: str, user_id: str) -> CertificateRequest:
    record = session.get(CertificateRequest, identity)
    if record is None or (record.user_id != user_id and _reviewer_role(session, record, user_id) is None):
        raise HTTPException(404, "Pedido não encontrado.")
    return record


def _audit(session: Session, record: CertificateRequest, previous: str | None, user_id: str, role: str, reason: str | None, eligibility: dict[str, Any]):
    session.add(CertificateRequestTransition(id=str(uuid4()), request_id=record.id, revision=record.revision, from_status=previous, to_status=record.status, actor_user_id=user_id, actor_role=role, reason=reason, eligibility=eligibility))


@router.get("/contexts")
def contexts(request: Request, course_id: str = Query(min_length=1, max_length=120), course_version_id: str = Query(min_length=1, max_length=36), claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        result = []
        for enrollment in session.scalars(select(Enrollment).where(Enrollment.user_id == claims["sub"], Enrollment.course_id == course_id, Enrollment.status == "active").order_by(Enrollment.id)):
            classes = session.scalars(select(ClassEnrollment.class_id).where(ClassEnrollment.enrollment_id == enrollment.id, ClassEnrollment.user_id == claims["sub"], ClassEnrollment.status == "active")).all()
            for class_id in [None, *classes]:
                try:
                    _, version, classroom, offering, program, _, _ = _context(session, claims["sub"], enrollment.id, course_version_id, class_id)
                except HTTPException:
                    continue
                existing = session.scalar(select(CertificateRequest).where(CertificateRequest.enrollment_id == enrollment.id, CertificateRequest.course_version_id == version.id))
                required = existing.required_seconds if existing is not None else offering.planned_seconds
                result.append({"enrollment_id": enrollment.id, "program_name": program.name, "class_id": class_id, "class_name": classroom.name if classroom else None, "course_version_id": version.id, "course_title": version.content["title"], "eligibility": _eligibility(session, enrollment, version.id, class_id, required)})
        return {"contexts": result}


@router.post("", status_code=201)
def create(payload: RequestCreate, request: Request, response: Response, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        context = _context(session, claims["sub"], payload.enrollment_id, payload.course_version_id, payload.class_id)
        enrollment, version, _, offering, program, institution, user = context
        existing = session.scalar(select(CertificateRequest).where(CertificateRequest.enrollment_id == enrollment.id, CertificateRequest.course_version_id == version.id))
        if existing is not None:
            if existing.class_id != payload.class_id:
                raise HTTPException(409, "Pedido já existe para esta matrícula/edição com outro contexto de turma.")
            response.status_code = 200
            return _view(session, existing)
        record = CertificateRequest(id=str(uuid4()), user_id=user.id, enrollment_id=enrollment.id, course_id=enrollment.course_id, course_version_id=version.id, class_id=payload.class_id, program_id=program.id, institution_id=institution.id, holder_name=user.name, course_title=version.content["title"], program_name=program.name, institution_name=institution.name, required_seconds=offering.planned_seconds, status="pending", revision=1)
        eligibility = _eligibility(session, enrollment, version.id, payload.class_id, record.required_seconds)
        session.add(record)
        try:
            session.flush()
            _audit(session, record, None, user.id, "learner", None, eligibility)
            session.commit()
        except IntegrityError as error:
            session.rollback()
            existing = session.scalar(select(CertificateRequest).where(CertificateRequest.enrollment_id == payload.enrollment_id, CertificateRequest.course_version_id == payload.course_version_id))
            if existing is not None and existing.user_id == claims["sub"] and existing.class_id == payload.class_id:
                response.status_code = 200
                return _view(session, existing)
            raise HTTPException(409, "Pedido concorrente/inconsistente. Recarregue.") from error
        return _view(session, record)


@router.get("")
def own(request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        return {"requests": [_view(session, record) for record in session.scalars(select(CertificateRequest).where(CertificateRequest.user_id == claims["sub"]).order_by(CertificateRequest.requested_at.desc()))]}


@router.get("/review-queue")
def queue(request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        actor = session.get(User, claims["sub"])
        programs = select(ProgramMembership.program_id).where(
            ProgramMembership.user_id == claims["sub"],
            ProgramMembership.status == "active",
            ProgramMembership.role.in_(("coordinator", "admin")),
        )
        classes = select(Classroom.id).join(
            ProgramMembership, ProgramMembership.program_id == Classroom.program_id,
        ).where(
            Classroom.teacher_id == claims["sub"],
            ProgramMembership.user_id == claims["sub"],
            ProgramMembership.status == "active",
            ProgramMembership.role == "teacher",
        )
        global_admin = actor is not None and actor.role == "admin"
        if actor is None or (not global_admin and not session.scalar(select(or_(programs.exists(), classes.exists())))):
            raise HTTPException(403, "Sem escopo de revisão autorizado.")
        query = select(CertificateRequest).where(CertificateRequest.status == "pending", CertificateRequest.user_id != claims["sub"])
        if not global_admin:
            query = query.where(or_(CertificateRequest.program_id.in_(programs), CertificateRequest.class_id.in_(classes)))
        records = session.scalars(query.order_by(CertificateRequest.requested_at)).all()
        return {"requests": [_view(session, record) for record in records]}


@router.get("/{request_id}")
def detail(request_id: str, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        return _view(session, _visible(session, request_id, claims["sub"]))


def _cas(session: Session, record: CertificateRequest, expected: int, **changes):
    result = session.execute(update(CertificateRequest).where(CertificateRequest.id == record.id, CertificateRequest.revision == expected, CertificateRequest.status == record.status).values(revision=expected + 1, **changes), execution_options={"synchronize_session": False})
    if result.rowcount != 1:
        raise HTTPException(409, "Pedido alterado por outra pessoa. Recarregue.")
    session.refresh(record)


@router.post("/{request_id}/review")
def review(request_id: str, payload: ReviewCreate, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        record = _visible(session, request_id, claims["sub"])
        role = _reviewer_role(session, record, claims["sub"])
        if role is None or record.user_id == claims["sub"]:
            raise HTTPException(403, "Revisão exige outra pessoa autorizada no programa/turma.")
        if record.revision != payload.expected_revision or record.status != "pending":
            raise HTTPException(409, "Pedido não está pendente nesta revisão.")
        # Lock the enrollment also used by study events to serialize evidence checks.
        session.scalar(select(Enrollment).where(Enrollment.id == record.enrollment_id).with_for_update())
        if payload.decision == "approve":
            context = _context(session, record.user_id, record.enrollment_id, record.course_version_id, record.class_id)
            if context[5].id != record.institution_id:
                raise HTTPException(409, "Instituição do programa mudou; revisão exige conferência institucional.")
        eligibility = _request_eligibility(session, record)
        if payload.decision == "approve" and not eligibility["eligible"]:
            raise HTTPException(422, "Carga horária/conclusão desta matrícula e edição ainda não elegível.")
        target = "approved" if payload.decision == "approve" else "rejected"
        _cas(session, record, payload.expected_revision, status=target, reviewed_at=datetime.now(timezone.utc), review_reason=payload.reason)
        _audit(session, record, "pending", claims["sub"], role, payload.reason, eligibility)
        session.commit()
        return _view(session, record)


@router.post("/{request_id}/resubmit")
def resubmit(request_id: str, payload: RevisionAction, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        record = _visible(session, request_id, claims["sub"])
        if record.user_id != claims["sub"]:
            raise HTTPException(403, "Somente o autor pode reapresentar o pedido.")
        if record.status != "rejected" or record.revision != payload.expected_revision:
            raise HTTPException(409, "Somente pedido rejeitado nesta revisão pode ser reapresentado.")
        _context(session, record.user_id, record.enrollment_id, record.course_version_id, record.class_id)
        eligibility = _request_eligibility(session, record)
        _cas(session, record, payload.expected_revision, status="pending", reviewed_at=None, review_reason=None)
        _audit(session, record, "rejected", claims["sub"], "learner", None, eligibility)
        session.commit()
        return _view(session, record)
