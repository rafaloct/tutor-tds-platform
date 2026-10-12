"""Shared active occupancy and advisory capacity reference."""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .models import ClassEnrollment, Classroom

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


def capacity_warning(session: Session, classroom: Classroom) -> bool:
    """Signal an advisory warning before an assignment crosses 30 active links."""
    return active_occupancy(session, classroom.id) >= DEFAULT_CLASS_CAPACITY
