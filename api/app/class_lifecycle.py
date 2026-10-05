"""Territorial classroom lifecycle over canonical Tutor TDS entities."""

from __future__ import annotations

import hashlib
import hmac
import json
from datetime import date, datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .classroom_policy import DEFAULT_CLASS_CAPACITY, active_occupancy
from .context_memberships import bind_membership, membership_id
from .course_editor import ensure_legacy_course_version, latest_published_version
from .models import (
    CertificateRequest,
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    ClassroomCommandReceipt,
    ClassSession,
    CohortMembership,
    Course,
    CourseVersion,
    EvidenceItem,
    OfficialAttendanceDecision,
    OperatorCommandReceipt,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)

router = APIRouter(prefix="/operations/classes", tags=["operations", "classes"])


class PrepareClassCommand(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    id: str = Field(min_length=16, max_length=180)
    reason: str = Field(min_length=3, max_length=500)
    institution_id: str = Field(min_length=1, max_length=36)
    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)
    teacher_id: str = Field(min_length=1, max_length=36)
    monitor_ids: list[str] = Field(default_factory=list)
    name: str = Field(min_length=2, max_length=240)
    offer_municipality: str = Field(min_length=2, max_length=240)
    offer_location: str = Field(min_length=2, max_length=500)
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def validate_prepare(self) -> "PrepareClassCommand":
        if self.end_date < self.start_date:
            raise ValueError("end_date deve ser igual ou posterior a start_date")
        if len(set(self.monitor_ids)) != len(self.monitor_ids):
            raise ValueError("monitor_ids não pode conter duplicatas")
        return self


class ScopedClassCommand(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    id: str = Field(min_length=16, max_length=180)
    reason: str = Field(min_length=3, max_length=500)
    institution_id: str = Field(min_length=1, max_length=36)
    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)
    version_id: str = Field(min_length=1, max_length=36)
    expected_revision: int = Field(ge=0)


class PlanClassCommand(ScopedClassCommand):
    name: str = Field(min_length=2, max_length=240)
    offer_municipality: str = Field(min_length=2, max_length=240)
    offer_location: str = Field(min_length=2, max_length=500)
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def validate_dates(self) -> "PlanClassCommand":
        if self.end_date < self.start_date:
            raise ValueError("end_date deve ser igual ou posterior a start_date")
        return self


class TeamClassCommand(ScopedClassCommand):
    teacher_id: str = Field(min_length=1, max_length=36)
    monitor_ids: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_team(self) -> "TeamClassCommand":
        if len(set(self.monitor_ids)) != len(self.monitor_ids):
            raise ValueError("monitor_ids não pode conter duplicatas")
        return self


class TransitionClassCommand(ScopedClassCommand):
    target_status: Literal["active", "closed"]


def _enabled(request: Request) -> None:
    if not request.app.state.settings.class_lifecycle_enabled:
        raise HTTPException(status_code=404, detail="Ciclo de turma indisponível.")


def _digest(request: Request, payload: BaseModel) -> str:
    secret = request.app.state.settings.require_auth_secrets()[0]
    body = json.dumps(
        payload.model_dump(mode="json"),
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def _authorize_program(
    session: Session,
    program_id: str,
    actor_id: str,
    *,
    roles: set[str] | frozenset[str] = frozenset({"program_operator", "coordinator"}),
    write: bool = False,
) -> tuple[Program, ProgramMembership]:
    statement = select(Program).where(Program.id == program_id)
    program = session.scalar(statement.with_for_update() if write else statement)
    if program is None:
        raise HTTPException(status_code=404, detail="Programa não encontrado.")
    membership = session.get(ProgramMembership, (actor_id, program_id))
    if (
        membership is None
        or membership.status != "active"
        or membership.role not in roles
    ):
        raise HTTPException(
            status_code=403,
            detail="Ator não autorizado para este programa.",
        )
    return program, membership


def _class_context(
    session: Session,
    class_id: str,
    actor_id: str,
    *,
    write: bool,
    allow_teacher_read: bool = False,
) -> tuple[Classroom, Program, ProgramMembership]:
    statement = select(Classroom).where(Classroom.id == class_id)
    classroom = session.scalar(statement.with_for_update() if write else statement)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Turma não encontrada.")
    program = session.get(Program, classroom.program_id)
    if program is None:
        raise HTTPException(status_code=409, detail="Programa da turma inconsistente.")
    membership = session.get(ProgramMembership, (actor_id, classroom.program_id))
    allowed = (
        membership is not None
        and membership.status == "active"
        and membership.role in {"program_operator", "coordinator"}
    )
    teacher_read = (
        allow_teacher_read
        and classroom.teacher_id == actor_id
        and membership is not None
        and membership.status == "active"
        and membership.role == "teacher"
    )
    if not (allowed or teacher_read):
        raise HTTPException(
            status_code=403,
            detail="Ator não autorizado para esta turma.",
        )
    return classroom, program, membership


def _require_scope(
    classroom: Classroom,
    program: Program,
    payload: ScopedClassCommand,
) -> None:
    if (
        payload.institution_id != program.institution_id
        or payload.program_id != classroom.program_id
        or payload.course_id != classroom.course_id
        or payload.version_id != classroom.course_version_id
    ):
        raise HTTPException(
            status_code=403,
            detail="Comando fora do contexto territorial autorizado.",
        )


def _require_revision(classroom: Classroom, expected: int) -> None:
    if classroom.lifecycle_revision != expected:
        raise HTTPException(
            status_code=409,
            detail="A turma mudou; consulte o readiness antes de reenviar.",
        )


def _team_membership(
    session: Session,
    user_id: str,
    program_id: str,
    role: Literal["teacher", "monitor"],
) -> ProgramMembership:
    record = session.get(ProgramMembership, (user_id, program_id))
    if record is None or record.status != "active" or record.role != role:
        raise HTTPException(
            status_code=422,
            detail=f"{role} não possui vínculo ativo neste programa.",
        )
    return record


def _validate_team(
    session: Session,
    program_id: str,
    teacher_id: str,
    monitor_ids: list[str],
) -> None:
    _team_membership(session, teacher_id, program_id, "teacher")
    for monitor_id in monitor_ids:
        _team_membership(session, monitor_id, program_id, "monitor")


def _replace_team(
    session: Session,
    classroom: Classroom,
    teacher_id: str,
    monitor_ids: list[str],
) -> None:
    _validate_team(session, classroom.program_id, teacher_id, monitor_ids)

    old_teacher_id = classroom.teacher_id
    classroom.teacher_id = teacher_id
    bind_membership(session, classroom.id, teacher_id, "teacher")
    if old_teacher_id != teacher_id:
        previous = session.get(
            CohortMembership,
            membership_id(classroom.id, old_teacher_id, "teacher"),
        )
        if previous is not None:
            previous.status = "inactive"

    target_monitors = set(monitor_ids)
    current = {
        item.user_id: item
        for item in session.scalars(
            select(ClassMonitor).where(ClassMonitor.class_id == classroom.id)
        )
    }
    for user_id, record in current.items():
        if user_id in target_monitors:
            bind_membership(session, classroom.id, user_id, "monitor")
            continue
        cohort = session.get(
            CohortMembership,
            membership_id(classroom.id, user_id, "monitor"),
        )
        if cohort is not None:
            cohort.status = "inactive"
        session.delete(record)
    for user_id in target_monitors - set(current):
        session.add(
            ClassMonitor(
                class_id=classroom.id,
                user_id=user_id,
                program_id=classroom.program_id,
            )
        )
        bind_membership(session, classroom.id, user_id, "monitor")
    session.flush()


def _activation_blockers(session: Session, classroom: Classroom) -> list[str]:
    blockers: list[str] = []
    if not (classroom.offer_municipality or "").strip():
        blockers.append("offer_municipality_missing")
    if not (classroom.offer_location or "").strip():
        blockers.append("offer_location_missing")

    version = (
        session.get(CourseVersion, classroom.course_version_id)
        if classroom.course_version_id
        else None
    )
    if (
        version is None
        or version.course_id != classroom.course_id
        or version.status not in {"published", "archived"}
    ):
        blockers.append("course_version_invalid")

    teacher = session.get(
        ProgramMembership, (classroom.teacher_id, classroom.program_id)
    )
    if teacher is None or teacher.status != "active" or teacher.role != "teacher":
        blockers.append("teacher_membership_invalid")

    for monitor in session.scalars(
        select(ClassMonitor).where(ClassMonitor.class_id == classroom.id)
    ):
        membership = session.get(
            ProgramMembership, (monitor.user_id, classroom.program_id)
        )
        if (
            membership is None
            or membership.status != "active"
            or membership.role != "monitor"
        ):
            blockers.append("monitor_membership_invalid")
            break
    return blockers


def _closure_warnings(session: Session, classroom: Classroom) -> dict[str, int]:
    return {
        "open_sessions": int(
            session.scalar(
                select(func.count())
                .select_from(ClassSession)
                .where(
                    ClassSession.class_id == classroom.id,
                    ClassSession.status == "open",
                )
            )
            or 0
        ),
        "pending_evidence": int(
            session.scalar(
                select(func.count())
                .select_from(EvidenceItem)
                .where(
                    EvidenceItem.class_id == classroom.id,
                    EvidenceItem.review_status == "pending",
                )
            )
            or 0
        ),
        "pending_makeup": int(
            session.scalar(
                select(func.count())
                .select_from(OfficialAttendanceDecision)
                .where(
                    OfficialAttendanceDecision.class_id == classroom.id,
                    OfficialAttendanceDecision.status == "PENDING_MAKEUP",
                )
            )
            or 0
        ),
        "pending_certificate_requests": int(
            session.scalar(
                select(func.count())
                .select_from(CertificateRequest)
                .where(
                    CertificateRequest.class_id == classroom.id,
                    CertificateRequest.status == "pending",
                )
            )
            or 0
        ),
    }


def _capacity_snapshot(session: Session, classroom: Classroom) -> dict[str, object]:
    occupancy = active_occupancy(session, classroom.id)
    override = session.scalar(
        select(OperatorCommandReceipt)
        .where(
            OperatorCommandReceipt.class_id == classroom.id,
            OperatorCommandReceipt.action == "assign_capacity_override",
        )
        .order_by(OperatorCommandReceipt.occurred_at.desc())
        .limit(1)
    )
    exception = None
    if occupancy > DEFAULT_CLASS_CAPACITY and override is not None:
        exception = {
            "state": "authorized",
            "actor_id": override.actor_id,
            "reason": override.reason,
            "occurred_at": override.occurred_at.isoformat(),
        }
    elif occupancy > DEFAULT_CLASS_CAPACITY:
        exception = {"state": "audit_missing"}
    return {
        "limit": DEFAULT_CLASS_CAPACITY,
        "occupancy": occupancy,
        "remaining": max(0, DEFAULT_CLASS_CAPACITY - occupancy),
        "over_capacity": occupancy > DEFAULT_CLASS_CAPACITY,
        "exception": exception,
    }


def _history(session: Session, classroom: Classroom) -> list[dict[str, object]]:
    records = session.scalars(
        select(ClassroomCommandReceipt)
        .where(ClassroomCommandReceipt.class_id == classroom.id)
        .order_by(ClassroomCommandReceipt.revision)
        .limit(100)
    ).all()
    return [
        {
            "id": record.id,
            "revision": record.revision,
            "action": record.action,
            "actor_id": record.actor_id,
            "reason": record.reason,
            "occurred_at": record.occurred_at.isoformat(),
        }
        for record in records
    ]


def _snapshot(
    session: Session,
    classroom: Classroom,
    program: Program,
    actor_membership: ProgramMembership,
) -> dict[str, object]:
    monitors = list(
        session.scalars(
            select(ClassMonitor.user_id)
            .where(ClassMonitor.class_id == classroom.id)
            .order_by(ClassMonitor.user_id)
        )
    )
    blockers = _activation_blockers(session, classroom)
    warnings = _closure_warnings(session, classroom)
    role = actor_membership.role
    coordinator = role == "coordinator"
    operator = role == "program_operator"
    return {
        "classroom": {
            "id": classroom.id,
            "institution_id": program.institution_id,
            "program_id": classroom.program_id,
            "course_id": classroom.course_id,
            "course_version_id": classroom.course_version_id,
            "teacher_id": classroom.teacher_id,
            "monitor_ids": monitors,
            "name": classroom.name,
            "offer_municipality": classroom.offer_municipality,
            "offer_location": classroom.offer_location,
            "start_date": classroom.start_date.isoformat(),
            "end_date": classroom.end_date.isoformat(),
            "status": classroom.status,
            "revision": classroom.lifecycle_revision,
        },
        "capacity": _capacity_snapshot(session, classroom),
        "readiness": {
            "activation_blockers": blockers,
            "can_activate": classroom.status == "planned" and not blockers,
            "can_close": classroom.status == "active",
            "closure_warnings": warnings,
            "closure_warnings_block_close": False,
            "close_open_session_policy": "HUMAN_GATE_CLOSE_WITH_OPEN_SESSION",
        },
        "capabilities": {
            "role": role,
            "can_prepare": (operator or coordinator)
            and classroom.status == "planned",
            "can_change_team": coordinator
            and classroom.status != "closed"
            or operator
            and classroom.status == "planned",
            "can_activate": coordinator
            and classroom.status == "planned"
            and not blockers,
            "can_close": coordinator and classroom.status == "active",
            "can_override_capacity": coordinator,
        },
        "history": _history(session, classroom),
    }


def _previous(
    session: Session,
    *,
    command_id: str,
    actor_id: str,
    class_id: str | None,
    request_hash: str,
) -> ClassroomCommandReceipt | None:
    record = session.get(ClassroomCommandReceipt, command_id)
    if record is None:
        return None
    if (
        record.actor_id != actor_id
        or (class_id is not None and record.class_id != class_id)
        or record.request_hash != request_hash
    ):
        raise HTTPException(status_code=409, detail="Replay de lifecycle divergente.")
    return record


def _store(
    session: Session,
    classroom: Classroom,
    *,
    command_id: str,
    actor_id: str,
    action: str,
    reason: str,
    request_hash: str,
    result: dict[str, object],
) -> ClassroomCommandReceipt:
    record = ClassroomCommandReceipt(
        id=command_id,
        actor_id=actor_id,
        program_id=classroom.program_id,
        class_id=classroom.id,
        revision=classroom.lifecycle_revision,
        action=action,
        reason=reason,
        request_hash=request_hash,
        result=result,
        occurred_at=datetime.now(timezone.utc),
    )
    session.add(record)
    return record


@router.get("/options")
def options(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, list[dict[str, object]]]:
    _enabled(request)
    with Session(request.app.state.database.engine) as session:
        rows = session.execute(
            select(ProgramMembership, Program, ProgramCourse, Course)
            .join(Program, Program.id == ProgramMembership.program_id)
            .join(ProgramCourse, ProgramCourse.program_id == Program.id)
            .join(Course, Course.id == ProgramCourse.course_id)
            .where(
                ProgramMembership.user_id == claims["sub"],
                ProgramMembership.status == "active",
                ProgramMembership.role.in_(["program_operator", "coordinator"]),
                Course.active.is_(True),
            )
            .order_by(Program.name, Course.title)
            .limit(250)
        ).all()
        items: list[dict[str, object]] = []
        for membership, program, offering, course in rows:
            version = latest_published_version(session, course.id)
            items.append(
                {
                    "institution_id": program.institution_id,
                    "program_id": program.id,
                    "program_name": program.name,
                    "course_id": offering.course_id,
                    "course_title": course.title,
                    "course_version_id": version.id if version else None,
                    "version_number": version.version_number if version else None,
                    "role": membership.role,
                    "can_prepare": True,
                    "can_activate": membership.role == "coordinator",
                    "can_close": membership.role == "coordinator",
                    "can_override_capacity": membership.role == "coordinator",
                }
            )
        return {"options": items}


@router.get("/team-candidates")
def team_candidates(
    program_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    """Return only display-safe active teacher/monitor candidates."""
    _enabled(request)
    with Session(request.app.state.database.engine) as session:
        _authorize_program(session, program_id, claims["sub"])
        rows = session.execute(
            select(User.id, User.name, ProgramMembership.role)
            .join(
                ProgramMembership,
                ProgramMembership.user_id == User.id,
            )
            .where(
                ProgramMembership.program_id == program_id,
                ProgramMembership.status == "active",
                ProgramMembership.role.in_(["teacher", "monitor"]),
            )
            .order_by(ProgramMembership.role, User.name, User.id)
            .limit(250)
        ).all()
        return {
            "program_id": program_id,
            "candidates": [
                {
                    "user_id": row.id,
                    "display_name": row.name,
                    "role": row.role,
                }
                for row in rows
            ],
        }


@router.get("")
def manageable_classes(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, list[dict[str, object]]]:
    """List only classrooms visible through the lifecycle RBAC boundary."""
    _enabled(request)
    actor_id = claims["sub"]
    with Session(request.app.state.database.engine) as session:
        rows = session.execute(
            select(Classroom, Program, ProgramMembership)
            .join(Program, Program.id == Classroom.program_id)
            .join(
                ProgramMembership,
                and_(
                    ProgramMembership.program_id == Classroom.program_id,
                    ProgramMembership.user_id == actor_id,
                ),
            )
            .where(
                ProgramMembership.status == "active",
                or_(
                    ProgramMembership.role.in_(["program_operator", "coordinator"]),
                    and_(
                        ProgramMembership.role == "teacher",
                        Classroom.teacher_id == actor_id,
                    ),
                ),
            )
            .order_by(Classroom.start_date.desc(), Classroom.name, Classroom.id)
            .limit(250)
        ).all()
        items: list[dict[str, object]] = []
        for classroom, program, membership in rows:
            item = _snapshot(session, classroom, program, membership)
            item.pop("history", None)
            items.append(item)
        return {"classes": items}


@router.post("", status_code=201)
def prepare_class(
    payload: PrepareClassCommand,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    _enabled(request)
    request_hash = _digest(request, payload)
    with Session(request.app.state.database.engine) as session:
        replay = session.get(ClassroomCommandReceipt, payload.id)
        if replay is not None:
            _authorize_program(session, replay.program_id, claims["sub"])
            replay = _previous(
                session,
                command_id=payload.id,
                actor_id=claims["sub"],
                class_id=None,
                request_hash=request_hash,
            )
            if replay.program_id != payload.program_id:
                raise HTTPException(status_code=409, detail="Replay de programa divergente.")
            return replay.result

        program, actor_membership = _authorize_program(
            session, payload.program_id, claims["sub"], write=True
        )
        # A second identical prepare may have waited on the program lock while
        # the first transaction committed its receipt. Re-read after locking.
        replay = _previous(
            session,
            command_id=payload.id,
            actor_id=claims["sub"],
            class_id=None,
            request_hash=request_hash,
        )
        if replay is not None:
            if replay.program_id != payload.program_id:
                raise HTTPException(status_code=409, detail="Replay de programa divergente.")
            return replay.result
        if program.institution_id != payload.institution_id:
            raise HTTPException(
                status_code=403,
                detail="Programa não pertence à instituição informada.",
            )
        if session.get(ProgramCourse, (payload.program_id, payload.course_id)) is None:
            raise HTTPException(
                status_code=422,
                detail="Curso não é ofertado por este programa.",
            )
        course = session.get(Course, payload.course_id)
        if course is None or not course.active:
            raise HTTPException(
                status_code=422,
                detail="Curso não está publicado para novas turmas.",
            )
        version = latest_published_version(session, course.id)
        if version is None:
            version = ensure_legacy_course_version(session, course)
        if version.status != "published":
            raise HTTPException(
                status_code=409,
                detail="Curso não possui versão publicada.",
            )
        _validate_team(
            session,
            payload.program_id,
            payload.teacher_id,
            payload.monitor_ids,
        )
        classroom = Classroom(
            id=str(uuid4()),
            program_id=payload.program_id,
            course_id=payload.course_id,
            course_version_id=version.id,
            teacher_id=payload.teacher_id,
            name=payload.name,
            offer_municipality=payload.offer_municipality,
            offer_location=payload.offer_location,
            start_date=payload.start_date,
            end_date=payload.end_date,
            status="planned",
            lifecycle_revision=1,
        )
        session.add(classroom)
        session.flush()
        _replace_team(
            session,
            classroom,
            payload.teacher_id,
            payload.monitor_ids,
        )
        result = _snapshot(session, classroom, program, actor_membership)
        receipt = _store(
            session,
            classroom,
            command_id=payload.id,
            actor_id=claims["sub"],
            action="prepare",
            reason=payload.reason,
            request_hash=request_hash,
            result={},
        )
        session.flush()
        result = _snapshot(session, classroom, program, actor_membership)
        receipt.result = result
        try:
            session.commit()
        except IntegrityError as error:
            session.rollback()
            raise HTTPException(
                status_code=409,
                detail="Conflito ao preparar a turma; consulte novamente.",
            ) from error
        return result


def _mutating_context(
    session: Session,
    class_id: str,
    payload: ScopedClassCommand,
    actor_id: str,
    request_hash: str,
) -> tuple[Classroom, Program, ProgramMembership, ClassroomCommandReceipt | None]:
    classroom, program, membership = _class_context(
        session,
        class_id,
        actor_id,
        write=True,
    )
    _require_scope(classroom, program, payload)
    replay = _previous(
        session,
        command_id=payload.id,
        actor_id=actor_id,
        class_id=class_id,
        request_hash=request_hash,
    )
    if replay is None:
        _require_revision(classroom, payload.expected_revision)
    return classroom, program, membership, replay


@router.post("/{class_id}/plan")
def update_plan(
    class_id: str,
    payload: PlanClassCommand,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    _enabled(request)
    request_hash = _digest(request, payload)
    with Session(request.app.state.database.engine) as session:
        classroom, program, membership, replay = _mutating_context(
            session, class_id, payload, claims["sub"], request_hash
        )
        if replay is not None:
            return replay.result
        if classroom.status != "planned":
            raise HTTPException(
                status_code=409,
                detail="Planejamento territorial só pode ser alterado em planned.",
            )
        classroom.name = payload.name
        classroom.offer_municipality = payload.offer_municipality
        classroom.offer_location = payload.offer_location
        classroom.start_date = payload.start_date
        classroom.end_date = payload.end_date
        classroom.lifecycle_revision += 1
        receipt = _store(
            session,
            classroom,
            command_id=payload.id,
            actor_id=claims["sub"],
            action="plan",
            reason=payload.reason,
            request_hash=request_hash,
            result={},
        )
        session.flush()
        result = _snapshot(session, classroom, program, membership)
        receipt.result = result
        session.commit()
        return result


@router.post("/{class_id}/team")
def update_team(
    class_id: str,
    payload: TeamClassCommand,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    _enabled(request)
    request_hash = _digest(request, payload)
    with Session(request.app.state.database.engine) as session:
        classroom, program, membership, replay = _mutating_context(
            session, class_id, payload, claims["sub"], request_hash
        )
        if replay is not None:
            return replay.result
        if classroom.status == "closed":
            raise HTTPException(status_code=409, detail="Turma encerrada é imutável.")
        if membership.role == "program_operator" and classroom.status != "planned":
            raise HTTPException(
                status_code=403,
                detail="Após ativação, somente a coordenação pode alterar a equipe.",
            )
        _replace_team(
            session,
            classroom,
            payload.teacher_id,
            payload.monitor_ids,
        )
        classroom.lifecycle_revision += 1
        receipt = _store(
            session,
            classroom,
            command_id=payload.id,
            actor_id=claims["sub"],
            action="team",
            reason=payload.reason,
            request_hash=request_hash,
            result={},
        )
        session.flush()
        result = _snapshot(session, classroom, program, membership)
        receipt.result = result
        session.commit()
        return result


@router.post("/{class_id}/transition")
def transition_class(
    class_id: str,
    payload: TransitionClassCommand,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    _enabled(request)
    request_hash = _digest(request, payload)
    with Session(request.app.state.database.engine) as session:
        classroom, program, membership, replay = _mutating_context(
            session, class_id, payload, claims["sub"], request_hash
        )
        if replay is not None:
            return replay.result
        if membership.role != "coordinator":
            raise HTTPException(
                status_code=403,
                detail="Somente a coordenação pode ativar ou encerrar turmas.",
            )
        if payload.target_status == "active":
            if classroom.status != "planned":
                raise HTTPException(
                    status_code=409,
                    detail="Ativação exige estado planned.",
                )
            blockers = _activation_blockers(session, classroom)
            if blockers:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "message": "Turma ainda não está pronta para ativação.",
                        "blockers": blockers,
                    },
                )
        else:
            if classroom.status != "active":
                raise HTTPException(
                    status_code=409,
                    detail="Encerramento exige estado active.",
                )

        classroom.status = payload.target_status
        classroom.lifecycle_revision += 1
        receipt = _store(
            session,
            classroom,
            command_id=payload.id,
            actor_id=claims["sub"],
            action=f"transition_{payload.target_status}",
            reason=payload.reason,
            request_hash=request_hash,
            result={},
        )
        session.flush()
        result = _snapshot(session, classroom, program, membership)
        receipt.result = result
        session.commit()
        return result


@router.get("/{class_id}/readiness")
def readiness(
    class_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> dict[str, object]:
    _enabled(request)
    with Session(request.app.state.database.engine) as session:
        classroom, program, membership = _class_context(
            session,
            class_id,
            claims["sub"],
            write=False,
            allow_teacher_read=True,
        )
        return _snapshot(session, classroom, program, membership)
