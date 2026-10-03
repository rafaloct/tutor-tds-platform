"""Scoped administrative commands over existing identity/enrollment entities."""
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import re
from typing import Literal
from uuid import uuid4

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import AuthService, RegisterRequest, access_claims
from .context_memberships import bind_student, membership_id
from .models import (ClassEnrollment, Classroom, CohortMembership, Enrollment,
                     OperatorCommandReceipt, Program, ProgramCourse,
                     ProgramMembership, StudentBaseline, User)

router = APIRouter(prefix="/operations", tags=["operations"])


class Search(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    query: str = Field(min_length=2, max_length=100)


class PersonLookup(BaseModel):
    model_config = ConfigDict(extra="forbid")
    person_id: str = Field(min_length=1, max_length=36)
    identity_proof: str | None = Field(default=None, max_length=2000)


class Command(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    id: str = Field(min_length=16, max_length=180)
    action: Literal["register", "enroll", "assign", "revoke"]
    reason: str = Field(min_length=3, max_length=500)
    institution_id: str
    program_id: str
    course_id: str
    version_id: str
    person_id: str | None = Field(default=None, max_length=36)
    expected_revision: int | None = Field(default=None, ge=0)
    identity_proof: str | None = Field(default=None, max_length=2000)
    registration: RegisterRequest | None = None


def enabled(request):
    if not request.app.state.settings.operator_operations_enabled:
        raise HTTPException(404, "Operação indisponível.")


def authorized(session, program_id, actor_id):
    actor = session.get(User, actor_id)
    membership = session.get(ProgramMembership, (actor_id, program_id))
    # Even a global admin requires a scoped active program membership here.
    if actor is None or membership is None or membership.status != "active" or membership.role not in {"program_operator", "coordinator", "admin"}:
        raise HTTPException(403, "Operador não autorizado neste programa.")


def context(session, class_id, actor_id, *, write=False):
    classroom = session.get(Classroom, class_id)
    if classroom is None:
        raise HTTPException(404, "Contexto indisponível.")
    # Serialize all commands in the program, including cross-class corrections.
    statement = select(Program).where(Program.id == classroom.program_id)
    program = session.scalar(statement.with_for_update() if write else statement)
    authorized(session, program.id, actor_id)
    if classroom.course_version_id is None:
        raise HTTPException(409, "Turma sem edição fixada.")
    return classroom, program


def scope_of(classroom, program):
    return {"institution_id": program.institution_id, "program_id": program.id,
            "course_id": classroom.course_id, "class_id": classroom.id,
            "version_id": classroom.course_version_id,
            "label": f"{program.name} / {classroom.name}"}


def secret(request):
    return request.app.state.settings.require_auth_secrets()[0]


def identity_proof(request, actor, program, subject):
    return jwt.encode({"purpose": "operator_identity", "sub": subject,
                       "actor": actor, "program": program,
                       "exp": datetime.now(timezone.utc) + timedelta(minutes=10)},
                      secret(request), algorithm="HS256")


def require_person(session, request, program_id, actor_id, person_id, proof):
    person = session.get(User, person_id)
    if person is None:
        raise HTTPException(404, "Pessoa não localizada.")
    member = session.get(ProgramMembership, (person_id, program_id))
    if member is not None:
        return person
    try:
        claims = jwt.decode(proof or "", secret(request), algorithms=["HS256"])
        if (claims.get("purpose"), claims.get("actor"), claims.get("program"), claims.get("sub")) != ("operator_identity", actor_id, program_id, person_id):
            raise ValueError("scope")
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(403, "Confirme a identidade por busca exata antes do vínculo.") from None
    return person


def revision(session, program_id, person_id):
    return session.scalar(select(func.max(OperatorCommandReceipt.revision)).where(
        OperatorCommandReceipt.program_id == program_id,
        OperatorCommandReceipt.subject_id == person_id)) or 0


def snapshot(session, classroom, program, person):
    enrollment = session.scalar(select(Enrollment).where(Enrollment.user_id == person.id,
        Enrollment.program_id == program.id, Enrollment.course_id == classroom.course_id))
    link = session.get(ClassEnrollment, (classroom.id, person.id))
    bound = session.get(CohortMembership, membership_id(classroom.id, person.id, "student"))
    baseline = session.scalar(select(StudentBaseline.id).where(StudentBaseline.class_id == classroom.id,
        StudentBaseline.user_id == person.id))
    history = session.scalars(select(OperatorCommandReceipt).where(
        OperatorCommandReceipt.subject_id == person.id, OperatorCommandReceipt.class_id == classroom.id)
        .order_by(OperatorCommandReceipt.revision.desc()).limit(100)).all()
    return {"person": {"id": person.id, "name": person.name}, "scope": scope_of(classroom, program),
            "revision": revision(session, program.id, person.id),
            "enrolled": enrollment is not None and enrollment.status == "active",
            "assigned": link is not None and link.status == "active" and bound is not None and bound.status == "active",
            "baseline_linked": baseline is not None,
            "history_ids": [item.id for item in history]}


def hydrate(session, result):
    """Resolve actor references at read time; never duplicate them in JSON."""
    response = {key: value for key, value in result.items() if key != "history_ids"}
    history = [session.get(OperatorCommandReceipt, key) for key in result["history_ids"]]
    response["history"] = [{"action": item.action, "reason": item.reason,
        "actor_label": item.actor_id or "ator removido",
        "occurred_at": item.occurred_at.isoformat()} for item in history if item is not None]
    return response


@router.get("/scopes")
def scopes(request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        records = session.execute(select(Classroom, Program).join(Program, Classroom.program_id == Program.id)
            .join(ProgramMembership, ProgramMembership.program_id == Program.id)
            .where(ProgramMembership.user_id == claims["sub"], ProgramMembership.status == "active",
                   ProgramMembership.role.in_(["program_operator", "coordinator", "admin"]),
                   Classroom.course_version_id.is_not(None)).order_by(Classroom.id).limit(100)).all()
        return {"scopes": [scope_of(classroom, program) for classroom, program in records]}


@router.post("/{class_id}/search")
def search(class_id: str, payload: Search, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        _, program = context(session, class_id, claims["sub"])
        digits = re.sub(r"\D", "", payload.query)
        if len(digits) == 11:
            digest = AuthService(session, request.app.state.settings)._cpf_digest(payload.query)
            people = session.scalars(select(User).where(User.cpf_digest == digest)).all()
        else:
            people = session.scalars(select(User).join(ProgramMembership, ProgramMembership.user_id == User.id)
                .where(ProgramMembership.program_id == program.id, User.name.icontains(payload.query, autoescape=True))
                .order_by(User.name, User.id).limit(50)).all()
        return {"people": [{"id": person.id, "name": person.name,
            "identity_proof": identity_proof(request, claims["sub"], program.id, person.id)} for person in people]}


@router.post("/{class_id}/inspect")
def inspect(class_id: str, payload: PersonLookup, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        classroom, program = context(session, class_id, claims["sub"])
        person = require_person(session, request, program.id, claims["sub"], payload.person_id, payload.identity_proof)
        return hydrate(session, snapshot(session, classroom, program, person))


@router.post("/{class_id}/commands")
def execute(class_id: str, payload: Command, request: Request, claims=Depends(access_claims)):
    enabled(request)
    # HMAC prevents offline dictionary recovery of CPF/password from receipt hash.
    body = payload.model_dump(mode="json", exclude={"identity_proof"})
    if payload.registration:
        body["registration"]["cpf"] = payload.registration.cpf.get_secret_value()
        body["registration"]["password"] = payload.registration.password.get_secret_value()
    digest = hmac.new(secret(request).encode(), json.dumps(body, sort_keys=True, separators=(",", ":")).encode(), hashlib.sha256).hexdigest()
    with Session(request.app.state.database.engine) as session:
        classroom, program = context(session, class_id, claims["sub"], write=True)
        expected = scope_of(classroom, program)
        if any(getattr(payload, key) != expected[key] for key in ["institution_id", "program_id", "course_id", "version_id"]):
            raise HTTPException(409, "Contexto mudou; consulte novamente.")
        previous = session.get(OperatorCommandReceipt, payload.id)
        if previous:
            if previous.actor_id != claims["sub"] or previous.class_id != class_id or previous.request_hash != digest:
                raise HTTPException(409, "Replay divergente.")
            return hydrate(session, previous.result)
        if classroom.status == "closed":
            raise HTTPException(409, "Turma encerrada.")
        try:
            if payload.action == "register":
                if payload.registration is None or payload.person_id is not None:
                    raise HTTPException(422, "Cadastro inválido.")
                person = AuthService(session, request.app.state.settings).register(payload.registration)
                session.add(ProgramMembership(user_id=person.id, program_id=program.id, role="student", status="active"))
                session.flush()
            else:
                if payload.registration is not None or payload.person_id is None:
                    raise HTTPException(422, "Comando inválido.")
                person = require_person(session, request, program.id, claims["sub"], payload.person_id, payload.identity_proof)
                if payload.expected_revision != revision(session, program.id, person.id):
                    raise HTTPException(409, "Outra operação alterou os vínculos; consulte novamente.")
                mutate(session, classroom, program, person, payload.action)
            receipt = OperatorCommandReceipt(id=payload.id, actor_id=claims["sub"], subject_id=person.id,
                program_id=program.id, class_id=class_id, revision=revision(session, program.id, person.id)+1,
                action=payload.action, reason=payload.reason, request_hash=digest, result={}, occurred_at=datetime.now(timezone.utc))
            session.add(receipt)
            session.flush()
            result = snapshot(session, classroom, program, person)
            receipt.result = result
            session.commit()
            return hydrate(session, result)
        except IntegrityError:
            session.rollback()
            raise HTTPException(409, "Conflito de cadastro ou operação. Consulte novamente.") from None


def mutate(session, classroom, program, person, action):
    member = session.get(ProgramMembership, (person.id, program.id))
    if member is not None and member.status != "active":
        raise HTTPException(409, "Vínculo de programa inativo exige revisão específica.")
    enrollment = session.scalar(select(Enrollment).where(Enrollment.user_id == person.id,
        Enrollment.program_id == program.id, Enrollment.course_id == classroom.course_id))
    if action == "enroll":
        if session.get(ProgramCourse, (program.id, classroom.course_id)) is None:
            raise HTTPException(409, "Curso não ofertado no programa.")
        if member is None:
            session.add(ProgramMembership(user_id=person.id, program_id=program.id, role="student", status="active"))
            session.flush()
        if enrollment is None:
            session.add(Enrollment(id=str(uuid4()), user_id=person.id, program_id=program.id,
                course_id=classroom.course_id, status="active"))
        elif enrollment.status != "active":
            raise HTTPException(409, "Matrícula inativa exige revisão específica.")
        session.flush()
        return
    if member is None or enrollment is None or enrollment.status != "active":
        raise HTTPException(409, "Matrícula ativa necessária.")
    link = session.get(ClassEnrollment, (classroom.id, person.id))
    if action == "assign":
        if link is None:
            link = ClassEnrollment(class_id=classroom.id, user_id=person.id, enrollment_id=enrollment.id,
                program_id=program.id, course_id=classroom.course_id, status="active")
            session.add(link)
        elif link.enrollment_id != enrollment.id or link.course_version_id not in {None, classroom.course_version_id}:
            raise HTTPException(409, "Linhagem divergente.")
        link.status = "active"
        try:
            bind_student(session, classroom, link)
        except ValueError:
            raise HTTPException(409, "Edição ou vínculo inconsistente.") from None
    else:
        if link is None:
            raise HTTPException(409, "Vínculo não existe.")
        link.status = "inactive"
        bound = session.get(CohortMembership, membership_id(classroom.id, person.id, "student"))
        if bound is not None:
            bound.status = "inactive"
    session.flush()
