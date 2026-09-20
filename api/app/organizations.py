from __future__ import annotations

from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import require_roles
from .database import Database
from .models import (
    Course,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    LearningEventRecord,
    User,
)

router = APIRouter(prefix="/admin", tags=["admin"])
admin_claims = require_roles("admin")
ProgramRole = Literal["student", "teacher", "monitor", "admin"]


class InstitutionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=2, max_length=240)


class InstitutionResponse(InstitutionCreate):
    id: str


class ProgramCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    institution_id: str = Field(min_length=1, max_length=36)
    name: str = Field(min_length=2, max_length=240)


class ProgramResponse(ProgramCreate):
    id: str


class MembershipCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: str = Field(min_length=1, max_length=36)
    role: ProgramRole


class MembershipResponse(MembershipCreate):
    program_id: str
    status: str


class EnrollmentCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: str = Field(min_length=1, max_length=36)
    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)


class EnrollmentResponse(EnrollmentCreate):
    id: str
    status: str


class WorkloadUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    planned_hours: float = Field(gt=0, le=10_000)


class ProgramHierarchy(ProgramResponse):
    course_ids: list[str]
    memberships: list[MembershipResponse]


class InstitutionHierarchy(InstitutionResponse):
    programs: list[ProgramHierarchy]


@router.post("/institutions", response_model=InstitutionResponse, status_code=201)
def create_institution(
    payload: InstitutionCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> InstitutionResponse:
    name = payload.name.strip()
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        existing = session.scalar(select(Institution).where(Institution.name == name))
        if existing is not None:
            raise HTTPException(status_code=409, detail="Instituição já cadastrada.")
        record = Institution(id=str(uuid4()), name=name)
        session.add(record)
        _commit(session, "Não foi possível criar a instituição.")
        return InstitutionResponse(id=record.id, name=record.name)


@router.post("/programs", response_model=ProgramResponse, status_code=201)
def create_program(
    payload: ProgramCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> ProgramResponse:
    name = payload.name.strip()
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        if session.get(Institution, payload.institution_id) is None:
            raise HTTPException(status_code=404, detail="Instituição não encontrada.")
        existing = session.scalar(
            select(Program).where(
                Program.institution_id == payload.institution_id,
                Program.name == name,
            )
        )
        if existing is not None:
            raise HTTPException(status_code=409, detail="Programa já cadastrado.")
        record = Program(
            id=str(uuid4()),
            institution_id=payload.institution_id,
            name=name,
        )
        session.add(record)
        _commit(session, "Não foi possível criar o programa.")
        return ProgramResponse(
            id=record.id,
            institution_id=record.institution_id,
            name=record.name,
        )


@router.post("/programs/{program_id}/courses/{course_id}", status_code=201)
def offer_course(
    program_id: str,
    course_id: str,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> dict[str, str]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        _require(session, Program, program_id, "Programa não encontrado.")
        _require(session, Course, course_id, "Curso não encontrado.")
        if session.get(ProgramCourse, (program_id, course_id)) is not None:
            raise HTTPException(status_code=409, detail="Curso já ofertado no programa.")
        session.add(ProgramCourse(program_id=program_id, course_id=course_id))
        _commit(session, "Não foi possível vincular o curso.")
        return {"program_id": program_id, "course_id": course_id}


@router.put("/programs/{program_id}/courses/{course_id}/workload")
def update_workload(
    program_id: str,
    course_id: str,
    payload: WorkloadUpdate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> dict[str, float | str]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        link = session.get(ProgramCourse, (program_id, course_id))
        if link is None:
            raise HTTPException(status_code=404, detail="Oferta de curso não encontrada.")
        link.planned_seconds = round(payload.planned_hours * 60 * 60)
        session.commit()
        return {
            "program_id": program_id,
            "course_id": course_id,
            "planned_hours": link.planned_seconds / 3600,
        }


@router.post(
    "/programs/{program_id}/memberships",
    response_model=MembershipResponse,
    status_code=201,
)
def create_membership(
    program_id: str,
    payload: MembershipCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> MembershipResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        _require(session, Program, program_id, "Programa não encontrado.")
        _require(session, User, payload.user_id, "Usuário não encontrado.")
        if session.get(ProgramMembership, (payload.user_id, program_id)) is not None:
            raise HTTPException(status_code=409, detail="Participação já cadastrada.")
        record = ProgramMembership(
            user_id=payload.user_id,
            program_id=program_id,
            role=payload.role,
            status="active",
        )
        session.add(record)
        _commit(session, "Não foi possível vincular o usuário.")
        return MembershipResponse(
            user_id=record.user_id,
            program_id=record.program_id,
            role=record.role,
            status=record.status,
        )


@router.post("/enrollments", response_model=EnrollmentResponse, status_code=201)
def create_enrollment(
    payload: EnrollmentCreate,
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> EnrollmentResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        membership = session.get(
            ProgramMembership, (payload.user_id, payload.program_id)
        )
        if membership is None or membership.status != "active":
            raise HTTPException(
                status_code=422,
                detail="Usuário não participa ativamente do programa.",
            )
        if session.get(ProgramCourse, (payload.program_id, payload.course_id)) is None:
            raise HTTPException(
                status_code=422,
                detail="Curso não é ofertado por este programa.",
            )
        existing = session.scalar(
            select(Enrollment).where(
                Enrollment.user_id == payload.user_id,
                Enrollment.program_id == payload.program_id,
                Enrollment.course_id == payload.course_id,
            )
        )
        if existing is not None:
            raise HTTPException(status_code=409, detail="Matrícula já cadastrada.")
        record = Enrollment(
            id=str(uuid4()),
            user_id=payload.user_id,
            program_id=payload.program_id,
            course_id=payload.course_id,
            status="active",
        )
        session.add(record)
        session.flush()
        session.execute(
            update(LearningEventRecord)
            .where(
                LearningEventRecord.user_id == payload.user_id,
                LearningEventRecord.course_id == payload.course_id,
                LearningEventRecord.enrollment_id.is_(None),
                LearningEventRecord.event_type == "study_activity",
            )
            .values(enrollment_id=record.id)
        )
        _commit(session, "Não foi possível criar a matrícula.")
        return EnrollmentResponse(
            id=record.id,
            user_id=record.user_id,
            program_id=record.program_id,
            course_id=record.course_id,
            status=record.status,
        )


@router.get("/hierarchy", response_model=list[InstitutionHierarchy])
def hierarchy(
    request: Request,
    institution_id: Annotated[str | None, Query(max_length=36)] = None,
    _: dict[str, str] = Depends(admin_claims),
) -> list[InstitutionHierarchy]:
    database: Database = request.app.state.database
    statement = select(Institution).order_by(Institution.name, Institution.id)
    if institution_id is not None:
        statement = statement.where(Institution.id == institution_id)
    with Session(database.engine) as session:
        institutions = session.scalars(statement).all()
        result: list[InstitutionHierarchy] = []
        for institution in institutions:
            programs = session.scalars(
                select(Program)
                .where(Program.institution_id == institution.id)
                .order_by(Program.name, Program.id)
            ).all()
            result.append(
                InstitutionHierarchy(
                    id=institution.id,
                    name=institution.name,
                    programs=[_program_hierarchy(session, item) for item in programs],
                )
            )
        return result


def _program_hierarchy(session: Session, program: Program) -> ProgramHierarchy:
    course_ids = session.scalars(
        select(ProgramCourse.course_id)
        .where(ProgramCourse.program_id == program.id)
        .order_by(ProgramCourse.course_id)
    ).all()
    memberships = session.scalars(
        select(ProgramMembership)
        .where(ProgramMembership.program_id == program.id)
        .order_by(ProgramMembership.user_id)
    ).all()
    return ProgramHierarchy(
        id=program.id,
        institution_id=program.institution_id,
        name=program.name,
        course_ids=list(course_ids),
        memberships=[
            MembershipResponse(
                user_id=item.user_id,
                program_id=item.program_id,
                role=item.role,
                status=item.status,
            )
            for item in memberships
        ],
    )


def _require(session: Session, model: type, identity: str, detail: str) -> None:
    if session.get(model, identity) is None:
        raise HTTPException(status_code=404, detail=detail)


def _commit(session: Session, detail: str) -> None:
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(status_code=409, detail=detail) from error
