from datetime import datetime, timezone
import hashlib

import pytest
from sqlalchemy import select, text, update
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from app.certificate_transport import canonical
from app.models import Classroom, ClassSession, CohortMembership, OfficialAttendanceDecision, ProgramMembership, User
from app.context_memberships import membership_id
from app.presence import official_attendance_projection
from test_certificate_requests import header, requests_api
from test_presence import presence_api, decide, close
from test_journey_traceability import enable
from test_student_followup import baseline
from test_certificate_policy_candidate import institutional, status as candidate_status, presence as candidate_presence


@pytest.fixture
def attendance_api(presence_api):
    client, engine = presence_api
    with Session(engine) as session:
        for identity in ['makeup'] + [f'm{i}' for i in range(2, 11)]:
            session.add(ClassSession(id=identity, class_id='c1', starts_at=datetime(2026,1,1,tzinfo=timezone.utc),
                ends_at=datetime(2027,1,1,tzinfo=timezone.utc), status='closed', opened_by='teacher',
                checkin_token_digest='a'*64, token_expires_at=datetime(2027,1,1,tzinfo=timezone.utc)))
        session.commit()
    yield client, engine


def official(client, *, original='s1', status='VALID', revision=0, makeup=None, actor='teacher', key=None):
    return client.post(f'/classes/c1/sessions/{original}/attendance/learner', headers=header(actor), json={
        'status':status, 'expected_revision':revision, 'makeup_session_id':makeup,
        'reason':'Conferência sintética do instrutor', 'idempotency_key':key or f'official-{original}-{revision}'})


def projection(engine, ids=None):
    with Session(engine) as session:
        return official_attendance_projection(session, class_id='c1', user_id='learner', enrollment_id='e1',
            program_id='p1', course_id='course', session_ids=ids or ['s1']+[f'm{i}' for i in range(2,11)])


def test_makeup_needs_explicit_decision_and_keeps_denominator(attendance_api):
    client, engine = attendance_api
    assert decide(client, status='absent').status_code == 200
    assert close(client, confirm=True).status_code == 200
    first = official(client, status='PENDING_MAKEUP', makeup='makeup')
    assert first.status_code == 200, first.text
    assert projection(engine)['valid_meetings'] == 0
    assert projection(engine)['configured_meetings'] == 10
    valid = official(client, revision=1, makeup='makeup')
    assert valid.status_code == 200, valid.text
    assert projection(engine)['valid_meetings'] == 1
    assert official(client, status='PENDING_MAKEUP', makeup='makeup').json() == first.json()
    assert official(client, revision=1, status='ABSENT', key='stale-official-key').status_code == 409
    assert official(client, revision=2, status='ABSENT').status_code == 200
    assert projection(engine)['valid_meetings'] == 0
    history = client.get('/classes/c1/sessions/s1/attendance/learner', headers=header('teacher')).json()
    assert history['total'] == 3
    assert [row['status'] for row in history['items']] == ['ABSENT','VALID','PENDING_MAKEUP']


def test_original_meetings_exact_70_percent_and_legacy_fallback(attendance_api):
    client, engine = attendance_api
    assert decide(client).status_code == 200
    for index in range(2,7):
        assert official(client, original=f'm{index}').status_code == 200
    assert projection(engine)['valid_meetings'] == 6
    assert not projection(engine)['attendance_70_percent']
    assert official(client, original='m7', status='JUSTIFIED_ABSENCE').status_code == 200
    assert not projection(engine)['attendance_70_percent']
    assert official(client, original='m7', revision=1).status_code == 200
    assert projection(engine)['frequency_percent'] == 70
    assert projection(engine)['attendance_70_percent']
    assert official(client, original='makeup').status_code == 200
    assert projection(engine)['valid_meetings'] == 7


def test_official_scope_replay_revocation_and_invalid_makeup(attendance_api):
    client, engine = attendance_api
    for actor in ('learner','monitor','coordinator','teacher2','outsider','admin'):
        assert official(client,actor=actor).status_code == 403
    assert official(client,makeup='s2').status_code == 404
    assert official(client,makeup='s1').status_code == 422
    assert official(client,status='PENDING_MAKEUP').status_code == 422
    assert official(client).status_code == 200
    with Session(engine) as session:
        session.get(ProgramMembership, ('teacher','p1')).status='inactive'
        session.commit()
    assert official(client).status_code == 403
    assert official(client,revision=1).status_code == 403


@pytest.mark.parametrize('revoke', ['program','cohort'])
def test_designated_global_admin_has_no_contextual_bypass(attendance_api,revoke):
    client,engine=attendance_api
    with Session(engine) as session:
        session.add(ProgramMembership(user_id='admin',program_id='p1',role='teacher',status='active'))
        session.flush()
        session.get(Classroom,'c1').teacher_id='admin'
        session.add(CohortMembership(id=membership_id('c1','admin','teacher'),class_id='c1',user_id='admin',role='teacher',status='active'))
        session.commit()
    assert official(client,actor='admin').status_code==200
    with Session(engine) as session:
        target=session.get(ProgramMembership,('admin','p1')) if revoke=='program' else session.get(CohortMembership,membership_id('c1','admin','teacher'))
        target.status='inactive'
        session.commit()
    assert official(client,actor='admin').status_code==403
    page=client.get('/classes/c1/sessions/s1/attendance/learner',headers=header('admin'))
    assert page.status_code==200 and page.json()['can_decide'] is False


@pytest.mark.parametrize('foreign_keys_enabled', [True, False])
def test_ledger_immutable_and_privacy_erasure(attendance_api, foreign_keys_enabled):
    client, engine = attendance_api
    assert official(client).status_code == 200
    for query in ("UPDATE official_attendance_decisions SET reason='Changed'", 'DELETE FROM official_attendance_decisions'):
        with pytest.raises(DBAPIError), engine.begin() as conn:
            conn.execute(text(query))
    if not foreign_keys_enabled and engine.dialect.name == 'sqlite':
        with engine.connect() as conn:
            conn.exec_driver_sql('PRAGMA foreign_keys=OFF')
    assert client.delete('/auth/me').status_code == 204
    with Session(engine) as session:
        assert session.scalar(select(OfficialAttendanceDecision)) is None


def test_journey_exports_official_frequency_only_with_configured_policy(attendance_api):
    client, engine = attendance_api
    enable(client)
    assert baseline(client,bi_record_id='DIG-0001').status_code == 200
    with Session(engine) as session:
        classroom = session.get(Classroom,'c1')
        policy = {'formal_hours':80,'course_id':'course','course_version_id':classroom.course_version_id,
                  'session_ids':['s1'], 'checkpoints':[{'id':'synthetic'}]}
        policy['policy_hash'] = hashlib.sha256(canonical(policy)).hexdigest()
        classroom.certificate_policy = policy
        session.commit()
    assert official(client,status='PENDING_MAKEUP',makeup='makeup').status_code == 200
    path='/classes/c1/journey-export'
    pending=client.get(path,headers=header('teacher')).json()['items'][0]
    assert pending['frequencia_percentual']==0 and pending['concluiu_frequencia_flag']==0
    assert official(client,revision=1,makeup='makeup').status_code == 200
    valid=client.get(path,headers=header('teacher')).json()['items'][0]
    assert valid['frequencia_percentual']==100 and valid['concluiu_frequencia_flag']==1
    assert valid['certificado_flag'] is None


def test_certificate_uses_same_explicit_correction_projection(institutional):
    client,engine,_,_,_=institutional
    candidate_presence(institutional,7)
    assert candidate_status(institutional).json()['attendance_70_percent'] is True
    assert official(client,original='meeting-0',status='ABSENT').status_code==200
    projected=candidate_status(institutional).json()
    assert projected['confirmed_presence']==6
    assert projected['attendance_70_percent'] is False
    assert projected['capacitado'] is False


@pytest.mark.parametrize('foreign_keys_enabled',[True,False])
def test_departed_instructor_anonymized_by_real_erasure_endpoint(attendance_api,foreign_keys_enabled):
    client,engine=attendance_api
    assert official(client).status_code==200
    # Synthetic assisted reassignment before self-erasure becomes allowed.
    with Session(engine) as session:
        session.execute(update(Classroom).where(Classroom.teacher_id=='teacher').values(teacher_id='teacher2'))
        session.execute(update(ClassSession).where(ClassSession.opened_by=='teacher').values(opened_by='teacher2'))
        session.get(ProgramMembership,('teacher','p1')).status='inactive'
        session.commit()
    if not foreign_keys_enabled and engine.dialect.name=='sqlite':
        with engine.connect() as conn: conn.exec_driver_sql('PRAGMA foreign_keys=OFF')
    result=client.delete('/auth/me',headers=header('teacher'))
    assert result.status_code==204,result.text
    with Session(engine) as session:
        record=session.scalar(select(OfficialAttendanceDecision))
        assert record.actor_user_id is None and record.status=='VALID'
