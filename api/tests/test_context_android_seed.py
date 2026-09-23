from __future__ import annotations

import importlib.util
from pathlib import Path

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.config import Settings
from app.database import Database
from app.models import ClassEnrollment, Classroom, CohortMembership, Course, CourseVersion, LearningEventRecord, User


MODULE_PATH = Path(__file__).resolve().parents[1] / 'ops' / 'seed_context_android.py'
SPEC = importlib.util.spec_from_file_location('seed_context_android', MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
seed_tool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(seed_tool)

PROJECT = 'lgtphbbpgqnzduhtyate'
OTHER_PROJECT = 'crxdnwqhogikjbyflwiq'
DIRECT = f'postgresql://postgres:synthetic-secret@db.{PROJECT}.supabase.co:5432/postgres'
POOLER = f'postgresql://postgres.{PROJECT}:synthetic-secret@aws-0-sa-east-1.pooler.supabase.com:5432/postgres'


@pytest.mark.parametrize('base', [DIRECT, POOLER, DIRECT.replace('postgresql://', 'postgres://')])
@pytest.mark.parametrize('tls', ['require', 'verify-ca', 'verify-full'])
def test_exact_approved_supabase_target(base, tls):
    assert seed_tool.validate_target(base + f'?sslmode={tls}', environment='staging',
        approved_supabase_project=PROJECT) == 'supabase'


@pytest.mark.parametrize('url', [
    DIRECT,
    DIRECT + '?sslmode=disable',
    DIRECT + '?sslmode=prefer',
    DIRECT + '?sslmode=require&sslmode=disable',
    DIRECT.replace(PROJECT, OTHER_PROJECT) + '?sslmode=require',
    DIRECT.replace('/postgres', '/tutor_tds') + '?sslmode=require',
    DIRECT.replace('.supabase.co:', '.supabase.co.attacker.test:') + '?sslmode=require',
    POOLER.replace(PROJECT, OTHER_PROJECT) + '?sslmode=require',
    POOLER.replace(f'postgres.{PROJECT}', 'postgres') + '?sslmode=require',
    POOLER.replace('.supabase.com:', '.supabase.com.attacker.test:') + '?sslmode=require',
    'sqlite+pysqlite:///:memory:',
    'not-a-database-url',
])
def test_wrong_target_or_missing_tls_is_rejected_without_secret_output(url):
    with pytest.raises(seed_tool.SeedSafetyError) as caught:
        seed_tool.validate_target(url, environment='staging', approved_supabase_project=PROJECT)
    assert 'synthetic-secret' not in str(caught.value)
    assert url not in str(caught.value)


@pytest.mark.parametrize('override', ['host', 'hostaddr', 'port', 'user', 'password', 'dbname', 'database', 'service', 'servicefile'])
def test_query_cannot_override_approved_target(override):
    with pytest.raises(seed_tool.SeedSafetyError, match='overrides'):
        seed_tool.validate_target(DIRECT + f'?sslmode=require&{override}=elsewhere',
            environment='staging', approved_supabase_project=PROJECT)


@pytest.mark.parametrize('environment', [None, '', 'production', 'local'])
def test_supabase_requires_explicit_staging_environment(environment):
    with pytest.raises(seed_tool.SeedSafetyError, match='TUTOR_ENVIRONMENT'):
        seed_tool.validate_target(DIRECT + '?sslmode=require', environment=environment,
            approved_supabase_project=PROJECT)


@pytest.mark.parametrize('approval', [None, '', OTHER_PROJECT])
def test_supabase_requires_exact_explicit_approval(approval):
    with pytest.raises(seed_tool.SeedSafetyError):
        seed_tool.validate_target(DIRECT + '?sslmode=require', environment='staging',
            approved_supabase_project=approval)


def test_existing_private_vps_database_guard_is_preserved():
    assert seed_tool.validate_target(
        'postgresql+psycopg://qa:synthetic@tds-context-qa-db:5432/tds_context_staging_qa'
    ) == 'vps'
    with pytest.raises(seed_tool.SeedSafetyError):
        seed_tool.validate_target('postgresql+psycopg://qa:synthetic@db:5432/tutor_tds')


@pytest.mark.parametrize('revision', [None, '20260920_0001'])
def test_preflight_rejects_missing_or_old_schema(revision):
    database = Database('sqlite+pysqlite:///:memory:')
    try:
        with Session(database.engine) as session:
            if revision:
                session.execute(text('CREATE TABLE alembic_version (version_num VARCHAR(32) PRIMARY KEY)'))
                session.execute(text('INSERT INTO alembic_version VALUES (:revision)'), {'revision':revision})
            with pytest.raises(seed_tool.SeedSafetyError, match='schema head'):
                seed_tool.validate_empty_head(session)
    finally:
        database.dispose()


def test_migrated_empty_database_is_seeded_once_with_existing_context_contract(tmp_path, monkeypatch):
    monkeypatch.delenv('DATABASE_URL', raising=False)
    url = f"sqlite+pysqlite:///{(tmp_path / 'seed.db').as_posix()}"
    migration = Config('alembic.ini')
    migration.set_main_option('sqlalchemy.url', url)
    command.upgrade(migration, 'head')
    settings = Settings(database_url=url, allowed_origins=(), jwt_secret='test-' * 8,
        cpf_pepper='test-pepper-' * 4, learning_context_enabled=True)
    database = Database(url)
    try:
        with Session(database.engine) as session, session.begin():
            assert seed_tool.validate_empty_head(session)
            assert session.scalar(select(func.count()).select_from(User)) == 0
            result = seed_tool.seed_context(session, settings,
                student_password='synthetic-student-password', teacher_password='synthetic-teacher-password')
        with Session(database.engine) as session:
            assert session.scalar(select(func.count()).select_from(User)) == 2
            assert session.scalar(select(func.count()).select_from(CohortMembership)) == 2
            assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 0
            assert session.get(User, result['teacher_id']).role == 'student'
            assert session.get(Classroom, 'qa-cohort').course_version_id == 'qa-edition-1'
            assert session.get(CourseVersion, 'qa-edition-1').status == 'archived'
            assert session.get(CourseVersion, 'qa-edition-2').status == 'published'
            assert session.get(Course, 'qa-course').title == 'Catálogo QA — edição 2'
            enrollment = session.scalar(select(ClassEnrollment))
            assert enrollment.context_id and enrollment.membership_id
            assert enrollment.course_version_id == 'qa-edition-1'
            with pytest.raises(seed_tool.SeedSafetyError, match='empty QA database'):
                seed_tool.validate_empty_head(session)
    finally:
        database.dispose()
