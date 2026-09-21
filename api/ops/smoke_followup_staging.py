"""Staging-only synthetic baseline/mentorship roundtrip; never reads baseline source."""
import json
from pathlib import Path
from smoke_course_editor_staging import call

CLASS = "8d7e5869-cdd6-4ebe-a94e-2de91c0e7399"
USER = "staging-qa-student"


def run():
    env = {}
    for line in Path('/opt/tutor-tds-staging/.staging-seed.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            env[key.strip()] = value.strip().strip('\"\'')
    tokens = {}
    for role in ('student', 'teacher'):
        prefix = 'STAGING_SEED_' + role.upper()
        tokens[role] = call('POST', '/auth/login', {'cpf': env[prefix + '_CPF'], 'password': env[prefix + '_PASSWORD']})['access_token']
        assert call('GET', '/auth/me', token=tokens[role])['id'] == 'staging-qa-' + role
    teacher, student = tokens['teacher'], tokens['student']
    assert call('GET', f'/classes/{CLASS}', token=teacher)['course_id'] == 'staging-editor-course-qa-20260921-a'
    base = f'/classes/{CLASS}/students/{USER}/baseline'
    link = {'source': 'staging-synthetic', 'record_id': 'qa-tablet-followup-20260921', 'baseline_date': '2026-09-21', 'territory_id': 'qa-territory', 'expected_revision': 0, 'reason': 'Teste sintético: não referencia formulário real.', 'idempotency_key': 'qa-baseline-20260921'}
    call('GET', base, token=student, expected=(403,))
    call('PUT', base, link, student, (403,))
    saved = call('PUT', base, link, teacher)
    assert saved['revision'] == 1 and saved['record_id'] == link['record_id']
    assert call('PUT', base, link, teacher) == saved
    readback = call('GET', base, token=teacher)
    assert len(readback['history']) == 1 and readback['baseline']['id'] == saved['id']
    cases = f'/classes/{CLASS}/mentorship-cases'
    body = {'user_id': USER, 'mentor_id': 'staging-qa-teacher', 'objective': 'QA sintético de acompanhamento', 'next_action': 'Conferir persistência do caso sintético', 'reason': 'Teste técnico, não atendimento real.', 'idempotency_key': 'qa-mentorship-20260921'}
    call('POST', cases, body, student, (403,))
    created = call('POST', cases, body, teacher, (200, 201))
    identity = created['id']
    assert call('POST', cases, body, teacher)['id'] == identity
    detail = cases + '/' + identity
    update = {'expected_revision': 1, 'status': 'in_progress', 'next_action': 'Revisar resultado do teste sintético', 'reason': 'Avanço sintético verificado pela equipe QA.', 'idempotency_key': 'qa-mentorship-update-20260921'}
    updated = call('PATCH', detail, update, teacher)
    assert updated['revision'] == 2 and updated['status'] == 'in_progress'
    assert call('PATCH', detail, update, teacher) == updated
    call('PATCH', detail, dict(update, idempotency_key='qa-mentorship-stale-20260921'), teacher, (409,))
    history = call('GET', detail, token=teacher)['history']
    assert [row['revision'] for row in history] == [1, 2]
    call('GET', detail, token=student, expected=(403,))
    page = call('GET', cases + '?user_id=' + USER, token=teacher)
    assert any(row['id'] == identity and row['revision'] == 2 for row in page['items'])
    mentors = call('GET', f'/classes/{CLASS}/students/{USER}/mentors', token=teacher)['mentors']
    assert any(row['user_id'] == 'staging-qa-teacher' for row in mentors)
    assert all(set(row) == {'user_id', 'name'} for row in mentors)
    call('GET', f'/classes/{CLASS}/students/{USER}/mentors', token=student, expected=(403,))
    dashboard = call('GET', f'/classes/{CLASS}/dashboard', token=teacher)
    learner = next(row for row in dashboard['students'] if row['user_id'] == USER)
    assert learner['baseline_linked'] is True
    assert learner['confirmed_sessions'] == 1
    assert learner['open_mentorship_cases'] == 1
    assert dashboard['summary']['baseline_linked_students'] == 1
    assert dashboard['summary']['confirmed_participations'] == 1
    assert dashboard['summary']['open_mentorship_cases'] == 1
    assert 'record_id' not in json.dumps(dashboard) and 'next_action' not in json.dumps(dashboard)
    print(json.dumps({'baseline_id': saved['id'], 'case_id': identity, 'baseline_revision': 1, 'case_revision': 2, 'authenticated_roundtrip': 'pass', 'source_accessed': False}))


if __name__ == '__main__':
    run()
