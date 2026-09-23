"""Prepare synthetic cohorts after UI publication, using only existing HTTP commands.

Default mode validates local configuration and prints a plan without remote access.
--execute reads the approved database in read-only transactions, authenticates the
four QA personas over HTTPS, and performs narrowly scoped administrative commands.
The operational four-persona defines file must never be compiled into the APK.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import ssl
from urllib.error import HTTPError, URLError
from urllib.request import HTTPSHandler, Request, build_opener
from uuid import UUID

from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.config import Settings
from app.context_memberships import membership_id
from app.database import Database
from app.learning_context import resolve_student_context
from app.models import (ClassEnrollment, ClassMonitor, Classroom, CohortMembership, Course,
    CourseVersion, CourseVersionTransition, Enrollment, Institution, LearningEventRecord,
    Program, ProgramCourse, ProgramMembership, User)
from ops import prepare_dynamic_learning_qa as fixture
from ops import verify_cloud_context_isolation as isolation
from ops.seed_context_android import APPROVED_SUPABASE_PROJECT, SeedSafetyError, validate_target


API_BASE = isolation.API_BASE
ROOT = fixture.ROOT
COURSE_PREFIX, PROGRAM_ID = fixture.COURSE_ID, fixture.PROGRAM_ID
START_DATE, END_DATE = '2026-09-23', '2027-12-31'
PLANNED_SECONDS = 120
CORE_MODELS = (User, Institution, Program, ProgramMembership, Course, CourseVersion,
    CourseVersionTransition, ProgramCourse, Classroom, Enrollment, ClassEnrollment,
    CohortMembership, ClassMonitor)
require = isolation.require


def _uuid(value):
    try:
        UUID(value)
    except (ValueError, TypeError, AttributeError):
        raise SeedSafetyError('Invalid synthetic UUID') from None
    return value


def course_scope(defines, run_id=None):
    course_id = defines.get('QA_DYNAMIC_COURSE_ID')
    match = re.fullmatch(re.escape(COURSE_PREFIX) + r'-([a-f0-9]{32})', course_id or '')
    require(match is not None, 'Course must identify one complete QA run')
    resolved_run = match.group(1)
    require(run_id is None or run_id == resolved_run, 'Course and run identifier disagree')
    return course_id, resolved_run


def class_names(run_id):
    return {number: f'Turma QA Dynamic {run_id[:8]} edição {number}' for number in (1, 2)}


def validate_defines(defines, runtime, run_id):
    validate_target(runtime.get('DATABASE_URL', ''), environment=runtime.get('TUTOR_ENVIRONMENT'),
        approved_supabase_project=APPROVED_SUPABASE_PROJECT)
    require(runtime.get('PUBLIC_API_BASE_URL') == defines.get('TUTOR_API_URL')
        == defines.get('TUTOR_STAGING_API_URL') == API_BASE, 'Unexpected QA API target')
    require(defines.get('TUTOR_ENVIRONMENT') == 'staging'
        and runtime.get('LEARNING_CONTEXT_ENABLED') == defines.get('LEARNING_CONTEXT_ENABLED') == 'true'
        and defines.get('DURABLE_LEARNING_OUTBOX_ENABLED') == 'true', 'Required staging flags disagree')
    course_scope(defines, run_id)
    require(defines.get('QA_DYNAMIC_PROGRAM_ID') == PROGRAM_ID, 'Unexpected synthetic program')
    require(isinstance(runtime.get('JWT_SECRET'), str) and len(runtime['JWT_SECRET']) >= 32,
        'Runtime secret is required to verify operational credentials')
    settings = Settings(database_url=runtime['DATABASE_URL'], allowed_origins=(), jwt_secret=runtime['JWT_SECRET'])
    identities = []
    for persona, (cpf, _, _, _) in fixture.PERSONAS.items():
        identities.append(_uuid(defines.get(f'QA_DYNAMIC_{persona}_ID')))
        require(defines.get(f'QA_DYNAMIC_{persona}_CPF') == cpf
            and defines.get(f'QA_DYNAMIC_{persona}_PASSWORD') == fixture.persona_password(settings, persona),
            'Operational synthetic credentials disagree')
    require(len(set(identities)) == 4, 'Synthetic personas must have distinct identities')


def content_payload(value):
    metadata = {'course_version_id', 'version_id', 'version_number', 'legacy_progress_compatible', 'class_id'}
    return {key: item for key, item in value.items() if key not in metadata}


@contextmanager
def read_session(engine):
    with Session(engine, autoflush=False) as session, session.begin():
        if engine.dialect.name == 'postgresql':
            session.execute(text('SET TRANSACTION READ ONLY'))
        heads = set(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())
        require(heads and set(MigrationContext.configure(session.connection()).get_current_heads()) == heads,
            'Staging schema must match local Alembic head')
        yield session


class ReadOnlyInspector:
    def __init__(self, engine, defines):
        self.engine, self.defines = engine, defines
        self.course_id, self.run_id = course_scope(defines)

    def snapshot(self):
        with read_session(self.engine) as session:
            program = session.get(Program, PROGRAM_ID)
            isolation.fields(program, {'institution_id': 'qa-org', 'name': fixture.PROGRAM_NAME}, 'QA program')
            for persona, (_, name, role, membership) in fixture.PERSONAS.items():
                identity = self.defines[f'QA_DYNAMIC_{persona}_ID']
                isolation.fields(session.get(User, identity), {'name': name, 'role': role}, 'QA identity')
                links = session.scalars(select(ProgramMembership).where(ProgramMembership.user_id == identity)).all()
                if membership is None:
                    require(not links, 'Operator must not have program memberships')
                else:
                    require(len(links) == 1, 'Unexpected QA program memberships')
                    isolation.fields(links[0], {'program_id': PROGRAM_ID, 'role': membership, 'status': 'active'},
                        'QA program membership')
            course = session.get(Course, self.course_id)
            require(course is not None and course.active, 'UI must publish the synthetic course first')
            offering = session.get(ProgramCourse, (PROGRAM_ID, self.course_id))
            require(offering is not None, 'Synthetic course offering is missing')
            require(set(session.scalars(select(ProgramCourse.program_id).where(ProgramCourse.course_id == self.course_id)))
                == {PROGRAM_ID}, 'Synthetic course cannot be shared with another program')
            versions = session.scalars(select(CourseVersion).where(CourseVersion.course_id == self.course_id)
                .order_by(CourseVersion.version_number)).all()
            classes = session.scalars(select(Classroom).where(Classroom.course_id == self.course_id)).all()
            class_ids = {row.id for row in classes}
            learner = self.defines['QA_DYNAMIC_LEARNER_ID']
            enrollments = session.scalars(select(Enrollment).where(Enrollment.course_id == self.course_id)).all()
            links = session.scalars(select(ClassEnrollment).where(ClassEnrollment.course_id == self.course_id)).all()
            events = session.scalars(select(LearningEventRecord).order_by(LearningEventRecord.event_id)).all()
            records = lambda rows: [isolation.record_values(row) for row in rows]
            protected = {}
            for model in CORE_MODELS:
                rows = session.scalars(select(model)).all()
                if model is ProgramCourse:
                    rows = [row for row in rows if (row.program_id, row.course_id) != (PROGRAM_ID, self.course_id)]
                elif model is Classroom:
                    rows = [row for row in rows if row.id not in class_ids]
                elif model is Enrollment:
                    rows = [row for row in rows if row.course_id != self.course_id]
                elif model in (ClassEnrollment, CohortMembership, ClassMonitor):
                    rows = [row for row in rows if row.class_id not in class_ids]
                protected[model.__tablename__] = sorted(records(rows), key=lambda item: json.dumps(item, sort_keys=True, default=str))
            return {'planned_seconds': offering.planned_seconds,
                'versions': [{'version_id': row.id, 'version_number': row.version_number,
                    'status': row.status, 'content_sha256': isolation.digest(row.content), 'content': row.content}
                    for row in versions], 'classes': records(classes), 'enrollments': records(enrollments),
                'class_enrollments': records(links),
                'unbound_study_count': sum(row.user_id == learner and row.course_id == self.course_id
                    and row.event_type == 'study_activity' and row.enrollment_id is None for row in events),
                'course_event_count': sum(row.course_id == self.course_id for row in events),
                'all_events_count': len(events), 'all_events_sha256': isolation.digest(records(events)),
                'protected_sha256': isolation.digest(protected)}


class HostHttp:
    def __init__(self):
        self.opener = build_opener(HTTPSHandler(context=ssl.create_default_context()), isolation.NoRedirect())
        self.requests = []

    def request(self, method, path, *, token=None, body=None, expected=200):
        require(path.startswith('/') and not path.startswith('//') and '://' not in path, 'Invalid QA API path')
        headers = {'User-Agent': isolation.USER_AGENT, 'Accept': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if body is not None:
            headers['Content-Type'] = 'application/json'
        request = Request(API_BASE + path, method=method, headers=headers,
            data=None if body is None else json.dumps(body).encode())
        try:
            with self.opener.open(request, timeout=30) as response:
                status, raw = response.status, response.read(2_000_000)
        except HTTPError as error:
            status, raw = error.code, error.read(2_000_000)
        except (URLError, TimeoutError):
            raise SeedSafetyError('Staging HTTPS failed; inspect current state before retrying') from None
        self.requests.append({'method': method, 'path': path, 'status': status})
        require(status == expected, f'Unexpected HTTPS response: {method} {path} returned {status}')
        return json.loads(raw)


class Bootstrap:
    def __init__(self, defines, inspector, http):
        self.defines, self.inspector, self.http = defines, inspector, http
        self.course_id, self.run_id = course_scope(defines)
        self.class_names = class_names(self.run_id)
        self.workload_path = f'/admin/programs/{PROGRAM_ID}/courses/{self.course_id}/workload'
        self.tokens = {}
        self.allowed_class_ids = set()

    def login(self, personas=None):
        for persona, (_, name, role, _) in fixture.PERSONAS.items():
            if personas is not None and persona not in personas:
                continue
            identity = self.defines[f'QA_DYNAMIC_{persona}_ID']
            response = self.http.request('POST', '/auth/login', body={
                'cpf': self.defines[f'QA_DYNAMIC_{persona}_CPF'],
                'password': self.defines[f'QA_DYNAMIC_{persona}_PASSWORD']})
            require(response.get('user') == {'id': identity, 'name': name, 'role': role}
                and isinstance(response.get('access_token'), str), 'HTTPS login returned an unexpected persona')
            self.tokens[persona] = response['access_token']
            require(self.read(persona, '/auth/me') == response['user'], 'Authenticated identity changed')

    def read(self, persona, path):
        return self.http.request('GET', path, token=self.tokens[persona])

    def command(self, method, path, body=None, expected=200):
        learner = self.defines['QA_DYNAMIC_LEARNER_ID']
        allowed = ((method, path) in {('POST', '/admin/enrollments'), ('POST', '/admin/classes'), ('PUT', self.workload_path)})
        parts = path.split('/')
        if len(parts) == 6 and parts[1:3] == ['admin', 'classes'] and parts[4:] == ['students', learner]:
            _uuid(parts[3])
            allowed = method == 'POST' and parts[3] in self.allowed_class_ids
        require(allowed, 'Host command is outside the synthetic bootstrap allowlist')
        if path in {'/admin/enrollments', '/admin/classes'}:
            require(body['program_id'] == PROGRAM_ID and body['course_id'] == self.course_id,
                'Host command cannot target another course/program')
        if path == '/admin/enrollments':
            require(body == {'user_id': learner, 'program_id': PROGRAM_ID, 'course_id': self.course_id},
                'Host can enroll only the synthetic learner')
        elif path == '/admin/classes':
            require(body.get('name') in self.class_names.values() and body == {
                'program_id': PROGRAM_ID, 'course_id': self.course_id,
                'teacher_id': self.defines['QA_DYNAMIC_AUTHOR_ID'], 'name': body['name'],
                'start_date': START_DATE, 'end_date': END_DATE, 'status': 'active'},
                'Host can create only the approved synthetic classrooms')
        elif path == self.workload_path:
            require(body == {'planned_hours': PLANNED_SECONDS / 3600}, 'Only the synthetic QA workload is allowed')
        return self.http.request(method, path, token=self.tokens['OPERATOR'], body=body, expected=expected)

    def inspect_phase(self, phase, state):
        expected_number = 1 if phase == 'after_v1' else 2
        snapshot = self.inspector.snapshot()
        require(len(snapshot['versions']) == expected_number, 'Unexpected number of course editions')
        current = snapshot['versions'][-1]
        require(current['version_number'] == expected_number and current['status'] == 'published',
            'UI has not published the expected edition')
        public = self.read('LEARNER', f'/courses/{self.course_id}')
        require(public.get('course_version_id') == current['version_id']
            and public.get('version_number') == expected_number
            and isolation.digest(content_payload(public)) == current['content_sha256'],
            'Public catalog differs from the published snapshot')
        editorial = self.read('PUBLISHER', f'/editor/courses/{self.course_id}?version_id={current["version_id"]}')
        require(editorial.get('status') == 'published' and editorial.get('program_id') == PROGRAM_ID
            and editorial.get('version_id') == current['version_id'], 'Editorial publication is not confirmed')
        require(snapshot['planned_seconds'] in {144000, PLANNED_SECONDS}, 'Unexpected QA course workload')
        if snapshot['enrollments'] or snapshot['unbound_study_count']:
            require(snapshot['planned_seconds'] == PLANNED_SECONDS, 'Workload cannot change after enrollment/study')
        learner = self.defines['QA_DYNAMIC_LEARNER_ID']
        require(len(snapshot['enrollments']) <= 1 and all(row['user_id'] == learner
            and row['program_id'] == PROGRAM_ID and row['status'] == 'active' for row in snapshot['enrollments']),
            'Unexpected or inactive synthetic enrollment')
        require(not snapshot['unbound_study_count'],
            'Unbound study exists; legacy enrollment creation would modify historical events')
        for row in snapshot['classes']:
            number = next((number for number, title in self.class_names.items() if row['name'] == title), None)
            require(number is not None and number <= expected_number, 'Unexpected synthetic classroom')
            self.check_class(row, number, snapshot['versions'][number - 1]['version_id'])
        for number in range(1, expected_number + 1):
            require(sum(row['name'] == self.class_names[number] for row in snapshot['classes']) <= 1,
                'Duplicate synthetic classrooms; refusing to guess')
        for link in snapshot['class_enrollments']:
            require(link['user_id'] == learner and link['program_id'] == PROGRAM_ID and link['status'] == 'active',
                'Unexpected or revoked classroom enrollment; refusing reactivation')
        if phase == 'after_v2':
            require(state is not None and state.get('v1') is not None, 'The after_v1 host state is required')
            previous = snapshot['versions'][0]
            require(previous['status'] == 'archived' and previous['version_id'] == state['v1']['version_id']
                and previous['content_sha256'] == state['v1']['content_sha256'], 'Pinned first edition changed')
            require(any(row['id'] == state['v1']['class_id'] for row in snapshot['classes']), 'First classroom disappeared')
        return snapshot

    def check_class(self, row, number, version_id):
        _uuid(row['id'])
        expected = {'program_id': PROGRAM_ID, 'course_id': self.course_id,
            'teacher_id': self.defines['QA_DYNAMIC_AUTHOR_ID'], 'course_version_id': version_id,
            'name': self.class_names[number], 'status': 'active'}
        require(all(row.get(key) == value for key, value in expected.items())
            and str(row['start_date']) == START_DATE and str(row['end_date']) == END_DATE,
            'Synthetic classroom attributes disagree; no repair is allowed')
        self.allowed_class_ids.add(row['id'])

    def describe(self, class_id, version):
        learner = self.defines['QA_DYNAMIC_LEARNER_ID']
        content = self.read('AUTHOR', f'/classes/{class_id}/course')
        require(content.get('course_version_id') == version['version_id']
            and isolation.digest(content_payload(content)) == version['content_sha256'], 'Class content is not pinned')
        snapshot = self.read('LEARNER', f'/classes/{class_id}/learning-context')
        observed = self.read('AUTHOR', f'/classes/{class_id}/students/{learner}/learning-context')
        context = snapshot['context']
        require(snapshot.get('contract_version') == 'cohort-enrollment-v2'
            and context['user_id'] == learner and context['organization_id'] == 'qa-org'
            and context['program_id'] == PROGRAM_ID and context['course_id'] == self.course_id
            and context['cohort_id'] == class_id and context['course_version_id'] == version['version_id']
            and context['role'] == 'student', 'Learner context lineage is incorrect')
        require(observed['context'] == context and observed['progress'] == snapshot['progress'],
            'Instructor and learner progress disagree')
        return {'class_id': class_id, 'version_id': version['version_id'], 'version_number': version['version_number'],
            'content_sha256': version['content_sha256'], 'content': version['content'],
            'context': context, 'progress': snapshot['progress']}

    def run(self, phase, state=None):
        require(phase in {'after_v1', 'after_v2'}, 'Unknown bootstrap phase')
        if state is not None:
            require(state.get('api_base') == API_BASE and state.get('course_id') == self.course_id
                and state.get('program_id') == PROGRAM_ID
                and state.get('learner_id') == self.defines['QA_DYNAMIC_LEARNER_ID'], 'Host state belongs to another fixture')
        self.login()
        before = self.inspect_phase(phase, state)
        number = 1 if phase == 'after_v1' else 2
        first_before = self.describe(state['v1']['class_id'], before['versions'][0]) if number == 2 else None
        if first_before:
            require(first_before['context'] == state['v1']['context']
                and first_before['progress']['progress_percent'] > 0, 'Study edition 1 before preparing edition 2')
        if before['planned_seconds'] != PLANNED_SECONDS:
            response = self.command('PUT', self.workload_path, {'planned_hours': PLANNED_SECONDS / 3600})
            require(response.get('planned_hours') == PLANNED_SECONDS / 3600, 'Synthetic workload update was not confirmed')
        learner = self.defines['QA_DYNAMIC_LEARNER_ID']
        if not before['enrollments']:
            enrollment = self.command('POST', '/admin/enrollments',
                {'user_id': learner, 'program_id': PROGRAM_ID, 'course_id': self.course_id}, expected=201)
            _uuid(enrollment.get('id'))
            require(enrollment.get('user_id') == learner and enrollment.get('program_id') == PROGRAM_ID
                and enrollment.get('course_id') == self.course_id and enrollment.get('status') == 'active',
                'Created enrollment differs from the requested fixture')
        else:
            enrollment = before['enrollments'][0]
        version = before['versions'][number - 1]
        classroom = next((row for row in before['classes'] if row['name'] == self.class_names[number]), None)
        if classroom is None:
            classroom = self.command('POST', '/admin/classes', {'program_id': PROGRAM_ID, 'course_id': self.course_id,
                'teacher_id': self.defines['QA_DYNAMIC_AUTHOR_ID'], 'name': self.class_names[number],
                'start_date': START_DATE, 'end_date': END_DATE, 'status': 'active'}, expected=201)
            self.check_class(classroom, number, version['version_id'])
        link = next((row for row in before['class_enrollments'] if row['class_id'] == classroom['id']), None)
        if link is None:
            self.command('POST', f'/admin/classes/{classroom["id"]}/students/{learner}', expected=201)
        else:
            require(link['enrollment_id'] == enrollment['id'] and link['course_version_id'] == version['version_id'],
                'Existing enrollment lineage differs')
        after = self.inspect_phase(phase, state)
        require(after['all_events_count'] == before['all_events_count']
            and after['all_events_sha256'] == before['all_events_sha256']
            and after['protected_sha256'] == before['protected_sha256'], 'Historical data changed during bootstrap')
        current = self.describe(classroom['id'], version)
        require(current['context']['legacy_enrollment_id'] == enrollment['id'], 'Legacy enrollment lineage changed')
        if number == 1 and state is not None and state.get('v1'):
            require(current['class_id'] == state['v1']['class_id']
                and current['version_id'] == state['v1']['version_id']
                and current['content_sha256'] == state['v1']['content_sha256']
                and current['context'] == state['v1']['context'], 'Recorded first classroom identity changed')
        result = {'api_base': API_BASE, 'course_id': self.course_id, 'program_id': PROGRAM_ID,
            'learner_id': learner, 'planned_seconds': PLANNED_SECONDS}
        result[f'v{number}'] = current
        if number == 2:
            first_after = self.describe(first_before['class_id'], before['versions'][0])
            require(first_after == first_before, 'First classroom progress/content changed while adding the second')
            require(current['context']['enrollment_id'] != first_after['context']['enrollment_id']
                and current['context']['membership_id'] != first_after['context']['membership_id']
                and current['context']['legacy_enrollment_id'] == first_after['context']['legacy_enrollment_id'],
                'Second enrollment must have independent context and shared legacy lineage')
            require(current['progress']['progress_percent'] == current['progress']['validated_hours'] == 0,
                'Second classroom unexpectedly has progress; no reset is allowed')
            result['v1'] = first_after
        result['last_completed_phase'] = phase
        evidence = {'status': 'bootstrap_passed', 'phase': phase, 'api_base': API_BASE,
            'course_id': self.course_id, 'program_id': PROGRAM_ID, 'planned_seconds': PLANNED_SECONDS,
            'synthetic_workload': '120 seconds for QA only; set before enrollment and preserved after study',
            'before': {key: before[key] for key in ('all_events_count', 'all_events_sha256', 'protected_sha256')},
            'after': {key: after[key] for key in ('all_events_count', 'all_events_sha256', 'protected_sha256')},
            'state': result, 'requests': self.http.requests,
            'verified_at': datetime.now(timezone.utc).isoformat(),
            'limitations': ['Synthetic staging bootstrap only; course publication remains in coordinator UI',
                'No direct database writes; partial HTTP success is preserved and rechecked on the next run']}
        return result, evidence


def capture_history(session):
    """Keep full event evidence; other core rows use per-PK hashes, never credential columns."""
    core = {}
    for model in CORE_MODELS:
        keys = [column.key for column in inspect(model).primary_key]
        core[model.__tablename__] = {json.dumps([getattr(row, key) for key in keys], separators=(',', ':')):
            isolation.digest(isolation.record_values(row)) for row in session.scalars(select(model))}
    events = {row.event_id: isolation.record_values(row) for row in session.scalars(select(LearningEventRecord))}
    return json.loads(json.dumps({'core': core, 'events': events}, default=lambda value: value.isoformat()))


def require_preserved_history(initial, current):
    for table, records in initial['core'].items():
        require(all(current['core'].get(table, {}).get(key) == digest for key, digest in records.items()),
            'An initial core record changed or disappeared')
    require(all(current['events'].get(key) == body for key, body in initial['events'].items()),
        'An initial learning event changed or disappeared')


def verify_editorial_ledger(session, state, defines):
    author, publisher = defines['QA_DYNAMIC_AUTHOR_ID'], defines['QA_DYNAMIC_PUBLISHER_ID']
    expected = set()
    for key in ('v1', 'v2'):
        identity = state[key]['version_id']
        expected.update({(identity, None, 'draft', author, 'teacher'),
            (identity, 'draft', 'in_review', author, 'teacher'),
            (identity, 'in_review', 'published', publisher, 'coordinator')})
    expected.add((state['v1']['version_id'], 'published', 'archived', publisher, 'coordinator'))
    records = session.scalars(select(CourseVersionTransition).where(CourseVersionTransition.version_id.in_(
        [state['v1']['version_id'], state['v2']['version_id']])).order_by(CourseVersionTransition.id)).all()
    observed = {(row.version_id, row.from_status, row.to_status, row.actor_user_id, row.actor_role) for row in records}
    require(len(records) == 7 and observed == expected,
        'Editorial ledger has unexpected transitions or actors')
    return {'transition_count': len(records), 'sha256': isolation.digest([isolation.record_values(row) for row in records])}


def validate_gate_start(session, settings, client, approval, defines, run_id):
    """Validate fixed identities and all prior QA scopes without resetting them.

    The initial seed remains stricter. A new gate may coexist with earlier QA
    courses; every existing row is captured below and must remain unchanged.
    """
    course_id, _ = course_scope(defines, run_id)
    require(session.get(Course, course_id) is None, 'This run course must be absent before installing the APK')
    fixture.validate_approved_history(session, client, approval)
    people = fixture._existing_personas(session, settings)
    require(set(people) == set(fixture.PERSONAS) and all(
        people[persona].id == defines[f'QA_DYNAMIC_{persona}_ID'] for persona in people),
        'Operational defines identify another fixture')
    student, teacher = client['QA_STUDENT_ID'], client['QA_TEACHER_ID']
    service = fixture.AuthService(session, settings)
    outsider = session.scalar(select(User).where(User.cpf_digest == service._cpf_digest(isolation.OUTSIDER_CPF)))
    require(outsider is not None, 'Approved isolation identity is missing')
    isolation.fields(outsider, {'name': isolation.OUTSIDER_NAME, 'role': 'student'}, 'isolation identity')
    original_users = {student, teacher, outsider.id}
    for model, expected in [(Institution, {'qa-org'}), (Program, {'qa-program', PROGRAM_ID}),
            (User, original_users | {person.id for person in people.values()})]:
        require(set(session.scalars(select(model.id))) == expected, 'Unexpected staging identity/organization IDs')
    expected_members = {(student, 'qa-program', 'student'), (teacher, 'qa-program', 'teacher'),
        (outsider.id, 'qa-program', 'teacher')} | {
        (people[persona].id, PROGRAM_ID, role) for persona, (_, _, _, role) in fixture.PERSONAS.items() if role}
    require(set(session.execute(select(ProgramMembership.user_id, ProgramMembership.program_id,
        ProgramMembership.role).where(ProgramMembership.status == 'active'))) == expected_members
        and len(session.scalars(select(ProgramMembership)).all()) == len(expected_members),
        'Unexpected program memberships')
    for identity, number, status in [('qa-edition-1', 1, 'archived'), ('qa-edition-2', 2, 'published')]:
        isolation.fields(session.get(CourseVersion, identity),
            {'course_id': 'qa-course', 'version_number': number, 'status': status}, 'original course edition')
    original_classes = {'qa-cohort', isolation.SECOND_COHORT}
    isolation.fields(session.get(Classroom, isolation.SECOND_COHORT), {'teacher_id': outsider.id,
        'program_id': 'qa-program', 'course_id': 'qa-course', 'course_version_id': 'qa-edition-1',
        'status': 'active'}, 'isolation cohort')
    second = resolve_student_context(session, isolation.SECOND_COHORT, student)
    require(second.progress.progress_percent == second.progress.validated_hours == 0,
        'Approved second enrollment no longer has zero progress')
    course_ids = set(session.scalars(select(Course.id)))
    prior_courses = course_ids - {'qa-course'}
    require('qa-course' in course_ids and all(identity == COURSE_PREFIX or
        re.fullmatch(re.escape(COURSE_PREFIX) + r'-[a-f0-9]{32}', identity) for identity in prior_courses),
        'Unexpected course outside the QA namespace')
    require(set(session.execute(select(ProgramCourse.program_id, ProgramCourse.course_id)))
        == {('qa-program', 'qa-course')} | {(PROGRAM_ID, identity) for identity in prior_courses},
        'Unexpected QA course offering or shared program')
    versions = session.scalars(select(CourseVersion)).all()
    require({row.id for row in versions if row.course_id == 'qa-course'} == {'qa-edition-1', 'qa-edition-2'}
        and all(row.course_id == 'qa-course' or (row.course_id in prior_courses and row.program_id == PROGRAM_ID
            and row.creator_user_id == people['AUTHOR'].id) for row in versions),
        'Unexpected course edition lineage')
    classrooms = session.scalars(select(Classroom)).all()
    prior_class_ids = {row.id for row in classrooms if row.id not in original_classes}
    require(original_classes.issubset({row.id for row in classrooms}) and all(row.id in original_classes or
        (row.course_id in prior_courses and row.program_id == PROGRAM_ID and row.teacher_id == people['AUTHOR'].id)
        for row in classrooms), 'Unexpected classroom scope')
    enrollments = session.scalars(select(Enrollment)).all()
    require({row.id for row in enrollments if row.course_id == 'qa-course'} == {'qa-legacy-enrollment'}
        and all(row.course_id == 'qa-course' or (row.course_id in prior_courses and row.program_id == PROGRAM_ID
            and row.user_id == people['LEARNER'].id) for row in enrollments), 'Unexpected learner enrollment')
    links = session.scalars(select(ClassEnrollment)).all()
    require({(row.class_id, row.user_id) for row in links if row.class_id in original_classes}
        == {(identity, student) for identity in original_classes}
        and all(row.class_id in original_classes or (row.class_id in prior_class_ids
            and row.course_id in prior_courses and row.program_id == PROGRAM_ID
            and row.user_id == people['LEARNER'].id) for row in links), 'Unexpected classroom enrollment')
    original_bindings = {(identity, user, role) for identity, user, role in [
        ('qa-cohort', student, 'student'), ('qa-cohort', teacher, 'teacher'),
        (isolation.SECOND_COHORT, student, 'student'), (isolation.SECOND_COHORT, outsider.id, 'teacher')]}
    bindings = session.scalars(select(CohortMembership)).all()
    require({(row.class_id, row.user_id, row.role) for row in bindings if row.class_id in original_classes}
        == original_bindings and all(row.id == membership_id(row.class_id, row.user_id, row.role)
            and (row.class_id in original_classes or (row.class_id in prior_class_ids and
                (row.user_id, row.role) in {(people['AUTHOR'].id, 'teacher'), (people['LEARNER'].id, 'student')}))
            for row in bindings), 'Unexpected cohort membership')
    require(session.scalar(select(ClassMonitor.user_id).limit(1)) is None, 'Unexpected monitor assignment')


def before_android(engine, defines, runtime, wave1_client, approval, http, run_id):
    settings = fixture.validate_inputs(runtime, wave1_client)
    course_id, _ = course_scope(defines, run_id)
    with read_session(engine) as session:
        validate_gate_start(session, settings, wave1_client, approval, defines, run_id)
        history = capture_history(session)
        original = isolation.original_snapshot(session, wave1_client)
    # Public read only: no login/session mutation is necessary before the build.
    http.request('GET', f'/courses/{course_id}', expected=404)
    baseline = {'run_id': run_id, 'api_base': API_BASE, 'course_id': course_id, 'program_id': PROGRAM_ID,
        'learner_id': defines['QA_DYNAMIC_LEARNER_ID'], 'history': history, 'original': original,
        'wave1_gate_sha256': approval['gate_sha256']}
    state = {key: baseline[key] for key in ('run_id', 'api_base', 'course_id', 'program_id', 'learner_id')}
    state.update(last_completed_phase='before_android', baseline_sha256=isolation.digest(baseline),
        baseline_event_count=len(history['events']))
    evidence = {'status': 'baseline_captured', 'phase': 'before_android', 'run_id': run_id,
        'api_base': API_BASE, 'course_absent_in_database_and_catalog': True,
        'baseline_sha256': state['baseline_sha256'], 'baseline_event_count': state['baseline_event_count'],
        'initial_core_record_count': sum(len(rows) for rows in history['core'].values()),
        'original_context_sha256': original['original_context_sha256'],
        'original_progress_percent': approval['progress']['progress_percent'],
        'requests': http.requests, 'verified_at': datetime.now(timezone.utc).isoformat()}
    return state, evidence, baseline


def after_android(engine, defines, runtime, wave1_client, approval, http, state, baseline):
    require(state is not None and state.get('last_completed_phase') in {'after_v2', 'after_android'}
        and state.get('baseline_sha256') == isolation.digest(baseline), 'Completed bootstrap state/baseline is required')
    require(all(state.get(key) == baseline.get(key) for key in ('run_id', 'api_base', 'course_id', 'program_id', 'learner_id')),
        'Baseline belongs to another run')
    course_id, _ = course_scope(defines, state['run_id'])
    require(state['course_id'] == course_id, 'Final inspection belongs to another run course')
    fixture.validate_inputs(runtime, wave1_client)
    with read_session(engine) as session:
        fixture.validate_approved_history(session, wave1_client, approval)
        current = capture_history(session)
        require_preserved_history(baseline['history'], current)
        original = isolation.original_snapshot(session, wave1_client)
    flow = Bootstrap(defines, ReadOnlyInspector(engine, defines), http)
    flow.login({'AUTHOR', 'PUBLISHER', 'LEARNER'})
    inspected = flow.inspect_phase('after_v2', state)
    result = {key: state[key] for key in ('run_id', 'api_base', 'course_id', 'program_id', 'learner_id',
        'baseline_sha256', 'baseline_event_count')}
    for number in (1, 2):
        key = f'v{number}'
        observed = flow.describe(state[key]['class_id'], inspected['versions'][number - 1])
        require(observed['context'] == state[key]['context']
            and observed['content_sha256'] == state[key]['content_sha256']
            and observed['progress']['progress_percent'] >= state[key]['progress']['progress_percent'],
            'Dynamic context/content changed or progress regressed')
        if number == 1:
            require(observed['progress']['progress_percent'] > state[key]['progress']['progress_percent'],
                'Offline study has not advanced the first classroom progress')
        else:
            require(observed['progress']['progress_percent'] == observed['progress']['validated_hours'] == 0,
                'The second classroom must remain without credited activity')
        result[key] = observed
    with read_session(engine) as session:
        final = capture_history(session)
        require_preserved_history(baseline['history'], final)
        fixture.validate_approved_history(session, wave1_client, approval)
        ledger = verify_editorial_ledger(session, result, defines)
    result.update(last_completed_phase='after_android', planned_seconds=PLANNED_SECONDS)
    evidence = {'status': 'history_preservation_passed', 'phase': 'after_android', 'run_id': state['run_id'],
        'api_base': API_BASE, 'baseline_sha256': state['baseline_sha256'],
        'initial_events_preserved': len(baseline['history']['events']), 'current_event_count': len(final['events']),
        'initial_core_records_preserved': sum(len(rows) for rows in baseline['history']['core'].values()),
        'original_context_sha256': original['original_context_sha256'],
        'original_progress_percent': approval['progress']['progress_percent'],
        'editorial_ledger': ledger,
        'state': result, 'requests': http.requests, 'verified_at': datetime.now(timezone.utc).isoformat(),
        'limitations': ['Allows new records while requiring every initial event body and core row hash to remain identical',
            'Does not replace the eight Android phase assertions or approve production']}
    return result, evidence


@contextmanager
def state_lock(path):
    lock = path.with_suffix(path.suffix + '.lock')
    try:
        handle = lock.open('x', encoding='utf-8')
    except FileExistsError:
        raise SeedSafetyError('Host state is locked; verify no other bootstrap is running') from None
    try:
        with handle:
            handle.write('dynamic-learning-bootstrap\n')
        yield
    finally:
        lock.unlink()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', required=True, choices=['before_android', 'after_v1', 'after_v2', 'after_android'])
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--defines', required=True, type=Path)
    parser.add_argument('--runtime-json', type=Path, default=ROOT / 'tmp/cloud-staging-runtime.json')
    parser.add_argument('--wave1-client-defines', type=Path, default=ROOT / 'tmp/cloud-context-android-defines.json')
    parser.add_argument('--output-state', required=True, type=Path)
    parser.add_argument('--output-evidence', required=True, type=Path)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args(argv)
    try:
        defines = json.loads(args.defines.read_text(encoding='utf-8-sig'))
        runtime = json.loads(args.runtime_json.read_text(encoding='utf-8-sig'))
        run_id = args.run_id
        require(re.fullmatch(r'[a-f0-9]{32}', run_id) is not None, 'Invalid QA run identifier')
        validate_defines(defines, runtime, run_id)
        course_id, _ = course_scope(defines, run_id)
        inputs = [args.defines, args.runtime_json, args.wave1_client_defines]
        baseline_path = args.output_state.with_name(args.output_state.stem + '.baseline.json')
        fixture.validate_output_paths(args.output_state, args.output_evidence, inputs)
        fixture.validate_output_paths(baseline_path, args.output_evidence, inputs)
        if not args.execute:
            commands = {
                'before_android': ['validate Wave 1 approval and synthetic identities',
                    'confirm course absent in database and public catalog', 'capture initial core and event history'],
                'after_android': ['verify every initial event and core record remains unchanged',
                    'verify contextual progress and pinned content', 'verify editorial transitions and actors'],
            }.get(args.phase, ['confirm UI publication', 'set synthetic workload before study if needed',
                'ensure one legacy enrollment', 'ensure pinned classroom', 'ensure learner membership',
                'verify immutable content, context, progress and history'])
            print(json.dumps({'status': 'plan', 'remote_access': False, 'phase': args.phase,
                'run_id': run_id,
                'course_id': course_id, 'program_id': PROGRAM_ID, 'planned_seconds': PLANNED_SECONDS,
                'commands': commands}))
            return
        args.output_state.parent.mkdir(parents=True, exist_ok=True)
        with state_lock(args.output_state):
            state = json.loads(args.output_state.read_text(encoding='utf-8-sig')) if args.output_state.exists() else None
            require(state is None or state.get('run_id') == run_id, 'Host state belongs to another run')
            database = Database(runtime['DATABASE_URL'])
            try:
                if args.phase in {'before_android', 'after_android'}:
                    wave1_client = json.loads(args.wave1_client_defines.read_text(encoding='utf-8-sig'))
                    approval = fixture.load_approval(ROOT / 'docs/production/evidence/wave1-acceptance.json',
                        ROOT / fixture.ISOLATION_EVIDENCE, ROOT / fixture.ANDROID_EVIDENCE)
                    if args.phase == 'before_android':
                        result, evidence, baseline = before_android(database.engine, defines, runtime,
                            wave1_client, approval, HostHttp(), run_id)
                        if baseline_path.exists():
                            require(json.loads(baseline_path.read_text(encoding='utf-8-sig')) == baseline,
                                'Existing baseline differs; preserve it and use a new run identifier')
                        baseline_path.write_text(json.dumps(baseline, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
                    else:
                        baseline = json.loads(baseline_path.read_text(encoding='utf-8-sig'))
                        result, evidence = after_android(database.engine, defines, runtime, wave1_client,
                            approval, HostHttp(), state, baseline)
                else:
                    require(state is not None and state.get('baseline_sha256')
                        and baseline_path.exists(), 'Capture the before_android baseline first')
                    baseline = json.loads(baseline_path.read_text(encoding='utf-8-sig'))
                    require(isolation.digest(baseline) == state['baseline_sha256'], 'Initial baseline digest changed')
                    result, evidence = Bootstrap(defines, ReadOnlyInspector(database.engine, defines), HostHttp()).run(args.phase, state)
                    result.update(run_id=run_id, baseline_sha256=state['baseline_sha256'],
                        baseline_event_count=state['baseline_event_count'])
                    evidence.update(run_id=run_id, baseline_sha256=state['baseline_sha256'])
            finally:
                database.dispose()
            for path, value in [(args.output_state, result), (args.output_evidence, evidence)]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'status': evidence['status'], 'phase': args.phase,
            'run_id': run_id}))
    except SeedSafetyError as error:
        raise SystemExit(str(error)) from None
    except (SQLAlchemyError, OSError, ValueError, KeyError, TypeError):
        raise SystemExit('Dynamic bootstrap failed; secrets and database rows are omitted') from None


if __name__ == '__main__':
    main()
