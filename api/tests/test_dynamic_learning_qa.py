from __future__ import annotations

from dataclasses import replace
from datetime import datetime, timezone
import hashlib
import json

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.auth import AuthService
from app.events import _serialize
from app.main import create_app
from app.models import (ClassEnrollment, Classroom, Course, CourseVersion, Enrollment,
    LearningEventRecord, Program, ProgramMembership, User)
from ops import prepare_dynamic_learning_qa as dynamic
from ops import verify_cloud_context_isolation as isolation
from ops.seed_context_android import SeedSafetyError
from test_cloud_context_isolation import local_inputs, seeded_database


def inputs():
    runtime, client = local_inputs()
    client['DURABLE_LEARNING_OUTBOX_ENABLED'] = 'true'
    return runtime, client


@pytest.fixture
def dynamic_database(seeded_database):
    database, settings, client = seeded_database
    client['DURABLE_LEARNING_OUTBOX_ENABLED'] = 'true'
    with Session(database.engine) as session, session.begin():
        isolation.ensure_fixture(session, settings, client)
        for index in range(73):
            session.add(LearningEventRecord(event_id=f'approved-telemetry-{index}',
                user_id=client['QA_STUDENT_ID'], enrollment_id='qa-legacy-enrollment',
                course_id='qa-course', event_type='page_viewed', session_id='approved-session',
                occurred_at=datetime.now(timezone.utc), payload={'page_id': 'home'}))
    with Session(database.engine) as session:
        snapshot = isolation.original_snapshot(session, client)
        context = isolation.resolve_student_context(session, 'qa-cohort', client['QA_STUDENT_ID'])
        events = [_serialize(row).model_dump(mode='json') for row in session.scalars(select(LearningEventRecord))]
        approval = {'original_context_sha256': snapshot['original_context_sha256'],
            'minimum_event_count': snapshot['all_events_count'], 'context': context.context.model_dump(mode='json'),
            'progress': context.progress.model_dump(mode='json'),
            'events': {item['event_id']: item for item in events}, 'evidence_sha256': {}, 'gate_sha256': 'a' * 64}
    return database, settings, client, approval


def proof_files(tmp_path, approval):
    isolation_proof = {'status': 'passed', 'api_base': isolation.API_BASE,
        'project_sha256': hashlib.sha256(isolation.APPROVED_SUPABASE_PROJECT.encode()).hexdigest(),
        'original_unchanged': {'original_context_sha256': approval['original_context_sha256'],
            'all_events_count': approval['minimum_event_count']}, 'original_progress': approval['progress']}
    android = {'status': 'ANDROID_PATHS_PASSED', 'all_phases_in_this_run': True, 'separate_processes': True,
        'phases': [{'phase': name} for name in ['student_online', 'student_restart', 'student_offline',
            'offline_restart', 'student_reconnect', 'instructor_observation']]}
    android['phases'][0]['events'] = list(approval['events'].values())
    android['phases'][-1]['context'] = approval['context']
    gate = {'status': 'WAVE1_FUNCTIONAL_STAGING_PASSED', 'wave': 1, 'next_wave_allowed': 2,
        'api_url': isolation.API_BASE, 'checks': {key: 'passed' for key in ('student_learning_path',
            'instructor_observation_path', 'offline_sync_path', 'contextual_authorization_and_isolation_https')},
        'evidence_sha256': {}}
    paths = [tmp_path / name for name in ('gate.json', 'isolation.json', 'android.json')]
    for key, path, value in [(dynamic.ISOLATION_EVIDENCE, paths[1], isolation_proof),
            (dynamic.ANDROID_EVIDENCE, paths[2], android)]:
        path.write_text(json.dumps(value), encoding='utf-8')
        gate['evidence_sha256'][key] = hashlib.sha256(path.read_bytes()).hexdigest()
    paths[0].write_text(json.dumps(gate), encoding='utf-8')
    return paths


def test_only_approved_target_and_flags_are_accepted():
    runtime, client = inputs()
    settings = dynamic.validate_inputs(runtime, client)
    passwords = {dynamic.persona_password(settings, persona) for persona in dynamic.PERSONAS}
    assert len(passwords) == 4 and all(len(password) == 64 for password in passwords)
    assert dynamic.persona_password(settings, 'AUTHOR') == dynamic.persona_password(settings, 'AUTHOR')


@pytest.mark.parametrize('container,key,value', [
    ('runtime', 'DATABASE_URL', 'postgresql://postgres:synthetic@db.crxdnwqhogikjbyflwiq.supabase.co/postgres?sslmode=require'),
    ('runtime', 'DATABASE_URL', f'postgresql://postgres:synthetic@db.{isolation.APPROVED_SUPABASE_PROJECT}.supabase.co/postgres'),
    ('runtime', 'TUTOR_ENVIRONMENT', 'production'),
    ('runtime', 'LEARNING_CONTEXT_ENABLED', 'false'),
    ('client', 'LEARNING_CONTEXT_ENABLED', 'false'),
    ('client', 'DURABLE_LEARNING_OUTBOX_ENABLED', 'false'),
    ('client', 'TUTOR_API_URL', 'https://tutor-tds.fastapicloud.dev'),
])
def test_target_and_flag_mismatches_are_rejected(container, key, value):
    runtime, client = inputs()
    (runtime if container == 'runtime' else client)[key] = value
    with pytest.raises(SeedSafetyError):
        dynamic.validate_inputs(runtime, client)


def test_approval_requires_successful_gate_and_exact_evidence_hashes(dynamic_database, tmp_path):
    *_, approval = dynamic_database
    paths = proof_files(tmp_path, approval)
    loaded = dynamic.load_approval(*paths)
    assert len(loaded['events']) == 74
    assert loaded['context'] == approval['context']
    paths[1].write_text(paths[1].read_text() + ' ', encoding='utf-8')
    with pytest.raises(SeedSafetyError, match='hash'):
        dynamic.load_approval(*paths)


def test_unapproved_wave_does_not_unlock_fixture(dynamic_database, tmp_path):
    *_, approval = dynamic_database
    paths = proof_files(tmp_path, approval)
    gate = json.loads(paths[0].read_text())
    gate['checks']['offline_sync_path'] = 'pending'
    paths[0].write_text(json.dumps(gate), encoding='utf-8')
    with pytest.raises(SeedSafetyError, match='incomplete'):
        dynamic.load_approval(*paths)


def test_fixture_is_additive_idempotent_and_does_not_create_course_or_learning_data(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session:
        before = isolation.original_snapshot(session, client)
    with Session(database.engine) as session, session.begin():
        first, evidence = dynamic.ensure_fixture(session, settings, client, approval)
    assert evidence['created'] is True and evidence['course_absent'] is True
    with Session(database.engine) as session, session.begin():
        second, repeated = dynamic.ensure_fixture(session, settings, client, approval)
        assert second == first and repeated['created'] is False
        assert isolation.original_snapshot(session, client) == before
        assert session.scalar(select(func.count()).select_from(User)) == 7
        assert session.scalar(select(func.count()).select_from(Program)) == 2
        for model, count in [(Course, 1), (CourseVersion, 2), (Enrollment, 1),
                (Classroom, 2), (ClassEnrollment, 2), (LearningEventRecord, 74)]:
            assert session.scalar(select(func.count()).select_from(model)) == count
        assert session.get(Course, dynamic.COURSE_ID) is None
    safe_output = json.dumps(evidence)
    for persona, data in dynamic.PERSONAS.items():
        assert data[0] not in safe_output
        assert first[f'QA_DYNAMIC_{persona}_PASSWORD'] not in safe_output


def test_all_personas_authenticate_with_real_jwt_and_scoped_editor_permissions(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        defines, _ = dynamic.ensure_fixture(session, settings, client, approval)
    with TestClient(create_app(settings=settings)) as api:
        for persona, (cpf, _, role, membership) in dynamic.PERSONAS.items():
            response = api.post('/auth/login', json={'cpf': cpf,
                'password': defines[f'QA_DYNAMIC_{persona}_PASSWORD']})
            assert response.status_code == 200
            account = response.json()
            assert account['user']['id'] == defines[f'QA_DYNAMIC_{persona}_ID']
            assert account['user']['role'] == role
            headers = {'Authorization': 'Bearer ' + account['access_token']}
            assert api.get('/auth/me', headers=headers).json()['id'] == account['user']['id']
            if persona != 'OPERATOR':
                context = api.get('/editor/context', headers=headers).json()
                expected = [] if persona == 'LEARNER' else [{'id': dynamic.PROGRAM_ID,
                    'name': dynamic.PROGRAM_NAME, 'role': membership,
                    'can_create': True, 'can_publish': persona == 'PUBLISHER'}]
                assert context['programs'] == expected
    with Session(database.engine) as session:
        assert session.scalar(select(ProgramMembership).where(
            ProgramMembership.user_id == defines['QA_DYNAMIC_OPERATOR_ID'])) is None
        assert isolation.original_snapshot(session, client)['all_events_count'] == 74


def test_legacy_preview_telemetry_is_allowed_and_all_current_rows_are_preserved(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        session.add(LearningEventRecord(event_id='later-preview-telemetry', user_id=client['QA_STUDENT_ID'],
            course_id='qa-course', event_type='page_viewed', session_id='later-preview',
            occurred_at=datetime.now(timezone.utc), payload={'page_id': 'home'}))
    with Session(database.engine) as session, session.begin():
        before = isolation.original_snapshot(session, client)
        _, evidence = dynamic.ensure_fixture(session, settings, client, approval)
        assert evidence['original_unchanged'] == before
        assert before['all_events_count'] == 75
        assert isolation.original_snapshot(session, client) == before


def test_changed_approved_event_body_blocks_fixture(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        session.get(LearningEventRecord, 'approved-telemetry-0').payload = {'page_id': 'different'}
    with Session(database.engine) as session, session.begin():
        with pytest.raises(SeedSafetyError, match='event body'):
            dynamic.ensure_fixture(session, settings, client, approval)
        assert session.get(Program, dynamic.PROGRAM_ID) is None


def test_existing_course_is_rejected_before_identity_creation(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        session.add(Course(id=dynamic.COURSE_ID, title='Already exists', author='QA', content={}, active=False))
    with Session(database.engine) as session, session.begin():
        with pytest.raises(SeedSafetyError, match='must be absent'):
            dynamic.ensure_fixture(session, settings, client, approval)
        assert session.get(Program, dynamic.PROGRAM_ID) is None
        assert session.scalar(select(func.count()).select_from(User)) == 3


@pytest.mark.parametrize('change', ['role', 'membership', 'password'])
def test_existing_fixture_mismatch_is_rejected_without_reset(dynamic_database, change):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        defines, _ = dynamic.ensure_fixture(session, settings, client, approval)
    identity = defines['QA_DYNAMIC_PUBLISHER_ID']
    with Session(database.engine) as session, session.begin():
        if change == 'role':
            session.get(User, identity).role = 'admin'
        elif change == 'membership':
            session.get(ProgramMembership, (identity, dynamic.PROGRAM_ID)).status = 'inactive'
    candidate = replace(settings, jwt_secret='different-strong-test-secret' * 2) if change == 'password' else settings
    with Session(database.engine) as session, session.begin():
        before = isolation.record_values(session.get(User, identity))
        with pytest.raises(SeedSafetyError):
            dynamic.ensure_fixture(session, candidate, client, approval)
        assert isolation.record_values(session.get(User, identity)) == before


def test_partial_fixture_is_not_repaired(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        session.add(Program(id=dynamic.PROGRAM_ID, institution_id='qa-org', name=dynamic.PROGRAM_NAME))
    with Session(database.engine) as session, session.begin():
        with pytest.raises(SeedSafetyError, match='Partial'):
            dynamic.ensure_fixture(session, settings, client, approval)
        assert session.scalar(select(func.count()).select_from(User)) == 3


def test_failure_mid_creation_rolls_back_program_and_every_new_identity(dynamic_database, monkeypatch):
    database, settings, client, approval = dynamic_database
    register = AuthService.register
    def fail_after_author(self, payload):
        if payload.cpf.get_secret_value() == dynamic.PERSONAS['PUBLISHER'][0]:
            raise SeedSafetyError('Injected persistence failure')
        return register(self, payload)
    monkeypatch.setattr(AuthService, 'register', fail_after_author)
    with Session(database.engine) as session:
        before = isolation.original_snapshot(session, client)
    with pytest.raises(SeedSafetyError, match='Injected'), Session(database.engine) as session, session.begin():
        dynamic.ensure_fixture(session, settings, client, approval)
    with Session(database.engine) as session:
        assert session.get(Program, dynamic.PROGRAM_ID) is None
        assert session.scalar(select(func.count()).select_from(User)) == 3
        assert session.scalar(select(func.count()).select_from(ProgramMembership)) == 3
        assert isolation.original_snapshot(session, client) == before


def test_non_head_schema_is_rejected(dynamic_database):
    database, settings, client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        session.execute(text("UPDATE alembic_version SET version_num='20260921_0015'"))
    with Session(database.engine) as session, session.begin():
        with pytest.raises(SeedSafetyError, match='head'):
            dynamic.ensure_fixture(session, settings, client, approval)


def test_credentials_output_cannot_be_written_into_tracked_workspace(tmp_path):
    with pytest.raises(SeedSafetyError, match='ignored JSON'):
        dynamic.validate_output_paths(dynamic.ROOT / 'docs/dynamic-secrets.json',
            dynamic.ROOT / 'docs/production/evidence/dynamic-test.json', [])


def test_default_cli_validates_local_gate_without_remote_or_output_writes(tmp_path, monkeypatch, capsys):
    runtime, client = inputs()
    runtime_path, client_path = tmp_path / 'runtime.json', tmp_path / 'client.json'
    runtime_path.write_text(json.dumps(runtime), encoding='utf-8')
    client_path.write_text(json.dumps(client), encoding='utf-8')
    def no_remote(*args, **kwargs):
        pytest.fail('Default mode must not connect to the database')
    monkeypatch.setattr(dynamic, 'Database', no_remote)
    defines = dynamic.ROOT / 'tmp/unit-dynamic-dry-run-defines.json'
    evidence = dynamic.ROOT / 'docs/production/evidence/unit-dynamic-dry-run.json'
    dynamic.main(['--runtime-json', str(runtime_path), '--client-defines', str(client_path),
        '--output-defines', str(defines), '--output-evidence', str(evidence)])
    output = capsys.readouterr().out
    assert json.loads(output)['remote_access'] is False
    assert runtime['JWT_SECRET'] not in output and runtime['QA_STUDENT_PASSWORD'] not in output
    assert not defines.exists() and not evidence.exists()
