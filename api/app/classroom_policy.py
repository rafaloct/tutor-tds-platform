"""Shared classroom policies enforced by every roster write path."""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import ClassEnrollment, Classroom, ProgramMembership

DEFAULT_CLASS_CAPACITY = 30


def active_occupancy(session: Session, class_id: str) -> int:
    """Count active classroom links, never registrations or historical rows."""
    return int(
        session.scalar(
            select(func.count())
            .select_from(ClassEnrollment)
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.status == "active",
            )
        )
        or 0
    )


def require_available_seat(
    session: Session,
    classroom: Classroom,
    *,
    actor_membership: ProgramMembership | None = None,
    reason: str | None = None,
) -> bool:
    """Fail closed at 30 unless a scoped coordinator explicitly overrides.

    Returns True only when this write is a coordinator capacity exception and
    therefore needs a distinguishable audit action.
    """
    if active_occupancy(session, classroom.id) < DEFAULT_CLASS_CAPACITY:
        return False
    if (
        actor_membership is not None
        and actor_membership.status == "active"
        and actor_membership.program_id == classroom.program_id
        and actor_membership.role == "coordinator"
        and reason is not None
        and len(reason.strip()) >= 3
    ):
        return True
    from fastapi import HTTPException

    raise HTTPException(
        status_code=409,
        detail=(
            "A turma atingiu a capacidade padrão de 30 participantes. "
            "Somente a coordenação pode autorizar exceção com motivo auditável."
        ),
    )
