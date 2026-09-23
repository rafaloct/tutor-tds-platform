"""Verify cohort isolation over real staging HTTPS after the Android gate.

Without --execute, validate local inputs only. With --execute, add one synthetic
teacher and one second cohort/contextual enrollment; never reset existing data.
Run from api/ using the ignored runtime/client-defines JSON files.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import ssl
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, HTTPSHandler, Request, build_opener
from uuid import UUID

from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from fastapi import HTTPException
from sqlalchemy import inspect, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import AuthService, LoginRequest, RegisterRequest
from app.config import Settings
from app.context_memberships import bind_membership, bind_student, membership_id
from app.database import Database
from app.learning_context import resolve_student_context
from app.models import (
    ClassEnrollment, ClassMonitor, Classroom, CohortMembership, Course, CourseVersion, Enrollment,
    Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User,
)
from ops.seed_context_android import APPROVED_SUPABASE_PROJECT, SeedSafetyError, validate_target


API_BASE = 'https://tutor-tds-staging.fastapicloud.dev'
USER_AGENT = 'TutorTDS-StagingAcceptance/1.0'
SECOND_COHORT = 'qa-cohort-isolation'
OUTSIDER_NAME = 'Instrutor QA Outra Turma'
OUTSIDER_CPF = '52998224725'


def require(condition, message):
    if not condition:
        raise SeedSafetyError(message)


def validate_inputs(runtime, client):
    validate_target(runtime.get('DATABASE_URL', ''), environment=runtime.get('TUTOR_ENVIRONMENT'),
        approved_supabase_project=APPROVED_SUPABASE_PROJECT)
    require(runtime.get('PUBLIC_API_BASE_URL') == API_BASE, 'Unexpected runtime API base')
    require(client.get('TUTOR_API_URL') == client.get('TUTOR_STAGING_API_URL') == API_BASE,
        'Unexpected client API base')
    require(client.get('TUTOR_ENVIRONMENT') == 'staging', 'Client must target staging')
    require(runtime.get('LEARNING_CONTEXT_ENABLED') == client.get('LEARNING_CONTEXT_ENABLED') == 'true',
        'Context flag must be enabled')
    for persona, cpf in [('STUDENT', '12345678909'), ('TEACHER', '11144477735')]:
        require(client.get(f'QA_{persona}_CPF') == cpf, 'Unexpected synthetic identity')
        password = runtime.get(f'QA_{persona}_PASSWORD')
        require(isinstance(password, str) and 12 <= len(password) <= 128
            and password == client.get(f'QA_{persona}_PASSWORD'), 'Synthetic credentials disagree')
        try:
            UUID(client.get(f'QA_{persona}_ID', ''))
        except (ValueError, TypeError, AttributeError):
            raise SeedSafetyError('Synthetic user ID must be a UUID') from None
    require(client['QA_STUDENT_ID'] != client['QA_TEACHER_ID'], 'Synthetic identities must differ')
    for key in ['JWT_SECRET', 'CPF_PEPPER']:
        require(isinstance(runtime.get(key), str) and len(runtime[key]) >= 32, 'Missing runtime auth secret')
    return Settings(database_url=runtime['DATABASE_URL'], allowed_origins=(),
        jwt_secret=runtime['JWT_SECRET'], cpf_pepper=runtime['CPF_PEPPER'],
        public_api_base_url=API_BASE, learning_context_enabled=True)


def outsider_password(settings):
    return hmac.new(settings.jwt_secret.encode(),
        f'tds:qa-context-isolation:{APPROVED_SUPABASE_PROJECT}'.encode(), hashlib.sha256).hexdigest()


def fields(record, expected, boundary):
    require(record is not None and all(getattr(record, key) == value for key, value in expected.items()),
        f'Unexpected {boundary}; refusing fixture mutation')


def record_values(record):
    return {column.key: getattr(record, column.key) for column in inspect(type(record)).columns}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
        default=lambda item: item.isoformat()).encode()).hexdigest()


def original_snapshot(session, client):
    student_id, teacher_id = client['QA_STUDENT_ID'], client['QA_TEACHER_ID']
    original = [session.get(User, student_id), session.get(User, teacher_id),
        session.get(Classroom, 'qa-cohort'), session.get(ClassEnrollment, ('qa-cohort', student_id)),
        session.get(Enrollment, 'qa-legacy-enrollment')]
    for user_id, role in [(student_id, 'student'), (teacher_id, 'teacher')]:
        original.append(session.get(ProgramMembership, (user_id, 'qa-program')))
        original.append(session.get(CohortMembership, membership_id('qa-cohort', user_id, role)))
    require(all(record is not None for record in original), 'Original context is incomplete')
    events = [record_values(item) for item in session.scalars(
        select(LearningEventRecord).order_by(LearningEventRecord.event_id))]
    return {'original_context_sha256': digest([record_values(item) for item in original]),
        'all_events_sha256': digest(events), 'all_events_count': len(events)}


def validate_seed(session, settings, client):
    expected_head = set(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())
    require(set(MigrationContext.configure(session.connection()).get_current_heads()) == expected_head,
        'Staging schema must match local Alembic head')
    student_id, teacher_id = client['QA_STUDENT_ID'], client['QA_TEACHER_ID']
    expected_tables = [(Institution, {'qa-org'}), (Program, {'qa-program'}),
        (Course, {'qa-course'}), (CourseVersion, {'qa-edition-1', 'qa-edition-2'}),
        (Enrollment, {'qa-legacy-enrollment'})]
    for model, expected_ids in expected_tables:
        require(set(session.scalars(select(model.id))) == expected_ids, 'Unexpected seed entity IDs')
    fields(session.get(Program, 'qa-program'), {'institution_id':'qa-org'}, 'program lineage')
    fields(session.get(ProgramCourse, ('qa-program', 'qa-course')), {'planned_seconds':120}, 'course offering')
    fields(session.get(CourseVersion, 'qa-edition-1'),
        {'course_id':'qa-course', 'version_number':1, 'status':'archived'}, 'pinned edition')
    fields(session.get(CourseVersion, 'qa-edition-2'),
        {'course_id':'qa-course', 'version_number':2, 'status':'published'}, 'catalog edition')
    fields(session.get(Enrollment, 'qa-legacy-enrollment'),
        {'user_id':student_id, 'program_id':'qa-program', 'course_id':'qa-course', 'status':'active'}, 'legacy enrollment')
    fields(session.get(Classroom, 'qa-cohort'), {'teacher_id':teacher_id, 'program_id':'qa-program',
        'course_id':'qa-course', 'course_version_id':'qa-edition-1', 'status':'active'}, 'original cohort')
    service = AuthService(session, settings)
    for persona, role, name in [('STUDENT', 'student', 'Aluno QA Contexto'), ('TEACHER', 'teacher', 'Instrutor QA Contexto')]:
        user_id = client[f'QA_{persona}_ID']
        fields(session.get(User, user_id), {'name':name, 'role':'student'}, 'original identity')
        fields(session.get(ProgramMembership, (user_id, 'qa-program')), {'role':role, 'status':'active'}, 'program membership')
        fields(session.get(CohortMembership, membership_id('qa-cohort', user_id, role)),
            {'class_id':'qa-cohort', 'user_id':user_id, 'role':role, 'status':'active'}, 'original membership')
        authenticated = service.authenticate(LoginRequest(cpf=client[f'QA_{persona}_CPF'],
            password=client[f'QA_{persona}_PASSWORD']))
        require(authenticated.id == user_id, 'Runtime credentials do not match original identities')
    original = resolve_student_context(session, 'qa-cohort', student_id)
    require(original.context.organization_id == 'qa-org' and original.context.legacy_enrollment_id == 'qa-legacy-enrollment',
        'Original context lineage mismatch')
    require(original.progress.progress_percent > 0 and original.progress.validated_hours > 0,
        'Complete the Android activity gate before adding the isolation fixture')
    outsider = session.scalar(select(User).where(User.cpf_digest == service._cpf_digest(OUTSIDER_CPF)))
    allowed_users = {student_id, teacher_id} | ({outsider.id} if outsider else set())
    require(set(session.scalars(select(User.id))) == allowed_users, 'Unexpected user IDs in staging')
    allowed_classes = {'qa-cohort'} | ({SECOND_COHORT} if outsider else set())
    require(set(session.scalars(select(Classroom.id))) == allowed_classes, 'Unexpected or partial isolation fixture')
    links = {('qa-cohort', student_id)} | ({(SECOND_COHORT, student_id)} if outsider else set())
    require(set(session.execute(select(ClassEnrollment.class_id, ClassEnrollment.user_id))) == links,
        'Unexpected contextual enrollment IDs')
    expected_memberships = {membership_id('qa-cohort', student_id, 'student'), membership_id('qa-cohort', teacher_id, 'teacher')}
    expected_program_users = {student_id, teacher_id}
    if outsider:
        expected_program_users.add(outsider.id)
        fields(outsider, {'name':OUTSIDER_NAME, 'role':'student'}, 'isolation identity')
        require(service.authenticate(LoginRequest(cpf=OUTSIDER_CPF, password=outsider_password(settings))).id == outsider.id,
            'Isolation credentials disagree; no reset is allowed')
        fields(session.get(ProgramMembership, (outsider.id, 'qa-program')), {'role':'teacher', 'status':'active'}, 'isolation program membership')
        fields(session.get(Classroom, SECOND_COHORT), {'teacher_id':outsider.id, 'program_id':'qa-program',
            'course_id':'qa-course', 'course_version_id':'qa-edition-1', 'status':'active'}, 'isolation cohort')
        for user_id, role in [(student_id, 'student'), (outsider.id, 'teacher')]:
            identity = membership_id(SECOND_COHORT, user_id, role)
            expected_memberships.add(identity)
            fields(session.get(CohortMembership, identity),
                {'class_id':SECOND_COHORT, 'user_id':user_id, 'role':role, 'status':'active'}, 'isolation membership')
        second = resolve_student_context(session, SECOND_COHORT, student_id)
        require(second.progress.progress_percent == second.progress.validated_hours == 0,
            'Isolation cohort already has progress; no reset is allowed')
        require(second.context.enrollment_id != original.context.enrollment_id
            and second.context.legacy_enrollment_id == original.context.legacy_enrollment_id,
            'Isolation enrollment lineage mismatch')
    require(set(session.scalars(select(CohortMembership.id))) == expected_memberships, 'Unexpected membership IDs')
    require(set(session.execute(select(ProgramMembership.user_id, ProgramMembership.program_id)))
        == {(user_id, 'qa-program') for user_id in expected_program_users}, 'Unexpected program memberships')
    require(session.scalar(select(ClassMonitor.user_id).limit(1)) is None, 'Unexpected monitor assignments')
    return outsider


def ensure_fixture(session, settings, client):
    existing = validate_seed(session, settings, client)
    if existing:
        return {'outsider_id':existing.id, 'created':False}
    outsider = AuthService(session, settings).register(RegisterRequest(name=OUTSIDER_NAME,
        cpf=OUTSIDER_CPF, phone='61999990000', password=outsider_password(settings)))
    session.add(ProgramMembership(user_id=outsider.id, program_id='qa-program', role='teacher'))
    session.flush()
    original = session.get(Classroom, 'qa-cohort')
    cohort = Classroom(id=SECOND_COHORT, program_id='qa-program', course_id='qa-course',
        course_version_id='qa-edition-1', teacher_id=outsider.id, name='Turma QA — isolamento de contexto',
        start_date=original.start_date, end_date=original.end_date, status='active')
    session.add(cohort)
    session.flush()
    bind_membership(session, cohort.id, outsider.id, 'teacher')
    link = ClassEnrollment(class_id=cohort.id, user_id=client['QA_STUDENT_ID'],
        enrollment_id='qa-legacy-enrollment', program_id='qa-program', course_id='qa-course', status='active')
    session.add(link)
    bind_student(session, cohort, link)
    session.flush()
    return {'outsider_id':outsider.id, 'created':True}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


class StagingHttp:
    def __init__(self):
        self.opener = build_opener(HTTPSHandler(context=ssl.create_default_context()), NoRedirect())
        self.requests = []

    def request(self, path, *, token=None, body=None, expected=200):
        require(path.startswith('/') and not path.startswith('//') and '://' not in path, 'Invalid QA API path')
        headers = {'User-Agent':USER_AGENT, 'Accept':'application/json'}
        if token:
            headers['Authorization'] = f'Bearer {token}'
        data = None if body is None else json.dumps(body).encode()
        if data is not None:
            headers['Content-Type'] = 'application/json'
        request = Request(API_BASE + path, data=data, headers=headers)
        try:
            with self.opener.open(request, timeout=30) as response:
                status, raw = response.status, response.read(2_000_000)
        except HTTPError as error:
            status, raw = error.code, error.read(2_000_000)
        except (URLError, TimeoutError):
            raise SeedSafetyError('Staging HTTPS request failed; connection details omitted') from None
        self.requests.append({'method':request.get_method(), 'path':path, 'status':status})
        require(status == expected, f'Unexpected HTTPS status for {path}: {status}; expected {expected}')
        if status == 403:
            return None
        try:
            return json.loads(raw)
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise SeedSafetyError('Staging API returned invalid JSON') from None

    def login(self, cpf, password, expected_id):
        value = self.request('/auth/login', body={'cpf':cpf, 'password':password})
        require(value.get('user', {}).get('id') == expected_id, 'HTTPS login returned unexpected identity')
        require(isinstance(value.get('access_token'), str), 'HTTPS login omitted access token')
        return value['access_token']


def execute(runtime, client):
    settings = validate_inputs(runtime, client)
    database = Database(settings.database_url)
    http = StagingHttp()
    try:
        with Session(database.engine) as session:
            validate_seed(session, settings, client)
            before = original_snapshot(session, client)
            original_id = resolve_student_context(session, 'qa-cohort', client['QA_STUDENT_ID']).context.enrollment_id
        student = http.login(client['QA_STUDENT_CPF'], client['QA_STUDENT_PASSWORD'], client['QA_STUDENT_ID'])
        instructor = http.login(client['QA_TEACHER_CPF'], client['QA_TEACHER_PASSWORD'], client['QA_TEACHER_ID'])
        original_path = '/classes/qa-cohort/learning-context'
        observer_path = f"/classes/qa-cohort/students/{client['QA_STUDENT_ID']}/learning-context"
        original = http.request(original_path, token=student)
        require(original['context']['enrollment_id'] == original_id and original['progress']['progress_percent'] > 0,
            'HTTPS context disagrees with approved staging database')
        require(http.request(observer_path, token=instructor)['progress'] == original['progress'],
            'Original instructor progress disagrees before fixture')
        with Session(database.engine) as session, session.begin():
            require(original_snapshot(session, client) == before, 'Original data changed during preflight')
            fixture = ensure_fixture(session, settings, client)
            require(original_snapshot(session, client) == before, 'Fixture affected original data; rolling back')
        outsider = http.login(OUTSIDER_CPF, outsider_password(settings), fixture['outsider_id'])
        # Teaching another cohort never creates a learner enrollment here.
        http.request(original_path, token=outsider, expected=403)
        http.request('/classes/qa-cohort/course', token=outsider, expected=403)
        http.request(observer_path, token=outsider, expected=403)
        http.request('/classes/qa-cohort/dashboard', token=outsider, expected=403)
        second = http.request(f'/classes/{SECOND_COHORT}/learning-context', token=student)
        require(second['context']['enrollment_id'] != original['context']['enrollment_id']
            and second['context']['membership_id'] != original['context']['membership_id']
            and second['context']['course_version_id'] == original['context']['course_version_id']
            and second['context']['legacy_enrollment_id'] == original['context']['legacy_enrollment_id'],
            'Second contextual enrollment is not independent')
        require(second['progress']['progress_percent'] == second['progress']['validated_hours'] == 0,
            'Original progress leaked into second cohort')
        observed_second = http.request(
            f"/classes/{SECOND_COHORT}/students/{client['QA_STUDENT_ID']}/learning-context", token=outsider)
        require(observed_second['context'] == second['context'] and observed_second['progress'] == second['progress'],
            'Second instructor must see precisely the second cohort')
        after_http = http.request(original_path, token=student)
        observed_original = http.request(observer_path, token=instructor)
        require(after_http['context'] == original['context'] and after_http['progress'] == original['progress'],
            'Original context/progress changed during isolation verification')
        require(observed_original['context'] == original['context'] and observed_original['progress'] == original['progress'],
            'Original instructor no longer sees exact student progress')
        with Session(database.engine) as session:
            validate_seed(session, settings, client)
            require(original_snapshot(session, client) == before, 'Original persisted data changed')
        return {'verified_at':datetime.now(timezone.utc).isoformat(), 'status':'passed',
            'scope':'real HTTPS cohort authorization and contextual progress isolation',
            'api_base':API_BASE, 'project_sha256':hashlib.sha256(APPROVED_SUPABASE_PROJECT.encode()).hexdigest(),
            'user_agent':USER_AGENT, 'fixture':{'cohort_id':SECOND_COHORT, 'created':fixture['created']},
            'original_progress':original['progress'], 'second_progress':second['progress'],
            'original_unchanged':before, 'requests':http.requests,
            'limitations':['Synthetic isolated staging only', 'Does not replace Android acceptance or release validation']}
    finally:
        database.dispose()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-json', type=Path, required=True)
    parser.add_argument('--client-defines', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        runtime = json.loads(args.runtime_json.read_text(encoding='utf-8-sig'))
        client = json.loads(args.client_defines.read_text(encoding='utf-8-sig'))
        validate_inputs(runtime, client)
        if not args.execute:
            print(json.dumps({'status':'local_inputs_validated', 'remote_access':False,
                'execution':'Run --execute only after the Android phases have completed'}))
            return
        require(args.output is not None, '--output is required for live execution evidence')
        require(args.output.resolve() not in {args.runtime_json.resolve(), args.client_defines.resolve()},
            'Evidence output must not overwrite runtime inputs')
        result = execute(runtime, client)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print(json.dumps({'status':result['status'], 'fixture_created':result['fixture']['created'],
            'http_checks':len(result['requests'])}))
    except SeedSafetyError as error:
        raise SystemExit(str(error)) from None
    except (SQLAlchemyError, HTTPException, OSError, json.JSONDecodeError, ValueError):
        raise SystemExit('Isolation verification failed; secrets and database rows are omitted') from None


if __name__ == '__main__':
    main()
