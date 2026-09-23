"""Physical bindings preserve legacy lineage and never infer a new edition."""
import os

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import MetaData, create_engine, inspect, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.context_memberships import backfill_context_bindings, bind_student, membership_id
from app.models import Base, ClassEnrollment, Classroom, CohortMembership, LearningEventRecord
from test_course_version_events import event, version_events


def test_account_erasure_removes_canonical_links_without_erasing_staff(version_events):
    from app.auth import router
    client, engine = version_events
    client.app.include_router(router)
    with Session(engine) as session:
        backfill_context_bindings(session)
        session.commit()
    response = client.delete('/auth/me')
    assert response.status_code == 204, response.text
    with Session(engine) as session:
        assert not list(session.scalars(select(CohortMembership).where(CohortMembership.user_id == 'student')))
        assert len(list(session.scalars(select(CohortMembership).where(CohortMembership.user_id == 'teacher')))) == 2


def add_parallel(engine):
    with Session(engine) as session:
        original = session.get(Classroom, 'class-p1')
        session.add(Classroom(id='parallel', program_id='p1', course_id='course', course_version_id='old',
            teacher_id='teacher', name='Parallel', start_date=original.start_date, end_date=original.end_date))
        session.flush()
        session.add(ClassEnrollment(class_id='parallel', user_id='student', enrollment_id='enrollment-p1',
            program_id='p1', course_id='course', status='inactive'))
        session.commit()


def test_backfill_is_idempotent_and_preserves_parallel_inactive_contexts(version_events):
    client, engine = version_events
    add_parallel(engine)
    assert client.post('/events', json=event('preserved', class_id='class-p1', course_version_id='old')).status_code == 201
    with Session(engine) as session:
        before = session.get(LearningEventRecord, 'preserved').payload.copy()
        assert backfill_context_bindings(session) == 3
        session.commit()
        links = list(session.scalars(select(ClassEnrollment)))
        original = {link.class_id: (link.context_id, link.membership_id) for link in links}
        assert len(set(link.context_id for link in links)) == 3
        assert session.get(ClassEnrollment, ('parallel', 'student')).enrollment_id == 'enrollment-p1'
        assert session.get(CohortMembership, membership_id('parallel', 'student', 'student')).status == 'inactive'
        assert backfill_context_bindings(session) == 3
        session.commit()
        assert {link.class_id: (link.context_id, link.membership_id) for link in links} == original
        assert session.get(LearningEventRecord, 'preserved').payload == before
        assert session.get(LearningEventRecord, 'preserved').enrollment_id == 'enrollment-p1'


def test_backfill_failure_is_atomic_and_existing_edition_cannot_be_repointed(version_events):
    _, engine = version_events
    with Session(engine) as session:
        backfill_context_bindings(session)
        session.commit()
        link = session.get(ClassEnrollment, ('class-p1', 'student'))
        stable_id = link.context_id
        classroom = session.get(Classroom, 'class-p1')
        classroom.course_version_id = 'current'
        with pytest.raises(ValueError, match='cannot be repointed'):
            bind_student(session, classroom, link)
        session.rollback()
        assert link.context_id == stable_id and link.course_version_id == 'old'
        classroom.course_version_id = None
        with pytest.raises(ValueError, match='preflight'):
            backfill_context_bindings(session)
        session.rollback()
        assert classroom.course_version_id == 'old'


def test_populated_migration_preserves_data_and_enforces_lineage(tmp_path, version_events):
    client, source = version_events
    add_parallel(source)
    assert client.post('/events', json=event('preserved', class_id='class-p1', course_version_id='old')).status_code == 201
    url = os.environ.get('TDS_CONTEXT_MIGRATION_DATABASE_URL') or f"sqlite+pysqlite:///{(tmp_path / 'physical.db').as_posix()}"
    if os.environ.get('TDS_CONTEXT_MIGRATION_DATABASE_URL'):
        parsed = make_url(url)
        assert parsed.drivername == 'postgresql+psycopg' and parsed.database == 'tds_context_gate'
    target = create_engine(url)
    assert not inspect(target).get_table_names(), 'Migration test requires an empty disposable database'
    config = Config('alembic.ini')
    config.set_main_option('sqlalchemy.url', url)
    command.upgrade(config, '20260921_0018')
    old = MetaData()
    old.reflect(target)
    # Import only fixture data into the actual old schema, without new columns.
    with source.connect() as origin, target.begin() as destination:
        for table in old.sorted_tables:
            if table.name == 'alembic_version':
                continue
            rows = origin.execute(select(Base.metadata.tables[table.name])).mappings().all()
            if rows:
                destination.execute(table.insert(), [{column.name: row[column.name] for column in table.columns} for row in rows])
    command.upgrade(config, 'head')
    with target.connect() as connection:
        if target.dialect.name == 'sqlite':
            connection.execute(text('PRAGMA foreign_keys=ON'))
        links = connection.execute(text('SELECT context_id,membership_id,enrollment_id,status FROM class_enrollments ORDER BY class_id')).all()
        assert len(links) == 3 and len({row.context_id for row in links}) == 3
        assert links[-1].status == 'inactive' and links[-1].enrollment_id == 'enrollment-p1'
        assert connection.execute(text("SELECT status FROM cohort_memberships WHERE class_id='parallel' AND role='student'")).scalar_one() == 'inactive'
        assert connection.execute(text("SELECT enrollment_id FROM learning_events WHERE event_id='preserved'")).scalar_one() == 'enrollment-p1'
        connection.commit()
        for statement in [
            "UPDATE class_enrollments SET membership_id=NULL WHERE class_id='class-p1'",
            "UPDATE class_enrollments SET membership_role='teacher' WHERE class_id='class-p1'",
            "UPDATE class_enrollments SET membership_id=(SELECT id FROM cohort_memberships WHERE class_id='class-p2' AND role='student') WHERE class_id='class-p1'",
        ]:
            with pytest.raises(IntegrityError):
                connection.execute(text(statement))
            connection.rollback()
    # QA downgrade and forward recovery retain legacy rows and recreate same IDs.
    command.downgrade(config, '20260921_0018')
    command.upgrade(config, 'head')
    with target.connect() as connection:
        assert connection.execute(text('SELECT context_id,membership_id,enrollment_id,status FROM class_enrollments ORDER BY class_id')).all() == links
    command.downgrade(config, 'base')
    target.dispose()
