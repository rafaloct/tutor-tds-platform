"""Human attendance is separate from evidence acceptance and QR check-ins.

Owner erasure removes private association/name/reason/history. Departed actors in
other people's decisions are anonymized. Reports store only aggregate counts.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .evidence import _active_student, _class, _class_session, _locked_class_session, _staff
from .models import ClassCheckin, ClassEnrollment, Enrollment, EvidenceItem, ProgramMembership, SessionPresence, SessionPresenceDecision, User

router = APIRouter(tags=["presence"])
STATUSES = ("pending", "suggested_present", "confirmed_present", "justified_absence", "absent")


class PresenceCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    status: Literal["confirmed_present", "justified_absence", "absent"]
    expected_revision: int = Field(ge=0)
    reason: str = Field(min_length=3, max_length=500)
    idempotency_key: str = Field(min_length=8, max_length=180, pattern=r"^[A-Za-z0-9_.:-]+$")


def _roster(classroom, session_id):
    return select(ClassEnrollment, User, SessionPresence).join(User, User.id == ClassEnrollment.user_id).join(
        Enrollment, Enrollment.id == ClassEnrollment.enrollment_id,
    ).join(ProgramMembership, (ProgramMembership.user_id == ClassEnrollment.user_id) & (ProgramMembership.program_id == ClassEnrollment.program_id)).outerjoin(
        SessionPresence, (SessionPresence.session_id == session_id) & (SessionPresence.user_id == ClassEnrollment.user_id),
    ).where(
        ClassEnrollment.class_id == classroom.id,
        ClassEnrollment.program_id == classroom.program_id,
        ClassEnrollment.course_id == classroom.course_id,
        ClassEnrollment.status == "active",
        Enrollment.user_id == ClassEnrollment.user_id,
        Enrollment.program_id == ClassEnrollment.program_id,
        Enrollment.course_id == ClassEnrollment.course_id,
        Enrollment.status == "active",
        ProgramMembership.status == "active",
    )


def _counts(session, class_id, session_id, user_ids):
    result = {identity: {"checkin_count": 0, "checkout_count": 0, "activity_count": 0} for identity in user_ids}
    if not result:
        return result
    # Rejected evidence is not a suggestion. Counts never confer formal presence.
    checkins = session.execute(select(ClassCheckin.user_id, ClassCheckin.kind, func.count()).join(
        EvidenceItem, EvidenceItem.id == ClassCheckin.evidence_id,
    ).where(
        ClassCheckin.session_id == session_id, ClassCheckin.user_id.in_(user_ids),
        EvidenceItem.class_id == class_id, EvidenceItem.session_id == session_id,
        EvidenceItem.user_id == ClassCheckin.user_id, EvidenceItem.review_status != "rejected",
    ).group_by(ClassCheckin.user_id, ClassCheckin.kind))
    for user_id, kind, count in checkins:
        if kind in {"checkin", "checkout"}:
            result[user_id][f"{kind}_count"] = count
    activities = session.execute(select(EvidenceItem.user_id, func.count()).where(
        EvidenceItem.class_id == class_id, EvidenceItem.session_id == session_id,
        EvidenceItem.user_id.in_(user_ids), EvidenceItem.evidence_type == "activity",
        EvidenceItem.review_status != "rejected",
    ).group_by(EvidenceItem.user_id))
    for user_id, count in activities:
        result[user_id]["activity_count"] = count
    return result


def _utc(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _view(link, user, presence, counts, decision=None):
    state = decision or presence
    return {
        "user_id": user.id, "user_name": presence.user_name if presence else user.name,
        "enrollment_id": presence.enrollment_id if presence else link.enrollment_id,
        "status": state.status if state else ("suggested_present" if counts["checkin_count"] or counts["activity_count"] else "pending"),
        "revision": state.revision if state else 0,
        **counts,
        "reason": state.reason if state else None,
        "decided_at": _utc(state.decided_at) if state else None,
    }


def presence_summary(session, classroom, session_id):
    rows = session.execute(_roster(classroom, session_id)).all()
    counts = _counts(session, classroom.id, session_id, [user.id for _, user, _ in rows])
    states = Counter(_view(link, user, presence, counts[user.id])["status"] for link, user, presence in rows)
    return {"total": len(rows), "counts": {status: states[status] for status in STATUSES}, "pending_count": states["pending"] + states["suggested_present"]}


@router.get("/classes/{class_id}/sessions/{session_id}/presence")
def list_presence(class_id: str, session_id: str, request: Request, limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _class(session, class_id)
        _staff(session, classroom, claims, monitor=True)
        class_session = _class_session(session, class_id, session_id)
        query = _roster(classroom, session_id)
        total = session.scalar(select(func.count()).select_from(query.subquery())) or 0
        rows = session.execute(query.order_by(User.name, User.id).offset(offset).limit(limit)).all()
        counts = _counts(session, class_id, session_id, [user.id for _, user, _ in rows])
        return {"items": [_view(link, user, presence, counts[user.id]) for link, user, presence in rows], "total": total, "limit": limit, "offset": offset, "session_status": class_session.status}


@router.post("/classes/{class_id}/sessions/{session_id}/presence/{user_id}")
def decide_presence(class_id: str, session_id: str, user_id: str, payload: PresenceCreate, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        classroom = _class(session, class_id)
        _staff(session, classroom, claims, monitor=True)
        if user_id == claims["sub"]:
            raise HTTPException(403, "A decisão exige outra pessoa da equipe.")
        class_session = _locked_class_session(session, class_id, session_id)
        if not _active_student(session, classroom, user_id):
            raise HTTPException(403, "Matrícula/vínculo ativo e consistente obrigatório.")
        link = session.get(ClassEnrollment, (class_id, user_id))
        user = session.get(User, user_id)
        record = session.scalar(select(SessionPresence).where(SessionPresence.session_id == session_id, SessionPresence.user_id == user_id))
        if record is not None and record.enrollment_id != link.enrollment_id:
            raise HTTPException(409, "Matrícula do vínculo mudou; associação histórica preservada.")
        previous = session.scalar(select(SessionPresenceDecision).where(SessionPresenceDecision.idempotency_key == payload.idempotency_key))
        if previous is not None:
            if record is None or previous.presence_id != record.id or previous.actor_user_id != claims["sub"] or previous.revision != payload.expected_revision + 1 or previous.status != payload.status or previous.reason != payload.reason:
                raise HTTPException(409, "Idempotência divergente.")
            return _view(link, user, record, previous.evidence_counts, decision=previous)
        if class_session.status != "open":
            raise HTTPException(409, "Sessão encerrada.")
        if (record.revision if record else 0) != payload.expected_revision:
            raise HTTPException(409, "Presença alterada; recarregue a revisão.")
        counts = _counts(session, class_id, session_id, [user_id])[user_id]
        now = datetime.now(timezone.utc)
        try:
            if record is None:
                record = SessionPresence(id=str(uuid4()), session_id=session_id, class_id=class_id, user_id=user_id, enrollment_id=link.enrollment_id, program_id=classroom.program_id, course_id=classroom.course_id, user_name=user.name, status=payload.status, revision=1, reason=payload.reason, decided_at=now)
                session.add(record)
                session.flush()
            else:
                result = session.execute(update(SessionPresence).where(SessionPresence.id == record.id, SessionPresence.revision == payload.expected_revision).values(status=payload.status, revision=payload.expected_revision + 1, reason=payload.reason, decided_at=now), execution_options={"synchronize_session": False})
                if result.rowcount != 1:
                    raise HTTPException(409, "Presença alterada; recarregue a revisão.")
                session.refresh(record)
            membership = session.get(ProgramMembership, (claims["sub"], classroom.program_id))
            role = "admin" if claims["role"] == "admin" else membership.role
            session.add(SessionPresenceDecision(id=str(uuid4()), presence_id=record.id, revision=record.revision, status=payload.status, reason=payload.reason, decided_at=now, actor_user_id=claims["sub"], actor_role=role, idempotency_key=payload.idempotency_key, evidence_counts=counts))
            session.commit()
        except IntegrityError as error:
            session.rollback()
            raise HTTPException(409, "Decisão concorrente/inconsistente; recarregue.") from error
        return _view(link, user, record, counts)
