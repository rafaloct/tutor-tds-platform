from __future__ import annotations

from datetime import datetime, timezone
import json
import sys
from uuid import uuid4

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.database import Database
from app.main import create_app
from app.models import ClassEnrollment, Classroom, CohortMembership, LearningEventRecord, User
from ops.seed_context_android import SeedSafetyError, seed_context
from ops import verify_cloud_context_isolation as verify


def local_inputs():
    runtime = {'DATABASE_URL':f'postgresql://postgres:synthetic@db.{verify.APPROVED_SUPABASE_PROJECT}.supabase.co:5432/postgres?sslmode=require',
        'TUTOR_ENVIRONMENT':'staging', 'PUBLIC_API_BASE_URL':verify.API_BASE,
        'LEARNING_CONTEXT_ENABLED':'true', 'JWT_SECRET':'test-jwt-' * 5, 'CPF_PEPPER':'test-pepper-' * 4,
        'QA_STUDENT_PASSWORD':'synthetic-student-password', 'QA_TEACHER_PASSWORD':'synthetic-teacher-password'}
    client = {key:runtime[key] for key in ['TUTOR_ENVIRONMENT', 'LEARNING_CONTEXT_ENABLED', 'QA_STUDENT_PASSWORD', 'QA_TEACHER_PASSWORD']}
    client.update(TUTOR_API_URL=verify.API_BASE, TUTOR_STAGING_API_URL=verify.API_BASE,
        QA_STUDENT_CPF='12345678909', QA_TEACHER_CPF='11144477735',
        QA_STUDENT_ID=str(uuid4()), QA_TEACHER_ID=str(uuid4()))
    return runtime, client


def test_local_inputs_accept_only_approved_cloud_endpoints():
    runtime, client = local_inputs()
    settings = verify.validate_inputs(runtime, client)
    assert settings.public_api_base_url == verify.API_BASE
    assert len(verify.outsider_password(settings)) == 64


@pytest.mark.parametrize('container,key,value', [
    ('runtime', 'DATABASE_URL', 'postgresql://postgres:synthetic@db.crxdnwqhogikjbyflwiq.supabase.co:5432/postgres?sslmode=require'),
    ('runtime', 'DATABASE_URL', f'postgresql://postgres:synthetic@db.{verify.APPROVED_SUPABASE_PROJECT}.supabase.co:5432/postgres'),
    ('runtime', 'PUBLIC_API_BASE_URL', 'https://tutor-tds.fastapicloud.dev'),
    ('runtime', 'TUTOR_ENVIRONMENT', 'production'),
    ('client', 'TUTOR_STAGING_API_URL', 'https://other.fastapicloud.dev'),
    ('client', 'QA_STUDENT_ID', '../other-user'),
    ('client', 'QA_TEACHER_CPF', 'unapproved'),
    ('client', 'QA_STUDENT_PASSWORD', 'different-password'),
])
def test_local_inputs_reject_mismatched_runtime(container, key, value):
    runtime, client = local_inputs()
    (runtime if container == 'runtime' else client)[key] = value
    with pytest.raises(SeedSafetyError):
        verify.validate_inputs(runtime, client)


def test_redirects_never_forward_authentication():
    assert verify.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.test') is None


def test_default_cli_validates_only_local_files(tmp_path, monkeypatch, capsys):
    runtime, client = local_inputs()
    runtime_path, client_path = tmp_path / 'runtime.json', tmp_path / 'client.json'
    runtime_path.write_text(json.dumps(runtime), encoding='utf-8')
    client_path.write_text(json.dumps(client), encoding='utf-8')
    monkeypatch.setattr(sys, 'argv', ['verify', '--runtime-json', str(runtime_path), '--client-defines', str(client_path)])
    def no_remote(*args, **kwargs):
        pytest.fail('Default command must not connect to DB or HTTPS')
    monkeypatch.setattr(verify, 'Database', no_remote)
    monkeypatch.setattr(verify, 'StagingHttp', no_remote)
    verify.main()
    result = json.loads(capsys.readouterr().out)
    assert result['status'] == 'local_inputs_validated'
    assert result['remote_access'] is False


@pytest.fixture
def seeded_database(tmp_path, monkeypatch):
    monkeypatch.delenv('DATABASE_URL', raising=False)
    url = f"sqlite+pysqlite:///{(tmp_path / 'isolation.db').as_posix()}"
    migration = Config('alembic.ini')
    migration.set_main_option('sqlalchemy.url', url)
    command.upgrade(migration, 'head')
    runtime, client = local_inputs()
    settings = Settings(database_url=url, allowed_origins=(), jwt_secret=runtime['JWT_SECRET'],
        cpf_pepper=runtime['CPF_PEPPER'], learning_context_enabled=True)
    database = Database(url)
    with Session(database.engine) as session, session.begin():
        users = seed_context(session, settings, student_password=runtime['QA_STUDENT_PASSWORD'],
            teacher_password=runtime['QA_TEACHER_PASSWORD'])
        client.update(QA_STUDENT_ID=users['student_id'], QA_TEACHER_ID=users['teacher_id'])
        session.add(LearningEventRecord(event_id='unit-isolation-existing-event', user_id=users['student_id'],
            enrollment_id='qa-legacy-enrollment', course_id='qa-course', event_type='study_activity',
            session_id='unit-isolation-existing-session', occurred_at=datetime.now(timezone.utc),
            active_seconds=30, validated_seconds=30,
            payload={'class_id':'qa-cohort', 'course_version_id':'qa-edition-1'}))
    try:
        yield database, settings, client
    finally:
        database.dispose()


def test_fixture_is_additive_idempotent_and_preserves_original_events(seeded_database):
    database, settings, client = seeded_database
    with Session(database.engine) as session:
        before = verify.original_snapshot(session, client)
    with Session(database.engine) as session, session.begin():
        first = verify.ensure_fixture(session, settings, client)
        assert first['created'] is True
    with Session(database.engine) as session, session.begin():
        second = verify.ensure_fixture(session, settings, client)
        assert second == {'created':False, 'outsider_id':first['outsider_id']}
        assert verify.original_snapshot(session, client) == before
        assert session.scalar(select(func.count()).select_from(User)) == 3
        assert session.scalar(select(func.count()).select_from(Classroom)) == 2
        assert session.scalar(select(func.count()).select_from(CohortMembership)) == 4
        assert session.scalar(select(func.count()).select_from(ClassEnrollment)) == 2
        assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 1
        original = verify.resolve_student_context(session, 'qa-cohort', client['QA_STUDENT_ID'])
        second_context = verify.resolve_student_context(session, verify.SECOND_COHORT, client['QA_STUDENT_ID'])
        assert original.context.enrollment_id != second_context.context.enrollment_id
        assert original.context.legacy_enrollment_id == second_context.context.legacy_enrollment_id
        assert original.progress.progress_percent == 25
        assert second_context.progress.progress_percent == 0


def test_existing_mismatched_fixture_is_rejected_without_repair(seeded_database):
    database, settings, client = seeded_database
    with Session(database.engine) as session, session.begin():
        verify.ensure_fixture(session, settings, client)
    with Session(database.engine) as session, session.begin():
        session.get(Classroom, verify.SECOND_COHORT).course_version_id = 'qa-edition-2'
    with Session(database.engine) as session:
        with pytest.raises(SeedSafetyError, match='isolation cohort'):
            verify.ensure_fixture(session, settings, client)
        assert session.get(Classroom, verify.SECOND_COHORT).course_version_id == 'qa-edition-2'


def test_unknown_original_identity_is_rejected_before_adding_fixture(seeded_database):
    database, settings, client = seeded_database
    client['QA_STUDENT_ID'] = str(uuid4())
    with Session(database.engine) as session:
        with pytest.raises(SeedSafetyError):
            verify.ensure_fixture(session, settings, client)
        assert session.scalar(select(func.count()).select_from(User)) == 2
        assert session.scalar(select(func.count()).select_from(Classroom)) == 1


def test_authenticated_outsider_without_enrollment_cannot_read_original_learning_path(seeded_database):
    database, settings, client = seeded_database
    with Session(database.engine) as session, session.begin():
        before = verify.original_snapshot(session, client)
        fixture = verify.ensure_fixture(session, settings, client)
        assert session.get(ClassEnrollment, ('qa-cohort', fixture['outsider_id'])) is None
    with TestClient(create_app(settings=settings)) as api:
        login = api.post('/auth/login', json={
            'cpf':verify.OUTSIDER_CPF, 'password':verify.outsider_password(settings),
        })
        assert login.status_code == 200
        assert login.json()['user']['id'] == fixture['outsider_id']
        headers = {'Authorization':'Bearer ' + login.json()['access_token']}
        assert api.get('/classes/qa-cohort/learning-context', headers=headers).status_code == 403
        assert api.get('/classes/qa-cohort/course', headers=headers).status_code == 403
        # The same genuine identity/token remains authorized for its own cohort.
        observed = api.get(
            f"/classes/{verify.SECOND_COHORT}/students/{client['QA_STUDENT_ID']}/learning-context",
            headers=headers,
        )
        assert observed.status_code == 200
        assert observed.json()['progress']['progress_percent'] == 0
    with Session(database.engine) as session:
        assert verify.original_snapshot(session, client) == before
