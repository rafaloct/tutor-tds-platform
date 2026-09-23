"""API golden path with real auth and a reopened file DB; not device/staging QA."""
from datetime import date, datetime, timezone
import os

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.context_memberships import backfill_context_bindings
from app.main import create_app
from app.models import ClassEnrollment, Classroom, Course, CourseVersion, Enrollment, Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User


def test_student_learning_path_instructor_observation_and_reconnect_after_restart(tmp_path):
    url = os.environ.get('TDS_CONTEXT_GATE_DATABASE_URL') or f"sqlite+pysqlite:///{(tmp_path / 'golden.db').as_posix()}"
    if os.environ.get('TDS_CONTEXT_GATE_DATABASE_URL'):
        from sqlalchemy.engine import make_url
        parsed = make_url(url)
        assert parsed.drivername == 'postgresql+psycopg' and parsed.database == 'tds_context_gate', 'Only isolated gate database allowed'
    migration = Config('alembic.ini')
    migration.set_main_option('sqlalchemy.url', url)
    command.upgrade(migration, 'head')
    settings = Settings(database_url=url, allowed_origins=(), jwt_secret='test-' * 8,
                        cpf_pepper='test-pepper-' * 4, learning_context_enabled=True)
    app = create_app(settings=settings)
    password = 'synthetic-password-2026'
    with TestClient(app) as client:
        identities = {}
        for persona, cpf in [('student', '12345678909'), ('teacher', '11144477735')]:
            registered = client.post('/auth/register', json={'name': persona, 'cpf': cpf,
                'phone': '61999990000', 'password': password})
            assert registered.status_code == 201, registered.text
            logged = client.post('/auth/login', json={'cpf': cpf, 'password': password})
            assert logged.status_code == 200, logged.text
            identities[persona] = logged.json()
        student_id = identities['student']['user']['id']
        teacher_id = identities['teacher']['user']['id']
        student = {'Authorization': 'Bearer ' + identities['student']['access_token']}
        teacher = {'Authorization': 'Bearer ' + identities['teacher']['access_token']}
        with Session(app.state.database.engine) as session:
            session.add(Institution(id='org', name='Synthetic TDS'))
            session.flush()
            session.add(Program(id='program', institution_id='org', name='Synthetic program'))
            content = {'id': 'course', 'title': 'Synthetic course', 'author': 'TDS',
                       'sections': [{'id': 'module', 'title': 'Module', 'messages': [{'id': 'block', 'type': 'bot', 'content': 'Learn'}]}]}
            session.add(Course(id='course', title='Synthetic course', author='TDS', content=content, active=True))
            session.flush()
            session.add_all([ProgramCourse(program_id='program', course_id='course', planned_seconds=60),
                ProgramMembership(user_id=student_id, program_id='program', role='student'),
                ProgramMembership(user_id=teacher_id, program_id='program', role='teacher'),
                CourseVersion(id='edition', course_id='course', version_number=1, revision=1, status='published', content=content)])
            session.flush()
            session.add(Enrollment(id='enrollment', user_id=student_id, program_id='program', course_id='course'))
            session.add(Classroom(id='cohort', program_id='program', course_id='course', course_version_id='edition',
                teacher_id=teacher_id, name='Synthetic cohort', start_date=date(2026, 1, 1), end_date=date(2027, 1, 1), status='active'))
            session.flush()
            session.add(ClassEnrollment(class_id='cohort', user_id=student_id, enrollment_id='enrollment', program_id='program', course_id='course'))
            session.flush()
            backfill_context_bindings(session)
            session.commit()
        path = '/classes/cohort/learning-context'
        # A person may teach elsewhere and learn here. Authenticate again after
        # changing the legacy identity role so this exercises real JWT checks.
        with Session(app.state.database.engine) as session:
            session.get(User, student_id).role = 'teacher'
            session.commit()
        logged = client.post('/auth/login', json={'cpf': '12345678909', 'password': password})
        assert logged.status_code == 200, logged.text
        student = {'Authorization': 'Bearer ' + logged.json()['access_token']}
        initial = client.get(path, headers=student)
        assert initial.status_code == 200, initial.text
        assert initial.json()['context']['course_version_id'] == client.get('/classes/cohort/course', headers=student).json()['course_version_id']
        assert initial.json()['progress']['progress_percent'] == 0
        payload = {'event_id': 'offline-stable-id', 'event_type': 'study_activity', 'course_id': 'course',
            'session_id': 'offline-session', 'occurred_at': datetime.now(timezone.utc).isoformat(), 'active_seconds': 30,
            'payload': {'class_id': 'cohort', 'course_version_id': 'edition'}}
        assert client.post('/events', headers=student, json=payload).status_code == 201
        expected = client.get(path, headers=student).json()['progress']
        assert expected['progress_percent'] == 50
        assert client.get('/classes/cohort/dashboard', headers=teacher).json()['students'][0] == expected
        assert client.get('/classes/cohort/dashboard', headers=student).status_code == 403
    # New application + connection pool, same persistent DB and real session.
    reopened = create_app(settings=settings)
    with TestClient(reopened) as client:
        assert client.get(path, headers=student).json()['progress'] == expected
        assert client.post('/events', headers=student, json=payload).status_code == 200
        observed = client.get(f'/classes/cohort/students/{student_id}/learning-context', headers=teacher)
        assert observed.status_code == 200, observed.text
        assert observed.json()['progress'] == expected
        with Session(reopened.state.database.engine) as session:
            assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 1
