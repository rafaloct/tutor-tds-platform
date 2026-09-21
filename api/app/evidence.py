from __future__ import annotations

import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .database import Database
from .models import (ClassCheckin, ClassEnrollment, ClassMonitor, Classroom,
    ClassSession, EvidenceImport, EvidenceItem, LearningEventRecord,
    ReviewDecision, SessionReport, Enrollment, ProgramMembership)

router = APIRouter(tags=["evidence"])

class SessionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    starts_at: datetime
    ends_at: datetime
    @model_validator(mode="after")
    def valid(self):
        if self.starts_at.tzinfo is None or self.ends_at.tzinfo is None or self.ends_at <= self.starts_at:
            raise ValueError("janela da sessão inválida")
        return self

class SessionResponse(BaseModel):
    id: str; class_id: str; starts_at: datetime; ends_at: datetime; status: str
    token_expires_at: datetime; token_version: int; checkin_token: str | None = None

class SessionView(BaseModel):
    id: str; class_id: str; starts_at: datetime; ends_at: datetime; status: Literal["open", "closed"]
    token_expires_at: datetime; token_version: int

class SessionPage(BaseModel):
    sessions: list[SessionView]
    total: int
    limit: int
    offset: int

class CheckinCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    kind: Literal["checkin", "checkout"]
    idempotency_key: str = Field(min_length=8, max_length=180, pattern=r"^[A-Za-z0-9_.:-]+$")
    token: str | None = Field(default=None, max_length=200)
    user_id: str | None = Field(default=None, max_length=36)

class CheckinResponse(BaseModel):
    id: str; session_id: str; user_id: str; kind: str; occurred_at: datetime; method: str; evidence_id: str

class EvidenceItemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    item_digest: str = Field(pattern=r"^[0-9a-f]{64,128}$")
    evidence_type: Literal["observation", "activity", "certificate", "message_metadata", "document_metadata"]
    occurred_at: datetime
    user_id: str | None = Field(default=None, max_length=36)
    session_id: str | None = Field(default=None, max_length=36)
    object_reference: str | None = Field(default=None, max_length=500)
    metadata: dict[str, str] = Field(default_factory=dict)
    @model_validator(mode="after")
    def structured_only(self):
        if self.occurred_at.tzinfo is None or self.occurred_at.utcoffset() is None:
            raise ValueError("occurred_at deve conter fuso horário")
        allowed = {"message_count", "mime_type", "source_item_id", "page_count"}
        if not set(self.metadata).issubset(allowed):
            raise ValueError("metadata aceita somente chaves estruturadas")
        if any(len(value) > 120 or "\n" in value for value in self.metadata.values()):
            raise ValueError("metadata não aceita conteúdo bruto")
        if self.object_reference and "://" in self.object_reference:
            raise ValueError("object_reference deve ser identificador privado, não URL")
        return self

class ImportCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    source_type: Literal["whatsapp_export", "drive_metadata", "sharesheet", "manual_metadata"]
    source_digest: str = Field(pattern=r"^[0-9a-f]{64,128}$")
    idempotency_key: str = Field(min_length=8, max_length=180, pattern=r"^[A-Za-z0-9_.:-]+$")
    retention_until: datetime
    items: list[EvidenceItemCreate] = Field(min_length=1, max_length=200)
    @model_validator(mode="after")
    def retention_timezone(self):
        if self.retention_until.tzinfo is None or self.retention_until.utcoffset() is None:
            raise ValueError("retention_until deve conter fuso horário")
        return self

class ImportResponse(BaseModel):
    id: str; class_id: str; source_type: str; status: str; retention_until: datetime; source_digest: str
    evidence_ids: list[str]

class ReviewCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    decision: Literal["accepted", "rejected"]
    reason_code: Literal["verified", "unrelated", "insufficient", "duplicate", "corrected"]

class ReportResponse(BaseModel):
    id: str; class_id: str; session_id: str; generated_at: datetime; report_digest: str; summary: dict[str, object]

@router.post("/admin/classes/{class_id}/sessions", response_model=SessionResponse, status_code=201)
def create_session(class_id: str, payload: SessionCreate, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); _staff(session, classroom, claims, monitor=False)
        token = secrets.token_urlsafe(24); now = datetime.now(timezone.utc)
        record = ClassSession(id=str(uuid4()), class_id=class_id, starts_at=payload.starts_at,
            ends_at=payload.ends_at, status="open", opened_by=claims["sub"],
            checkin_token_digest=_digest(token), token_expires_at=min(payload.ends_at, now + timedelta(minutes=10)), token_version=1)
        session.add(record); session.commit()
        return _session_response(record, token)

@router.get("/classes/{class_id}/sessions", response_model=SessionPage)
def list_sessions(
    class_id: str,
    request: Request,
    status: Literal["open", "closed"] | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    claims=Depends(access_claims),
):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id)
        _class_member(session, classroom, claims)
        filters = [ClassSession.class_id == class_id]
        if status is not None:
            filters.append(ClassSession.status == status)
        total = session.scalar(
            select(func.count()).select_from(ClassSession).where(*filters)
        ) or 0
        records = session.scalars(
            select(ClassSession)
            .where(*filters)
            .order_by(ClassSession.starts_at.desc(), ClassSession.id.desc())
            .offset(offset)
            .limit(limit)
        ).all()
        return SessionPage(
            sessions=[_session_view(item) for item in records],
            total=total,
            limit=limit,
            offset=offset,
        )

@router.get("/classes/{class_id}/sessions/open", response_model=SessionView)
def open_session(class_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id)
        _class_member(session, classroom, claims)
        record = session.scalar(
            select(ClassSession)
            .where(
                ClassSession.class_id == class_id,
                ClassSession.status == "open",
            )
            .order_by(ClassSession.starts_at.desc(), ClassSession.id.desc())
        )
        if record is None:
            raise HTTPException(404, "Sessão aberta não encontrada.")
        return _session_view(record)

@router.get("/classes/{class_id}/sessions/{session_id}", response_model=SessionView)
def get_session(class_id: str, session_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id)
        _class_member(session, classroom, claims)
        return _session_view(_class_session(session, class_id, session_id))

@router.post("/classes/{class_id}/sessions/{session_id}/token", response_model=SessionResponse)
def rotate_token(class_id: str, session_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); _staff(session, classroom, claims, monitor=True)
        record = _class_session(session, class_id, session_id)
        if record.status != "open": raise HTTPException(409, "Sessão encerrada.")
        token = secrets.token_urlsafe(24); record.checkin_token_digest = _digest(token)
        record.token_version += 1
        ends_at = record.ends_at.replace(tzinfo=timezone.utc) if record.ends_at.tzinfo is None else record.ends_at
        record.token_expires_at = min(ends_at, datetime.now(timezone.utc) + timedelta(minutes=10))
        session.commit(); return _session_response(record, token)

@router.post("/classes/{class_id}/sessions/{session_id}/checkins", response_model=CheckinResponse, status_code=201)
def checkin(class_id: str, session_id: str, payload: CheckinCreate, request: Request, response: Response, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); record = _class_session(session, class_id, session_id)
        staff = _is_staff(session, classroom, claims["sub"], claims["role"])
        if payload.user_id and payload.user_id != claims["sub"] and not staff:
            raise HTTPException(403, "Não é permitido registrar presença de outra pessoa.")
        user_id = payload.user_id if staff and payload.user_id else claims["sub"]
        if not _active_student(session, classroom, user_id):
            raise HTTPException(403, "Matrícula na turma não autorizada.")
        existing = session.scalar(select(ClassCheckin).where(ClassCheckin.idempotency_key == payload.idempotency_key))
        if existing:
            if existing.session_id != session_id or existing.user_id != user_id or existing.kind != payload.kind:
                raise HTTPException(409, "Idempotência divergente.")
            if not staff and existing.user_id != claims["sub"]:
                raise HTTPException(403, "Check-in não autorizado.")
            response.status_code = 200; return _checkin_response(existing)
        now = datetime.now(timezone.utc)
        if record.status != "open": raise HTTPException(409, "Sessão encerrada.")
        starts = record.starts_at.replace(tzinfo=timezone.utc) if record.starts_at.tzinfo is None else record.starts_at
        ends = record.ends_at.replace(tzinfo=timezone.utc) if record.ends_at.tzinfo is None else record.ends_at
        if now < starts - timedelta(minutes=15) or now > ends:
            raise HTTPException(409, "Check-in fora da janela da sessão.")
        method = "manual" if staff and payload.user_id else "qr"
        expires = record.token_expires_at.replace(tzinfo=timezone.utc) if record.token_expires_at.tzinfo is None else record.token_expires_at
        if method == "qr" and (not payload.token or not secrets.compare_digest(_digest(payload.token), record.checkin_token_digest) or now > expires):
            raise HTTPException(401, "Token de check-in inválido ou expirado.")
        evidence_id = str(uuid4()); evidence = EvidenceItem(id=evidence_id, class_id=class_id, session_id=session_id,
            user_id=user_id, evidence_type="attendance", occurred_at=now, confidence_basis_points=10000,
            review_status="pending", item_digest=_digest(f"{session_id}:{user_id}:{payload.kind}"), metadata_json={"method": method})
        result = ClassCheckin(id=str(uuid4()), session_id=session_id, user_id=user_id, kind=payload.kind,
            occurred_at=now, method=method, evidence_id=evidence_id, idempotency_key=payload.idempotency_key)
        # No ORM relationship connects these rows, so SQLAlchemy cannot infer
        # their FK dependency. Persist the evidence first on every dialect.
        session.add(evidence); _flush(session)
        session.add(result); _commit(session)
        return _checkin_response(result)

@router.post("/classes/{class_id}/evidence-imports", response_model=ImportResponse, status_code=201)
def import_evidence(class_id: str, payload: ImportCreate, request: Request, response: Response, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); _staff(session, classroom, claims, monitor=True)
        existing = session.scalar(select(EvidenceImport).where(EvidenceImport.idempotency_key == payload.idempotency_key))
        if existing:
            retention = existing.retention_until.replace(tzinfo=timezone.utc) if existing.retention_until.tzinfo is None else existing.retention_until
            requested_retention = payload.retention_until.astimezone(timezone.utc)
            if (existing.class_id != class_id or existing.imported_by != claims["sub"] or
                existing.source_type != payload.source_type or existing.source_digest != payload.source_digest or
                retention.astimezone(timezone.utc) != requested_retention):
                raise HTTPException(409, "Importação divergente.")
            response.status_code = 200; return _import_response(session, existing)
        if payload.retention_until <= datetime.now(timezone.utc): raise HTTPException(422, "Retenção deve ser futura.")
        record = EvidenceImport(id=str(uuid4()), class_id=class_id, source_type=payload.source_type,
            status="pending_review", imported_by=claims["sub"], retention_until=payload.retention_until,
            source_digest=payload.source_digest, idempotency_key=payload.idempotency_key)
        session.add(record)
        for item in payload.items:
            if item.user_id:
                if not _active_student(session, classroom, item.user_id):
                    raise HTTPException(422, "Usuário fora da turma ou matrícula inativa.")
            if item.session_id:
                evidence_session = session.get(ClassSession, item.session_id)
                if evidence_session is None or evidence_session.class_id != class_id: raise HTTPException(422, "Sessão fora da turma.")
            session.add(EvidenceItem(id=str(uuid4()), import_id=record.id, class_id=class_id, session_id=item.session_id,
                user_id=item.user_id, evidence_type=item.evidence_type, occurred_at=item.occurred_at,
                confidence_basis_points=0, review_status="pending", object_reference=item.object_reference,
                item_digest=item.item_digest, metadata_json=item.metadata))
        _commit(session); return _import_response(session, record)

@router.get("/classes/{class_id}/evidence-imports/{import_id}", response_model=ImportResponse)
def get_import(class_id: str, import_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        _staff(session, _class(session, class_id), claims, monitor=True)
        record = session.get(EvidenceImport, import_id)
        if record is None or record.class_id != class_id: raise HTTPException(404, "Importação não encontrada.")
        return _import_response(session, record)

@router.post("/classes/{class_id}/evidence/{evidence_id}/review")
def review(class_id: str, evidence_id: str, payload: ReviewCreate, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        _staff(session, _class(session, class_id), claims, monitor=True)
        item = session.get(EvidenceItem, evidence_id)
        if item is None or item.class_id != class_id: raise HTTPException(404, "Evidência não encontrada.")
        now = datetime.now(timezone.utc); item.review_status = payload.decision
        decision = ReviewDecision(id=str(uuid4()), evidence_id=evidence_id, decision=payload.decision,
            reason_code=payload.reason_code, decided_by=claims["sub"], decided_at=now)
        session.add(decision); session.commit()
        return {"evidence_id": evidence_id, "decision": payload.decision, "reason_code": payload.reason_code, "decided_at": now}

@router.get("/classes/{class_id}/exceptions")
def exceptions(class_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); staff = _is_staff(session, classroom, claims["sub"], claims["role"])
        student_ids = list(session.scalars(select(ClassEnrollment.user_id).where(ClassEnrollment.class_id == class_id, ClassEnrollment.status == "active")))
        if not staff:
            if not _active_student(session, classroom, claims["sub"]): raise HTTPException(403, "Turma não autorizada.")
            student_ids = [claims["sub"]]
        items = session.scalars(select(EvidenceItem).where(EvidenceItem.class_id == class_id, EvidenceItem.review_status == "pending")).all()
        return {"exceptions": [{"code": "evidence_needs_review", "user_id": item.user_id, "evidence_id": item.id} for item in items if (staff and item.user_id is None) or item.user_id in student_ids]}

@router.post("/classes/{class_id}/sessions/{session_id}/close", response_model=ReportResponse)
def close(class_id: str, session_id: str, request: Request, confirm_pending: bool = False, claims=Depends(access_claims)):
    from .presence import presence_summary
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        classroom = _class(session, class_id); _staff(session, classroom, claims, monitor=False)
        class_session = _locked_class_session(session, class_id, session_id)
        existing = session.scalar(select(SessionReport).where(SessionReport.session_id == session_id))
        if existing: return _report(existing)
        pending = list(session.scalars(select(EvidenceItem.id).where(EvidenceItem.session_id == session_id, EvidenceItem.review_status == "pending")))
        presence = presence_summary(session, classroom, session_id)
        if (pending or presence["pending_count"]) and not confirm_pending:
            raise HTTPException(409, "Há evidências/presenças pendentes; confirme o fechamento explicitamente.")
        checkins = list(session.scalars(select(ClassCheckin.id).where(ClassCheckin.session_id == session_id)))
        now = datetime.now(timezone.utc); summary = {"checkin_count": len(checkins), "pending_evidence_ids": pending, "pending_explicitly_confirmed": bool(pending or presence["pending_count"]), "presence": presence, "external_integrations": "disabled"}
        digest = _digest(json.dumps(summary, sort_keys=True) + session_id)
        report = SessionReport(id=str(uuid4()), class_id=class_id, session_id=session_id, generated_by=claims["sub"], generated_at=now, report_digest=digest, summary=summary)
        class_session.status = "closed"; class_session.closed_by = claims["sub"]
        session.add(report); session.commit(); return _report(report)

@router.get("/classes/{class_id}/reports/{report_id}", response_model=ReportResponse)
def get_report(class_id: str, report_id: str, request: Request, claims=Depends(access_claims)):
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        _staff(session, _class(session, class_id), claims, monitor=True)
        report = session.get(SessionReport, report_id)
        if report is None or report.class_id != class_id: raise HTTPException(404, "Relatório não encontrado.")
        return _report(report)

def _class(session, class_id):
    record = session.get(Classroom, class_id)
    if record is None: raise HTTPException(404, "Turma não encontrada.")
    return record
def _class_session(session, class_id, session_id):
    record = session.get(ClassSession, session_id)
    if record is None or record.class_id != class_id: raise HTTPException(404, "Sessão não encontrada.")
    return record
def _locked_class_session(session, class_id, session_id):
    # A no-op write provides the same session-level mutex on SQLite and Postgres.
    # Both formal decisions and close acquire it before reading presence state.
    result = session.execute(update(ClassSession).where(ClassSession.id == session_id, ClassSession.class_id == class_id).values(status=ClassSession.status), execution_options={"synchronize_session": False})
    if result.rowcount != 1: raise HTTPException(404, "Sessão não encontrada.")
    record = _class_session(session, class_id, session_id)
    session.refresh(record)
    return record
def _is_staff(session, classroom, user_id, role):
    if role == "admin":
        return True
    membership = session.get(ProgramMembership, (user_id, classroom.program_id))
    if membership is None or membership.status != "active":
        return False
    if classroom.teacher_id == user_id and membership.role in {"teacher", "coordinator", "admin"}:
        return True
    return membership.role in {"monitor", "teacher", "coordinator", "admin"} and session.get(ClassMonitor, (classroom.id, user_id)) is not None
def _staff(session, classroom, claims, monitor):
    allowed = _is_staff(session, classroom, claims["sub"], claims["role"]) and (monitor or claims["role"] == "admin" or classroom.teacher_id == claims["sub"])
    if not allowed: raise HTTPException(403, "Equipe da turma não autorizada.")
def _class_member(session, classroom, claims):
    if _is_staff(session, classroom, claims["sub"], claims["role"]):
        return
    if not _active_student(session, classroom, claims["sub"]):
        raise HTTPException(403, "Vínculo com a turma não autorizado.")

def _active_student(session, classroom, user_id):
    link = session.get(ClassEnrollment, (classroom.id, user_id))
    membership = session.get(ProgramMembership, (user_id, classroom.program_id))
    enrollment = session.get(Enrollment, link.enrollment_id) if link else None
    return (link is not None and link.status == "active" and
        membership is not None and membership.status == "active" and
        enrollment is not None and enrollment.status == "active" and
        enrollment.user_id == user_id and
        enrollment.program_id == link.program_id == classroom.program_id and
        enrollment.course_id == link.course_id == classroom.course_id)
def _digest(value): return hashlib.sha256(value.encode()).hexdigest()
def _session_response(r, token=None): return SessionResponse(id=r.id, class_id=r.class_id, starts_at=r.starts_at, ends_at=r.ends_at, status=r.status, token_expires_at=r.token_expires_at, token_version=r.token_version, checkin_token=token)
def _session_view(r): return SessionView(id=r.id, class_id=r.class_id, starts_at=r.starts_at, ends_at=r.ends_at, status=r.status, token_expires_at=r.token_expires_at, token_version=r.token_version)
def _checkin_response(r): return CheckinResponse(id=r.id, session_id=r.session_id, user_id=r.user_id, kind=r.kind, occurred_at=r.occurred_at, method=r.method, evidence_id=r.evidence_id)
def _import_response(session, r): return ImportResponse(id=r.id, class_id=r.class_id, source_type=r.source_type, status=r.status, retention_until=r.retention_until, source_digest=r.source_digest, evidence_ids=list(session.scalars(select(EvidenceItem.id).where(EvidenceItem.import_id == r.id))))
def _report(r): return ReportResponse(id=r.id, class_id=r.class_id, session_id=r.session_id, generated_at=r.generated_at, report_digest=r.report_digest, summary=r.summary)
def _commit(session):
    try: session.commit()
    except IntegrityError as exc: session.rollback(); raise HTTPException(409, "Registro duplicado ou divergente.") from exc
def _flush(session):
    try: session.flush()
    except IntegrityError as exc: session.rollback(); raise HTTPException(409, "Registro duplicado ou divergente.") from exc
