"""Class-scoped human baseline references and mentorship, never source answers.

Source references remain reserved to their explicitly reviewed person, including
superseded references. Owner erasure deletes all private snapshots and history.
Actor/mentor foreign keys can be anonymized without rewriting narrative history.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .evidence import _active_student, _class, _is_staff, _staff
from .models import BaselineRevision, BaselineSourceRecord, ClassEnrollment, ClassMonitor, Classroom, Enrollment, MentorshipCase, MentorshipRevision, ProgramMembership, StudentBaseline, User

router = APIRouter(tags=["student-followup"])
CASE_FIELDS = {"mentor_id", "objective", "next_action", "status"}


class HumanAction(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    reason: str = Field(min_length=3, max_length=500)
    idempotency_key: str = Field(min_length=8, max_length=180, pattern=r"^[A-Za-z0-9_.:-]+$")


class BaselinePut(HumanAction):
    expected_revision: int = Field(ge=0)
    source: str = Field(min_length=1, max_length=120, pattern=r"^[A-Za-z0-9_.:-]+$")
    record_id: str = Field(min_length=1, max_length=240)
    baseline_date: date
    territory_id: str | None = Field(default=None, min_length=1, max_length=120)

    @field_validator("record_id", "territory_id")
    @classmethod
    def opaque_reference(cls, value):
        if value is not None and any(ord(char) < 32 or ord(char) == 127 for char in value):
            raise ValueError("referência não aceita caracteres de controle")
        return value


class CaseCreate(HumanAction):
    user_id: str = Field(min_length=1, max_length=36)
    mentor_id: str = Field(min_length=1, max_length=36)
    objective: str = Field(min_length=3, max_length=1000)
    next_action: str = Field(min_length=3, max_length=1000)


class CasePatch(HumanAction):
    expected_revision: int = Field(ge=1)
    mentor_id: str | None = Field(default=None, min_length=1, max_length=36)
    objective: str | None = Field(default=None, min_length=3, max_length=1000)
    next_action: str | None = Field(default=None, min_length=3, max_length=1000)
    status: Literal["open", "in_progress", "closed"] | None = None

    @model_validator(mode="after")
    def has_change(self):
        fields = self.model_fields_set & CASE_FIELDS
        if not fields or any(getattr(self, name) is None for name in fields):
            raise ValueError("informe ao menos um campo mutável não nulo")
        return self


def _utc(value):
    return (value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)).isoformat()


def _scope(session, class_id, claims, *, lock=False):
    classroom = _class(session, class_id)
    _staff(session, classroom, claims, monitor=True)
    if lock:
        session.execute(update(Classroom).where(Classroom.id == class_id).values(status=Classroom.status), execution_options={"synchronize_session": False})
    return classroom


def _student(session, classroom, user_id):
    if not _active_student(session, classroom, user_id):
        raise HTTPException(403, "Vínculo ativo e consistente do estudante obrigatório.")
    return session.get(ClassEnrollment, (classroom.id, user_id))


def _mentor(session, classroom, mentor_id, student_id):
    user = session.get(User, mentor_id) if mentor_id else None
    # Global admin is not by itself a mentor assignment: a mentor must belong
    # to this classroom's active staff under the existing membership rules.
    if user is None or mentor_id == student_id or not _is_staff(session, classroom, mentor_id, "student"):
        raise HTTPException(422, "Mentor deve ser outra pessoa da equipe ativa vinculada à turma.")
    return user


def _role(session, classroom, claims):
    if claims["role"] == "admin":
        return "admin"
    return session.get(ProgramMembership, (claims["sub"], classroom.program_id)).role


def _lineage(record, link):
    if record.enrollment_id != link.enrollment_id:
        raise HTTPException(409, "Matrícula alterada; associação histórica preservada.")


def _baseline_snapshot(session, record):
    source = session.get(BaselineSourceRecord, record.source_record_id)
    return {"id": record.id, "class_id": record.class_id, "user_id": record.user_id, "enrollment_id": record.enrollment_id, "source": source.source, "record_id": source.record_id, "baseline_date": record.baseline_date.isoformat(), "territory_id": record.territory_id, "revision": record.revision, "reviewed_at": _utc(record.reviewed_at)}


def _baseline_view(session, record):
    audit = session.scalar(select(BaselineRevision).where(BaselineRevision.baseline_id == record.id, BaselineRevision.revision == record.revision))
    return _baseline_snapshot(session, record) | {"reviewed_by": audit.actor_user_id if audit else None}


def _case_snapshot(record):
    return {"id": record.id, "class_id": record.class_id, "user_id": record.user_id, "enrollment_id": record.enrollment_id, "objective": record.objective, "next_action": record.next_action, "status": record.status, "revision": record.revision, "opened_at": _utc(record.opened_at), "updated_at": _utc(record.updated_at), "closed_at": _utc(record.closed_at) if record.closed_at else None}


def _case_view(session, record=None, *, audit=None):
    mentor_id = audit.mentor_id if audit is not None else record.mentor_id
    mentor = session.get(User, mentor_id) if mentor_id else None
    snapshot = audit.snapshot if audit is not None else _case_snapshot(record)
    return snapshot | {"mentor_id": mentor_id, "mentor_name": mentor.name if mentor else None}


def _history(session, model, filter_):
    return [{"revision": row.revision, "actor_user_id": row.actor_user_id, "actor_role": row.actor_role, "reason": row.reason, "occurred_at": _utc(row.occurred_at), "snapshot": (_case_view(session, audit=row) if model is MentorshipRevision else row.snapshot)} for row in session.scalars(select(model).where(filter_).order_by(model.revision))]


def _commit(session):
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(409, "Alteração concorrente ou referência conflitante; recarregue.") from error


@router.get("/classes/{class_id}/students/{user_id}/mentors")
def list_mentors(class_id: str, user_id: str, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims)
        _student(session, classroom, user_id)
        identities = set(session.scalars(select(ClassMonitor.user_id).where(ClassMonitor.class_id == class_id)))
        identities.add(classroom.teacher_id)
        candidates = session.scalars(select(User).where(User.id.in_(identities), User.id != user_id).order_by(User.name, User.id))
        return {"mentors": [{"user_id": user.id, "name": user.name} for user in candidates if _is_staff(session, classroom, user.id, "student")]}


@router.get("/classes/{class_id}/students/{user_id}/baseline")
def get_baseline(class_id: str, user_id: str, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims)
        link = _student(session, classroom, user_id)
        record = session.scalar(select(StudentBaseline).where(StudentBaseline.class_id == class_id, StudentBaseline.user_id == user_id))
        if record is None:
            return {"baseline": None, "history": []}
        _lineage(record, link)
        return {"baseline": _baseline_view(session, record), "history": _history(session, BaselineRevision, BaselineRevision.baseline_id == record.id)}


@router.put("/classes/{class_id}/students/{user_id}/baseline")
def put_baseline(class_id: str, user_id: str, payload: BaselinePut, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims, lock=True)
        link = _student(session, classroom, user_id)
        record = session.scalar(select(StudentBaseline).where(StudentBaseline.class_id == class_id, StudentBaseline.user_id == user_id))
        if record is not None:
            _lineage(record, link)
        previous = session.scalar(select(BaselineRevision).where(BaselineRevision.idempotency_key == payload.idempotency_key))
        fields = {"source": payload.source, "record_id": payload.record_id, "baseline_date": payload.baseline_date.isoformat(), "territory_id": payload.territory_id}
        if previous is not None:
            if record is None or previous.baseline_id != record.id or previous.actor_user_id != claims["sub"] or previous.revision != payload.expected_revision + 1 or previous.reason != payload.reason or any(previous.snapshot[name] != value for name, value in fields.items()):
                raise HTTPException(409, "Idempotência divergente.")
            return previous.snapshot | {"reviewed_by": previous.actor_user_id}
        if (record.revision if record else 0) != payload.expected_revision:
            raise HTTPException(409, "Vínculo alterado; recarregue a revisão.")
        source = session.scalar(select(BaselineSourceRecord).where(BaselineSourceRecord.source == payload.source, BaselineSourceRecord.record_id == payload.record_id))
        if source is not None and source.user_id != user_id:
            raise HTTPException(409, "Referência já vinculada; revisão humana necessária.")
        now = datetime.now(timezone.utc)
        try:
            if source is None:
                source = BaselineSourceRecord(id=str(uuid4()), source=payload.source, record_id=payload.record_id, user_id=user_id)
                session.add(source)
                session.flush()
            if record is None:
                record = StudentBaseline(id=str(uuid4()), class_id=class_id, user_id=user_id, enrollment_id=link.enrollment_id, program_id=classroom.program_id, course_id=classroom.course_id, source_record_id=source.id, baseline_date=payload.baseline_date, territory_id=payload.territory_id, revision=1, reviewed_at=now)
                session.add(record)
                session.flush()
            else:
                result = session.execute(update(StudentBaseline).where(StudentBaseline.id == record.id, StudentBaseline.revision == payload.expected_revision).values(source_record_id=source.id, baseline_date=payload.baseline_date, territory_id=payload.territory_id, revision=payload.expected_revision + 1, reviewed_at=now), execution_options={"synchronize_session": False})
                if result.rowcount != 1:
                    raise HTTPException(409, "Vínculo alterado; recarregue.")
                session.refresh(record)
            session.add(BaselineRevision(id=str(uuid4()), baseline_id=record.id, revision=record.revision, actor_user_id=claims["sub"], actor_role=_role(session, classroom, claims), reason=payload.reason, occurred_at=now, idempotency_key=payload.idempotency_key, snapshot=_baseline_snapshot(session, record)))
            _commit(session)
        except IntegrityError as error:
            session.rollback()
            raise HTTPException(409, "Referência conflitante; recarregue.") from error
        return _baseline_view(session, record)


@router.get("/classes/{class_id}/mentorship-cases")
def list_cases(class_id: str, request: Request, user_id: str | None = Query(None, min_length=1, max_length=36), limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims)
        if user_id is not None:
            _student(session, classroom, user_id)
        query = select(MentorshipCase).join(ClassEnrollment, (ClassEnrollment.class_id == MentorshipCase.class_id) & (ClassEnrollment.user_id == MentorshipCase.user_id) & (ClassEnrollment.enrollment_id == MentorshipCase.enrollment_id)).join(Enrollment, Enrollment.id == MentorshipCase.enrollment_id).join(ProgramMembership, (ProgramMembership.user_id == MentorshipCase.user_id) & (ProgramMembership.program_id == MentorshipCase.program_id)).where(
            MentorshipCase.class_id == class_id,
            MentorshipCase.program_id == ClassEnrollment.program_id,
            MentorshipCase.course_id == ClassEnrollment.course_id,
            ClassEnrollment.program_id == classroom.program_id,
            ClassEnrollment.course_id == classroom.course_id,
            Enrollment.user_id == MentorshipCase.user_id,
            Enrollment.program_id == MentorshipCase.program_id,
            Enrollment.course_id == MentorshipCase.course_id,
            Enrollment.program_id == classroom.program_id,
            Enrollment.course_id == classroom.course_id,
            ClassEnrollment.status == "active", Enrollment.status == "active", ProgramMembership.status == "active",
        )
        if user_id is not None:
            query = query.where(MentorshipCase.user_id == user_id)
        total = session.scalar(select(func.count()).select_from(query.subquery())) or 0
        records = session.scalars(query.order_by(MentorshipCase.updated_at.desc(), MentorshipCase.id).offset(offset).limit(limit))
        return {"items": [_case_view(session, record) for record in records], "total": total, "limit": limit, "offset": offset}


def _case(session, classroom, case_id):
    record = session.get(MentorshipCase, case_id)
    if record is None or record.class_id != classroom.id:
        raise HTTPException(404, "Caso não encontrado.")
    _lineage(record, _student(session, classroom, record.user_id))
    return record


@router.get("/classes/{class_id}/mentorship-cases/{case_id}")
def get_case(class_id: str, case_id: str, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        record = _case(session, _scope(session, class_id, claims), case_id)
        return _case_view(session, record) | {"history": _history(session, MentorshipRevision, MentorshipRevision.case_id == record.id)}


@router.post("/classes/{class_id}/mentorship-cases", status_code=201)
def create_case(class_id: str, payload: CaseCreate, request: Request, response: Response, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims, lock=True)
        link = _student(session, classroom, payload.user_id)
        _mentor(session, classroom, payload.mentor_id, payload.user_id)
        previous = session.scalar(select(MentorshipRevision).where(MentorshipRevision.idempotency_key == payload.idempotency_key))
        if previous is not None:
            if previous.actor_user_id != claims["sub"] or previous.changed_fields != ["create"] or previous.reason != payload.reason or previous.mentor_id != payload.mentor_id or any(previous.snapshot[name] != value for name, value in {"class_id": class_id, "user_id": payload.user_id, "enrollment_id": link.enrollment_id, "objective": payload.objective, "next_action": payload.next_action}.items()):
                raise HTTPException(409, "Idempotência divergente.")
            response.status_code = 200
            return _case_view(session, audit=previous)
        now = datetime.now(timezone.utc)
        record = MentorshipCase(id=str(uuid4()), class_id=class_id, user_id=payload.user_id, enrollment_id=link.enrollment_id, program_id=classroom.program_id, course_id=classroom.course_id, mentor_id=payload.mentor_id, objective=payload.objective, next_action=payload.next_action, status="open", revision=1, opened_at=now, updated_at=now)
        session.add(record)
        try:
            session.flush()
            session.add(MentorshipRevision(id=str(uuid4()), case_id=record.id, revision=1, actor_user_id=claims["sub"], mentor_id=record.mentor_id, actor_role=_role(session, classroom, claims), reason=payload.reason, occurred_at=now, idempotency_key=payload.idempotency_key, changed_fields=["create"], snapshot=_case_snapshot(record)))
            _commit(session)
        except IntegrityError as error:
            session.rollback()
            raise HTTPException(409, "Caso concorrente; recarregue.") from error
        return _case_view(session, record)


@router.patch("/classes/{class_id}/mentorship-cases/{case_id}")
def patch_case(class_id: str, case_id: str, payload: CasePatch, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims, lock=True)
        record = _case(session, classroom, case_id)
        changes = payload.model_dump(include=CASE_FIELDS, exclude_unset=True)
        previous = session.scalar(select(MentorshipRevision).where(MentorshipRevision.idempotency_key == payload.idempotency_key))
        if previous is not None:
            original = previous.snapshot | {"mentor_id": previous.mentor_id}
            if previous.case_id != case_id or previous.actor_user_id != claims["sub"] or previous.revision != payload.expected_revision + 1 or previous.reason != payload.reason or previous.changed_fields != sorted(changes) or any(original[name] != value for name, value in changes.items()):
                raise HTTPException(409, "Idempotência divergente.")
            _mentor(session, classroom, previous.mentor_id, record.user_id)
            return _case_view(session, audit=previous)
        _mentor(session, classroom, changes.get("mentor_id", record.mentor_id), record.user_id)
        if record.revision != payload.expected_revision:
            raise HTTPException(409, "Caso alterado; recarregue a revisão.")
        now = datetime.now(timezone.utc)
        next_status = changes.get("status", record.status)
        result = session.execute(update(MentorshipCase).where(MentorshipCase.id == record.id, MentorshipCase.revision == payload.expected_revision).values(**changes, revision=payload.expected_revision + 1, updated_at=now, closed_at=(record.closed_at or now) if next_status == "closed" else None), execution_options={"synchronize_session": False})
        if result.rowcount != 1:
            raise HTTPException(409, "Caso alterado; recarregue.")
        session.refresh(record)
        session.add(MentorshipRevision(id=str(uuid4()), case_id=record.id, revision=record.revision, actor_user_id=claims["sub"], mentor_id=record.mentor_id, actor_role=_role(session, classroom, claims), reason=payload.reason, occurred_at=now, idempotency_key=payload.idempotency_key, changed_fields=sorted(changes), snapshot=_case_snapshot(record)))
        _commit(session)
        return _case_view(session, record)
