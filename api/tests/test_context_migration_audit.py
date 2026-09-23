from sqlalchemy import select
from sqlalchemy.orm import Session

from app.context_migration_audit import audit_context_lineage
from app.models import ClassEnrollment, Classroom, LearningEventRecord
from test_course_version_events import event, version_events


def test_preflight_preserves_parallel_classes_and_flags_ambiguous_old_evidence(version_events):
    client, engine = version_events
    # An existing program/course enrollment can legitimately span two cohorts.
    with Session(engine) as session:
        original = session.get(Classroom, "class-p1")
        session.add(Classroom(id="parallel", program_id="p1", course_id="course", course_version_id="old",
            teacher_id="teacher", name="Parallel", start_date=original.start_date, end_date=original.end_date))
        session.flush()
        session.add(ClassEnrollment(class_id="parallel", user_id="student", enrollment_id="enrollment-p1",
            program_id="p1", course_id="course", status="inactive"))
        session.commit()
    payload = event("exact", course_version_id="old", class_id="class-p1")
    assert client.post('/events', json=payload).status_code == 201
    with Session(engine) as session:
        exact = session.get(LearningEventRecord, "exact")
        session.add(LearningEventRecord(event_id="legacy", user_id=exact.user_id, enrollment_id=exact.enrollment_id,
            course_id=exact.course_id, event_type=exact.event_type, session_id="legacy", occurred_at=exact.occurred_at,
            payload={}, active_seconds=0, validated_seconds=0, sync_status="pending"))
        session.commit()
        report = audit_context_lineage(session)
        assert report['status'] == 'READY_FOR_ADDITIVE_BACKFILL'
        assert report['context_enrollment_count'] == 3
        assert report['legacy_enrollments_with_multiple_contexts'] == ['enrollment-p1']
        assert report['unresolved_evidence'] == [{'event_id': 'legacy', 'candidate_count': 2,
            'reason': 'preserve_legacy_evidence_without_inferred_context'}]
        assert not session.new and not session.dirty and not session.deleted
        assert session.get(ClassEnrollment, ('parallel', 'student')).status == 'inactive'


def test_preflight_blocks_unpinned_version_without_guessing_current_publication(version_events):
    _, engine = version_events
    with Session(engine) as session:
        session.get(Classroom, 'class-p1').course_version_id = None
        session.commit()
        report = audit_context_lineage(session)
        assert report['status'] == 'BLOCKED'
        assert report['blockers'][0]['reason'] == 'missing_or_unpublished_pinned_version'
        assert session.get(Classroom, 'class-p1').course_version_id is None
        assert len(session.scalars(select(ClassEnrollment)).all()) == 2
