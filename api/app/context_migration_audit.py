"""Read-only preflight for the physical Membership/Enrollment migration.

Never chooses an arbitrary class for old evidence or writes authorization.
"""
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import ClassEnrollment, Classroom, CourseVersion, Enrollment, LearningEventRecord, ProgramMembership


def audit_context_lineage(session: Session) -> dict:
    classrooms = {item.id: item for item in session.scalars(select(Classroom))}
    versions = {item.id: item for item in session.scalars(select(CourseVersion))}
    enrollments = {item.id: item for item in session.scalars(select(Enrollment))}
    programs = {(item.user_id, item.program_id): item for item in session.scalars(select(ProgramMembership))}
    contexts = defaultdict(list)
    blockers = []
    for link in session.scalars(select(ClassEnrollment)):
        classroom = classrooms.get(link.class_id)
        enrollment = enrollments.get(link.enrollment_id)
        identity = {"cohort_id": link.class_id, "user_id": link.user_id, "legacy_enrollment_id": link.enrollment_id}
        if (classroom is None or enrollment is None or
                enrollment.user_id != link.user_id or
                enrollment.program_id != link.program_id or
                enrollment.course_id != link.course_id or
                classroom.program_id != link.program_id or
                classroom.course_id != link.course_id or
                (link.user_id, link.program_id) not in programs):
            blockers.append({**identity, "reason": "broken_relational_lineage"})
            continue
        if link.status not in {"active", "inactive"}:
            blockers.append({**identity, "reason": "unsupported_membership_status"})
            continue
        version = versions.get(classroom.course_version_id)
        if version is None or version.course_id != link.course_id or version.status not in {"published", "archived"}:
            blockers.append({**identity, "reason": "missing_or_unpublished_pinned_version"})
            continue
        # Inactive links still have a historical identity. Never reactivate them.
        contexts[link.enrollment_id].append((classroom.id, version.id))

    ambiguous_events = []
    for event in session.scalars(select(LearningEventRecord).where(LearningEventRecord.enrollment_id.is_not(None))):
        candidates = contexts[event.enrollment_id]
        payload = event.payload or {}
        if payload.get("class_id"):
            candidates = [item for item in candidates if item[0] == payload["class_id"]]
        if payload.get("course_version_id"):
            candidates = [item for item in candidates if item[1] == payload["course_version_id"]]
        if len(candidates) != 1:
            ambiguous_events.append({"event_id": event.event_id, "candidate_count": len(candidates),
                                     "reason": "preserve_legacy_evidence_without_inferred_context"})
    return {
        "read_only": True,
        "status": "BLOCKED" if blockers else "READY_FOR_ADDITIVE_BACKFILL",
        "context_enrollment_count": sum(map(len, contexts.values())),
        "legacy_enrollments_with_multiple_contexts": sorted(key for key, values in contexts.items() if len(values) > 1),
        "blockers": blockers,
        "unresolved_evidence": ambiguous_events,
        "policy": "Preserve legacy IDs and evidence; never copy one event into several enrollments or reactivate a link.",
    }
