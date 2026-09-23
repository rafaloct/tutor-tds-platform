"""Canonical cohort bindings with explicit legacy lineage; callers own transaction."""
import json
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import and_, exists, or_, select
from sqlalchemy.orm import Session

from .models import ClassEnrollment, ClassMonitor, Classroom, CohortMembership, CourseVersion


def active_student_binding():
    """SQL predicate shared by legacy reads/writes during gradual migration.

    Unmigrated links keep legacy authorization. Once bound, a missing, revoked
    or mismatched canonical membership can never fall back to the legacy link.
    """
    return or_(
        and_(ClassEnrollment.context_id.is_(None), ClassEnrollment.membership_id.is_(None), ClassEnrollment.course_version_id.is_(None)),
        and_(ClassEnrollment.context_id.is_not(None), ClassEnrollment.course_version_id == Classroom.course_version_id,
            exists().where(CohortMembership.id == ClassEnrollment.membership_id,
                CohortMembership.class_id == ClassEnrollment.class_id,
                CohortMembership.user_id == ClassEnrollment.user_id,
                CohortMembership.role == 'student', CohortMembership.status == 'active')),
    )


def membership_id(class_id: str, user_id: str, role: str) -> str:
    return str(uuid5(NAMESPACE_URL, "tds:membership:" + json.dumps([class_id, user_id, role], separators=(",", ":"))))


def bind_membership(session: Session, class_id: str, user_id: str, role: str, status: str = "active", *, preserve_inactive: bool = False) -> CohortMembership:
    identity = membership_id(class_id, user_id, role)
    record = session.get(CohortMembership, identity)
    if record is None:
        record = CohortMembership(id=identity, class_id=class_id, user_id=user_id, role=role, status=status)
        session.add(record)
    elif not (preserve_inactive and record.status == 'inactive'):
        record.status = status
    session.flush()
    return record


def bind_student(session: Session, classroom: Classroom, link: ClassEnrollment, *, preserve_inactive: bool = False) -> None:
    version = session.get(CourseVersion, classroom.course_version_id) if classroom.course_version_id else None
    if version is None or version.course_id != link.course_id or version.status not in {'published', 'archived'}:
        raise ValueError('Context binding requires the pinned published course version')
    identity = membership_id(classroom.id, link.user_id, 'student')
    context_id = str(uuid5(NAMESPACE_URL, 'tds:enrollment:' + json.dumps([identity, version.id], separators=(',', ':'))))
    if link.context_id is not None and (link.context_id != context_id or link.membership_id != identity or link.course_version_id != version.id):
        raise ValueError('An existing contextual enrollment cannot be repointed')
    bind_membership(session, classroom.id, link.user_id, 'student', link.status, preserve_inactive=preserve_inactive)
    link.context_id, link.membership_id, link.course_version_id = context_id, identity, version.id


def backfill_context_bindings(session: Session) -> int:
    """Idempotent reconciliation after rollback; no commit and no inferred edition."""
    from .context_migration_audit import audit_context_lineage
    audit = audit_context_lineage(session)
    if audit['blockers']:
        raise ValueError('Context preflight failed; resolve lineage before backfill')
    for classroom in session.scalars(select(Classroom)):
        bind_membership(session, classroom.id, classroom.teacher_id, 'teacher', preserve_inactive=True)
    for monitor in session.scalars(select(ClassMonitor)):
        bind_membership(session, monitor.class_id, monitor.user_id, 'monitor', preserve_inactive=True)
    count = 0
    for link in session.scalars(select(ClassEnrollment)):
        bind_student(session, session.get(Classroom, link.class_id), link, preserve_inactive=True)
        count += 1
    session.flush()
    return count
