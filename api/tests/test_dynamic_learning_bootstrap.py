from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from uuid import uuid4

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import event, func, select
from sqlalchemy.orm import Session

from app.main import create_app
from app.models import ClassEnrollment, Classroom, CourseVersionTransition, Enrollment, LearningEventRecord
from ops import bootstrap_dynamic_learning_qa as host
from ops import prepare_dynamic_learning_qa as fixture
from ops.seed_context_android import SeedSafetyError
from test_dynamic_learning_qa import dynamic_database, inputs, seeded_database


class LocalHttp:
    def __init__(self, client):
        self.client, self.requests, self.sent = client, [], []

    def request(self, method, path, *, token=None, body=None, expected=200):
        response = self.client.request(method, path, json=body,
            headers={} if token is None else {'Authorization': 'Bearer ' + token})
        self.requests.append({'method': method, 'path': path, 'status': response.status_code})
        self.sent.append((method, path, body))
        host.require(response.status_code == expected, f'Unexpected local HTTP status {response.status_code}')
        return response.json()


@pytest.fixture
def bootstrap_data(dynamic_database):
    database, settings, wave1_client, approval = dynamic_database
    with Session(database.engine) as session, session.begin():
        defines, _ = fixture.ensure_fixture(session, settings, wave1_client, approval)
    runtime, _ = inputs()
    with TestClient(create_app(settings=settings)) as client:
        yield database, settings, wave1_client, approval, defines, runtime, LocalHttp(client)


def publish_via_editor(http, defines, previous=None):
    """Exercise the existing editorial API with its real author/reviewer credentials."""
    tokens = {}
    for persona in ('AUTHOR', 'PUBLISHER'):
        tokens[persona] = http.request('POST', '/auth/login', body={
            'cpf': defines[f'QA_DYNAMIC_{persona}_CPF'],
            'password': defines[f'QA_DYNAMIC_{persona}_PASSWORD']})['access_token']
    if previous is None:
        draft = http.request('POST', '/courses', token=tokens['AUTHOR'], expected=201,
            body={'course_id': host.COURSE_ID, 'program_id': host.PROGRAM_ID, 'title': 'Curso QA dinâmico', 'author': 'QA'})
    else:
        draft = http.request('POST', f'/courses/{host.COURSE_ID}/versions', token=tokens['AUTHOR'], expected=201,
            body={'source_version_id': previous['version_id']})
    saved = http.request('PATCH', f'/courses/{host.COURSE_ID}', token=tokens['AUTHOR'], body={
        'version_id': draft['version_id'], 'expected_revision': draft['revision'], 'title': 'Curso QA dinâmico',
        'author': 'QA', 'sections': [{'id': 'module', 'title': 'Módulo QA', 'messages': [
            {'id': 'intro', 'type': 'bot', 'content': f"Conteúdo da edição {draft['version_number']}"}]}]})
    reviewed = http.request('POST', f'/courses/{host.COURSE_ID}/submit', token=tokens['AUTHOR'], body={
        'version_id': saved['version_id'], 'expected_revision': saved['revision']})
    return http.request('POST', f'/courses/{host.COURSE_ID}/publish', token=tokens['PUBLISHER'], body={
        'version_id': reviewed['version_id'], 'expected_revision': reviewed['revision']})


def run_phase(data, phase, state=None):
    database, _, _, _, defines, _, http = data
    flow = host.Bootstrap(defines, host.ReadOnlyInspector(database.engine, defines), http)
    result, evidence = flow.run(phase, state)
    if state is not None:
        for key in ('run_id', 'baseline_sha256', 'baseline_event_count'):
            if key in state:
                result[key] = state[key]
    return result, evidence


def record_study(http, defines, state, identity, occurred_at):
    token = http.request('POST', '/auth/login', body={'cpf': defines['QA_DYNAMIC_LEARNER_CPF'],
        'password': defines['QA_DYNAMIC_LEARNER_PASSWORD']})['access_token']
    return http.request('POST', '/events', token=token, expected=201, body={
        'event_id': identity, 'event_type': 'study_activity', 'course_id': host.COURSE_ID,
        'session_id': identity, 'occurred_at': occurred_at.isoformat(), 'active_seconds': 3,
        'payload': {'class_id': state['v1']['class_id'], 'course_version_id': state['v1']['version_id']}})


def test_real_api_bootstraps_preserve_history_and_same_legacy_enrollment_across_editions(bootstrap_data):
    database, _, wave1_client, approval, defines, runtime, http = bootstrap_data
    before, captured, baseline = host.before_android(database.engine, defines, runtime, wave1_client,
        approval, http, 'unit-run')
    assert captured['status'] == 'baseline_captured' and captured['baseline_event_count'] == 74
    first = publish_via_editor(http, defines)
    state, first_evidence = run_phase(bootstrap_data, 'after_v1', before)
    assert state['v1']['version_id'] == first['version_id']
    assert state['v1']['progress']['progress_percent'] == 0
    assert state['v1']['progress']['planned_hours'] == round(120 / 3600, 4)
    assert first_evidence['before'] == first_evidence['after']
    records_before = len(http.sent)
    repeated, _ = run_phase(bootstrap_data, 'after_v1', state)
    assert repeated['v1'] == state['v1']
    assert all(not path.startswith('/admin/') for _, path, _ in http.sent[records_before:])
    record_study(http, defines, state, 'first-edition-online', datetime.now(timezone.utc) - timedelta(minutes=2))
    second = publish_via_editor(http, defines, first)
    next_state, second_evidence = run_phase(bootstrap_data, 'after_v2', state)
    assert next_state['v2']['version_id'] == second['version_id']
    assert next_state['v1']['content_sha256'] == state['v1']['content_sha256']
    assert next_state['v1']['progress']['progress_percent'] == 2.5
    assert next_state['v2']['progress']['progress_percent'] == 0
    assert next_state['v1']['context']['legacy_enrollment_id'] == next_state['v2']['context']['legacy_enrollment_id']
    assert next_state['v1']['context']['enrollment_id'] != next_state['v2']['context']['enrollment_id']
    assert second_evidence['before'] == second_evidence['after']
    record_study(http, defines, next_state, 'first-edition-offline-replay', datetime.now(timezone.utc) - timedelta(minutes=1))
    final, evidence = host.after_android(database.engine, defines, runtime, wave1_client, approval, http,
        next_state, baseline)
    assert evidence['status'] == 'history_preservation_passed'
    assert evidence['initial_events_preserved'] == 74 and evidence['current_event_count'] == 76
    assert final['v1']['progress']['progress_percent'] == 5
    assert final['v2']['progress']['progress_percent'] == 0
    assert evidence['editorial_ledger']['transition_count'] == 7
    with Session(database.engine) as session:
        assert session.scalar(select(func.count()).select_from(Enrollment).where(Enrollment.course_id == host.COURSE_ID)) == 1
        assert session.scalar(select(func.count()).select_from(ClassEnrollment).where(ClassEnrollment.course_id == host.COURSE_ID)) == 2
    serialized = json.dumps(evidence)
    for persona in fixture.PERSONAS:
        assert defines[f'QA_DYNAMIC_{persona}_PASSWORD'] not in serialized
        assert defines[f'QA_DYNAMIC_{persona}_CPF'] not in serialized
    with Session(database.engine) as session, session.begin():
        session.add(CourseVersionTransition(id=str(uuid4()), version_id=first['version_id'],
            from_status=None, to_status='published', actor_user_id=defines['QA_DYNAMIC_OPERATOR_ID'], actor_role='admin'))
    with Session(database.engine) as session, pytest.raises(SeedSafetyError, match='ledger'):
        host.verify_editorial_ledger(session, final, defines)


def test_missing_course_cannot_create_administrative_data(bootstrap_data):
    with pytest.raises(SeedSafetyError, match='publish'):
        run_phase(bootstrap_data, 'after_v1')
    assert not any(path.startswith('/admin/') for _, path, _ in bootstrap_data[-1].sent)


def test_unbound_study_blocks_legacy_enrollment_backfill_before_any_command(bootstrap_data):
    database, _, _, _, defines, _, http = bootstrap_data
    publish_via_editor(http, defines)
    with Session(database.engine) as session, session.begin():
        session.add(LearningEventRecord(event_id='unbound-study', user_id=defines['QA_DYNAMIC_LEARNER_ID'],
            course_id=host.COURSE_ID, event_type='study_activity', session_id='unbound',
            occurred_at=datetime.now(timezone.utc), active_seconds=3, validated_seconds=3, payload={}))
    with pytest.raises(SeedSafetyError, match='Workload|Unbound'):
        run_phase(bootstrap_data, 'after_v1')
    assert not any(path.startswith('/admin/') for _, path, _ in http.sent)
    with Session(database.engine) as session:
        assert session.get(LearningEventRecord, 'unbound-study').enrollment_id is None


def test_retry_recovers_partial_http_success_without_duplicate_class_or_enrollment(bootstrap_data, monkeypatch):
    database, _, _, _, defines, _, http = bootstrap_data
    publish_via_editor(http, defines)
    request = http.request
    def interrupted(method, path, **kwargs):
        if method == 'POST' and '/students/' in path:
            raise SeedSafetyError('Simulated interruption before learner inclusion')
        return request(method, path, **kwargs)
    monkeypatch.setattr(http, 'request', interrupted)
    with pytest.raises(SeedSafetyError, match='interruption'):
        run_phase(bootstrap_data, 'after_v1')
    monkeypatch.setattr(http, 'request', request)
    state, _ = run_phase(bootstrap_data, 'after_v1')
    with Session(database.engine) as session:
        assert session.scalar(select(func.count()).select_from(Classroom).where(Classroom.course_id == host.COURSE_ID)) == 1
        assert session.scalar(select(func.count()).select_from(Enrollment).where(Enrollment.course_id == host.COURSE_ID)) == 1
    assert state['v1']['context']['legacy_enrollment_id']


def test_revoked_membership_is_not_reactivated_on_retry(bootstrap_data):
    database, _, _, _, defines, _, http = bootstrap_data
    publish_via_editor(http, defines)
    state, _ = run_phase(bootstrap_data, 'after_v1')
    with Session(database.engine) as session, session.begin():
        session.get(ClassEnrollment, (state['v1']['class_id'], defines['QA_DYNAMIC_LEARNER_ID'])).status = 'inactive'
    sent = len(http.sent)
    with pytest.raises(SeedSafetyError, match='revoked'):
        run_phase(bootstrap_data, 'after_v1', state)
    assert not any(path.startswith('/admin/') for _, path, _ in http.sent[sent:])


def test_duplicate_class_names_are_rejected_instead_of_guessed(bootstrap_data):
    database, _, _, _, defines, _, http = bootstrap_data
    publish_via_editor(http, defines)
    state, _ = run_phase(bootstrap_data, 'after_v1')
    with Session(database.engine) as session, session.begin():
        existing = session.get(Classroom, state['v1']['class_id'])
        row = host.isolation.record_values(existing)
        row['id'] = str(uuid4())
        session.add(Classroom(**row))
    with pytest.raises(SeedSafetyError, match='Duplicate'):
        run_phase(bootstrap_data, 'after_v1', state)


def test_initial_core_or_event_changes_fail_history_subset_check(bootstrap_data):
    database = bootstrap_data[0]
    with Session(database.engine) as session:
        initial = host.capture_history(session)
    changed = deepcopy(initial)
    changed['events'].pop(next(iter(changed['events'])))
    with pytest.raises(SeedSafetyError, match='learning event'):
        host.require_preserved_history(initial, changed)
    changed = deepcopy(initial)
    changed['core']['users'][next(iter(changed['core']['users']))] = 'different'
    with pytest.raises(SeedSafetyError, match='core record'):
        host.require_preserved_history(initial, changed)


def test_readonly_inspector_issues_no_database_mutation_statements(bootstrap_data):
    database, _, _, _, defines, _, http = bootstrap_data
    publish_via_editor(http, defines)
    statements = []
    def collect(connection, cursor, statement, parameters, context, executemany):
        statements.append(statement.lstrip().split()[0].upper())
    event.listen(database.engine, 'before_cursor_execute', collect)
    try:
        host.ReadOnlyInspector(database.engine, defines).snapshot()
    finally:
        event.remove(database.engine, 'before_cursor_execute', collect)
    assert statements and not {'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'ALTER', 'DROP'}.intersection(statements)


def test_host_allowlist_cannot_publish_or_target_foreign_class(bootstrap_data):
    database, _, _, _, defines, _, http = bootstrap_data
    flow = host.Bootstrap(defines, host.ReadOnlyInspector(database.engine, defines), http)
    for method, path, body in [('POST', f'/courses/{host.COURSE_ID}/publish', {}),
            ('POST', f'/admin/classes/{uuid4()}/students/{defines["QA_DYNAMIC_LEARNER_ID"]}', None),
            ('POST', '/admin/enrollments', {'program_id': 'qa-program', 'course_id': 'qa-course'})]:
        with pytest.raises(SeedSafetyError):
            flow.command(method, path, body)
    assert not http.sent


@pytest.mark.parametrize('key,value', [('TUTOR_API_URL', 'https://production.test'),
    ('QA_DYNAMIC_PROGRAM_ID', 'qa-program'), ('QA_DYNAMIC_OPERATOR_ID', 'not-a-uuid'),
    ('QA_DYNAMIC_LEARNER_CPF', '12345678909'), ('QA_DYNAMIC_AUTHOR_PASSWORD', 'other-password')])
def test_host_target_and_persona_guards_reject_mismatch(bootstrap_data, key, value):
    *_, defines, runtime, _ = bootstrap_data
    changed = {**defines, key: value}
    with pytest.raises(SeedSafetyError):
        host.validate_defines(changed, runtime)


def test_default_cli_plan_uses_no_remote_service(bootstrap_data, tmp_path, monkeypatch, capsys):
    *_, defines, runtime, _ = bootstrap_data
    private = tmp_path / 'operational.json'
    config = tmp_path / 'runtime.json'
    private.write_text(json.dumps(defines), encoding='utf-8')
    config.write_text(json.dumps(runtime), encoding='utf-8')
    def no_remote(*args, **kwargs):
        pytest.fail('Plan must not connect to remote services')
    monkeypatch.setattr(host, 'Database', no_remote)
    monkeypatch.setattr(host, 'HostHttp', no_remote)
    host.main(['--phase', 'before_android', '--defines', str(private), '--runtime-json', str(config),
        '--output-state', str(host.ROOT / 'tmp/unit-bootstrap-plan.json'),
        '--output-evidence', str(host.ROOT / 'docs/production/evidence/unit-bootstrap-plan.json')])
    output = capsys.readouterr().out
    result = json.loads(output)
    assert result['remote_access'] is False and result['phase'] == 'before_android'
    assert result['run_id'] == 'unit-bootstrap-plan'
    assert 'confirm course absent in database and public catalog' in result['commands']
    assert defines['QA_DYNAMIC_OPERATOR_PASSWORD'] not in output
