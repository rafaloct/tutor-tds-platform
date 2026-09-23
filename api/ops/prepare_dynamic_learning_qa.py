"""Add the isolated Wave 2A identities only; never create its course or learning data.

Default mode validates local inputs/evidence without connecting to the database.
The explicit --execute mode is restricted to the approved staging project.
Run from api/. Credentials are written only to an ignored file under repo/tmp/.
This four-persona output is operational configuration: derive separate APK defines
with every QA_DYNAMIC_OPERATOR_* key removed before building the QA application.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import subprocess

from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import AuthService, LoginRequest, RegisterRequest
from app.context_memberships import membership_id
from app.database import Database
from app.learning_context import resolve_student_context
from app.models import (
    ClassEnrollment, ClassMonitor, Classroom, CohortMembership, Course, CourseVersion,
    Enrollment, Institution, LearningEventRecord, Program, ProgramCourse, ProgramMembership, User,
)
from ops.seed_context_android import APPROVED_SUPABASE_PROJECT, SeedSafetyError
from ops import verify_cloud_context_isolation as isolation


ROOT = Path(__file__).resolve().parents[2]
PROGRAM_ID = 'qa-dynamic-program'
PROGRAM_NAME = 'Formação QA — publicação dinâmica'
COURSE_ID = 'qa-dynamic-course'
PHONE = '61999990000'
PERSONAS = {
    'AUTHOR': ('79000000114', 'Autor QA Dynamic Learning', 'student', 'teacher'),
    'PUBLISHER': ('79000000203', 'Publicador QA Dynamic Learning', 'student', 'coordinator'),
    'LEARNER': ('79000000386', 'Aluno QA Dynamic Learning', 'student', 'student'),
    'OPERATOR': ('79000000467', 'Operador QA Dynamic Learning', 'admin', None),
}
ISOLATION_EVIDENCE = 'docs/production/evidence/cloud-context-isolation.json'
ANDROID_EVIDENCE = 'docs/production/evidence/context-android-gate.json'
EVENT_FIELDS = ('event_id', 'event_type', 'course_id', 'session_id', 'active_seconds',
    'validated_seconds', 'payload')
require = isolation.require


def persona_password(settings, persona):
    require(persona in PERSONAS, 'Unknown QA persona')
    label = f'tds:qa-dynamic-learning:{APPROVED_SUPABASE_PROJECT}:{persona}'
    return hmac.new(settings.jwt_secret.encode(), label.encode(), hashlib.sha256).hexdigest()


def validate_inputs(runtime, client):
    settings = isolation.validate_inputs(runtime, client)  # Includes exact target and TLS guard.
    require(client.get('DURABLE_LEARNING_OUTBOX_ENABLED') == 'true',
        'Durable contextual outbox must remain enabled in the QA client')
    return settings


def load_approval(gate_path, isolation_path, android_path):
    gate = json.loads(gate_path.read_text(encoding='utf-8-sig'))
    require(gate.get('status') == 'WAVE1_FUNCTIONAL_STAGING_PASSED'
        and gate.get('wave') == 1 and gate.get('next_wave_allowed') == 2
        and gate.get('api_url') == isolation.API_BASE, 'Wave 1 local acceptance is required')
    for key in ('student_learning_path', 'instructor_observation_path', 'offline_sync_path',
            'contextual_authorization_and_isolation_https'):
        require(gate.get('checks', {}).get(key) == 'passed', 'Wave 1 acceptance paths are incomplete')
    documents = {}
    hashes = {}
    for key, path in [(ISOLATION_EVIDENCE, isolation_path), (ANDROID_EVIDENCE, android_path)]:
        raw = path.read_bytes()
        hashes[key] = hashlib.sha256(raw).hexdigest()
        require(gate.get('evidence_sha256', {}).get(key) == hashes[key], 'Approved evidence hash mismatch')
        documents[key] = json.loads(raw.decode('utf-8-sig'))
    proof, android = documents[ISOLATION_EVIDENCE], documents[ANDROID_EVIDENCE]
    require(proof.get('status') == 'passed' and proof.get('api_base') == isolation.API_BASE
        and proof.get('project_sha256') == hashlib.sha256(APPROVED_SUPABASE_PROJECT.encode()).hexdigest(),
        'Isolation evidence belongs to another target or has not passed')
    require(android.get('status') == 'ANDROID_PATHS_PASSED'
        and android.get('all_phases_in_this_run') is True and android.get('separate_processes') is True,
        'Complete Android acceptance is required')
    phases = {item['phase']: item for item in android.get('phases', [])}
    require(set(phases) == {'student_online', 'student_restart', 'student_offline',
        'offline_restart', 'student_reconnect', 'instructor_observation'}, 'Android phases are incomplete')
    context = phases['instructor_observation']['context']
    events = {}
    for phase in phases.values():
        for event in phase.get('events', []):
            stable = {key: event[key] for key in (*EVENT_FIELDS, 'occurred_at')}
            previous = events.setdefault(event['event_id'], stable)
            require(previous == stable, 'Approved Android event evidence disagrees')
    require(events and proof['original_unchanged']['all_events_count'] >= len(events),
        'Approved learning event evidence is missing')
    require(proof['original_progress']['progress_percent'] > 0
        and proof['original_progress']['context_enrollment_id'] == context['enrollment_id'],
        'Approved context/progress evidence disagrees')
    return {'original_context_sha256': proof['original_unchanged']['original_context_sha256'],
        'minimum_event_count': proof['original_unchanged']['all_events_count'],
        'context': context, 'progress': proof['original_progress'], 'events': events,
        'evidence_sha256': hashes, 'gate_sha256': hashlib.sha256(gate_path.read_bytes()).hexdigest()}


def _instant(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00')) if isinstance(value, str) else value
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def _authenticate(service, cpf, password, expected_id):
    try:
        user = service.authenticate(LoginRequest(cpf=cpf, password=password))
    except HTTPException:
        raise SeedSafetyError('Existing synthetic credentials disagree; no reset is allowed') from None
    require(user.id == expected_id, 'Existing synthetic credentials resolve to another identity')


def validate_approved_history(session, client, approval):
    current = isolation.original_snapshot(session, client)
    require(current['original_context_sha256'] == approval['original_context_sha256'],
        'Original context differs from the approved Wave 1 state')
    require(current['all_events_count'] >= approval['minimum_event_count'],
        'Approved event history has lost records')
    context = resolve_student_context(session, 'qa-cohort', client['QA_STUDENT_ID'])
    require(context.context.model_dump(mode='json') == approval['context'], 'Approved context identity changed')
    for key in ('user_id', 'enrollment_id', 'context_enrollment_id', 'status', 'planned_hours',
            'validated_hours', 'progress_percent'):
        require(getattr(context.progress, key) == approval['progress'][key], 'Approved progress changed')
    for event_id, expected in approval['events'].items():
        row = session.get(LearningEventRecord, event_id)
        require(row is not None and row.user_id == client['QA_STUDENT_ID'],
            'Approved event disappeared or changed owner')
        actual = {key: getattr(row, key) for key in EVENT_FIELDS}
        actual['active_seconds'] = row.active_seconds or None  # Same representation as GET /events.
        require(actual == {key: expected[key] for key in EVENT_FIELDS}
            and _instant(row.occurred_at) == _instant(expected['occurred_at']),
            'Approved event body changed or disappeared')
    return current


def _existing_personas(session, settings):
    service = AuthService(session, settings)
    found = {persona: session.scalar(select(User).where(User.cpf_digest == service._cpf_digest(data[0])))
        for persona, data in PERSONAS.items()}
    program = session.get(Program, PROGRAM_ID)
    if program is None and not any(found.values()):
        return {}
    require(program is not None and all(found.values()), 'Partial dynamic QA fixture; refusing repair')
    isolation.fields(program, {'institution_id': 'qa-org', 'name': PROGRAM_NAME}, 'dynamic program')
    for persona, user in found.items():
        cpf, name, role, membership = PERSONAS[persona]
        isolation.fields(user, {'name': name, 'role': role, 'phone': PHONE}, 'dynamic QA identity')
        _authenticate(service, cpf, persona_password(settings, persona), user.id)
        links = session.scalars(select(ProgramMembership).where(ProgramMembership.user_id == user.id)).all()
        if membership is None:
            require(not links, 'Operational account must not receive a program membership')
        else:
            require(len(links) == 1, 'Unexpected dynamic QA program memberships')
            isolation.fields(links[0], {'program_id': PROGRAM_ID, 'role': membership, 'status': 'active'},
                'dynamic QA membership')
    return found


def validate_database(session, settings, client, approval):
    heads = set(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())
    require(heads and set(MigrationContext.configure(session.connection()).get_current_heads()) == heads,
        'Staging schema must match local Alembic head')
    require(session.get(Course, COURSE_ID) is None, 'Dynamic QA course must be absent before installing the APK')
    before = validate_approved_history(session, client, approval)
    people = _existing_personas(session, settings)
    student, teacher = client['QA_STUDENT_ID'], client['QA_TEACHER_ID']
    service = AuthService(session, settings)
    outsider = session.scalar(select(User).where(User.cpf_digest == service._cpf_digest(isolation.OUTSIDER_CPF)))
    require(outsider is not None, 'Approved isolation fixture is missing')
    original_users = {student, teacher, outsider.id}
    for persona in ('STUDENT', 'TEACHER'):
        _authenticate(service, client[f'QA_{persona}_CPF'], client[f'QA_{persona}_PASSWORD'], client[f'QA_{persona}_ID'])
    isolation.fields(outsider, {'name': isolation.OUTSIDER_NAME, 'role': 'student'}, 'isolation identity')
    _authenticate(service, isolation.OUTSIDER_CPF, isolation.outsider_password(settings), outsider.id)
    isolation.fields(session.get(ProgramMembership, (outsider.id, 'qa-program')),
        {'role': 'teacher', 'status': 'active'}, 'isolation program membership')
    for version_id, number, status in [('qa-edition-1', 1, 'archived'), ('qa-edition-2', 2, 'published')]:
        isolation.fields(session.get(CourseVersion, version_id),
            {'course_id': 'qa-course', 'version_number': number, 'status': status}, 'original course edition')
    for model, expected in [
        (Institution, {'qa-org'}), (Program, {'qa-program'} | ({PROGRAM_ID} if people else set())),
        (Course, {'qa-course'}), (CourseVersion, {'qa-edition-1', 'qa-edition-2'}),
        (Enrollment, {'qa-legacy-enrollment'}), (Classroom, {'qa-cohort', isolation.SECOND_COHORT}),
        (User, original_users | {user.id for user in people.values()}),
    ]:
        require(set(session.scalars(select(model.id))) == expected, 'Unexpected staging entity IDs')
    require(set(session.execute(select(ProgramCourse.program_id, ProgramCourse.course_id)))
        == {('qa-program', 'qa-course')}, 'Unexpected course offerings')
    require(set(session.execute(select(ClassEnrollment.class_id, ClassEnrollment.user_id)))
        == {('qa-cohort', student), (isolation.SECOND_COHORT, student)}, 'Unexpected learner enrollment')
    expected_memberships = {membership_id(cohort, user, role)
        for cohort, user, role in [('qa-cohort', student, 'student'), ('qa-cohort', teacher, 'teacher'),
            (isolation.SECOND_COHORT, student, 'student'), (isolation.SECOND_COHORT, outsider.id, 'teacher')]}
    require(set(session.scalars(select(CohortMembership.id))) == expected_memberships,
        'Unexpected cohort membership')
    for user, role in [(student, 'student'), (outsider.id, 'teacher')]:
        isolation.fields(session.get(CohortMembership, membership_id(isolation.SECOND_COHORT, user, role)),
            {'class_id': isolation.SECOND_COHORT, 'user_id': user, 'role': role, 'status': 'active'},
            'isolation cohort membership')
    expected_program_users = {(user, 'qa-program') for user in original_users}
    expected_program_users |= {(user.id, PROGRAM_ID) for persona, user in people.items()
        if PERSONAS[persona][3] is not None}
    require(set(session.execute(select(ProgramMembership.user_id, ProgramMembership.program_id)))
        == expected_program_users, 'Unexpected program memberships')
    require(session.scalar(select(ClassMonitor.user_id).limit(1)) is None, 'Unexpected monitor assignment')
    isolation.fields(session.get(Classroom, isolation.SECOND_COHORT), {'teacher_id': outsider.id,
        'program_id': 'qa-program', 'course_id': 'qa-course', 'course_version_id': 'qa-edition-1',
        'status': 'active'}, 'isolation cohort')
    second = resolve_student_context(session, isolation.SECOND_COHORT, student)
    require(second.progress.progress_percent == second.progress.validated_hours == 0,
        'Approved second enrollment no longer has zero progress')
    return people, before


def ensure_fixture(session, settings, client, approval):
    """Caller owns one transaction. Only users/program/program memberships are added."""
    people, before = validate_database(session, settings, client, approval)
    created = not people
    if created:
        session.add(Program(id=PROGRAM_ID, institution_id='qa-org', name=PROGRAM_NAME))
        session.flush()
        service = AuthService(session, settings)
        for persona, (cpf, name, role, membership) in PERSONAS.items():
            user = service.register(RegisterRequest(name=name, cpf=cpf, phone=PHONE,
                password=persona_password(settings, persona)))
            user.role = role
            people[persona] = user
            if membership is not None:
                session.add(ProgramMembership(user_id=user.id, program_id=PROGRAM_ID,
                    role=membership, status='active'))
        session.flush()
    validate_database(session, settings, client, approval)
    require(isolation.original_snapshot(session, client) == before, 'Fixture changed existing history; rolling back')
    defines = {key: client[key] for key in ('TUTOR_ENVIRONMENT', 'TUTOR_API_URL', 'TUTOR_STAGING_API_URL',
        'LEARNING_CONTEXT_ENABLED', 'DURABLE_LEARNING_OUTBOX_ENABLED')}
    defines.update(QA_DYNAMIC_PROGRAM_ID=PROGRAM_ID, QA_DYNAMIC_COURSE_ID=COURSE_ID)
    for persona, user in people.items():
        defines.update({f'QA_DYNAMIC_{persona}_ID': user.id, f'QA_DYNAMIC_{persona}_CPF': PERSONAS[persona][0],
            f'QA_DYNAMIC_{persona}_PASSWORD': persona_password(settings, persona)})
    evidence = {'status': 'fixture_prepared', 'created': created, 'api_base': isolation.API_BASE,
        'project_sha256': hashlib.sha256(APPROVED_SUPABASE_PROJECT.encode()).hexdigest(),
        'program_id': PROGRAM_ID, 'course_id': COURSE_ID, 'course_absent': True,
        'personas': {persona: {'global_role': data[2], 'program_role': data[3]} for persona, data in PERSONAS.items()},
        'original_unchanged': before, 'approved_event_bodies_verified': len(approval['events']),
        'wave1_gate_sha256': approval['gate_sha256'], 'evidence_sha256': approval['evidence_sha256'],
        'limitations': ['Synthetic staging identities only; no course, version, enrollment or event created',
            'Operator is reserved for legacy administrative fixture commands, never pedagogical publication',
            'Historical event bodies cover the Android evidence subset; all current rows are hashed before/after',
            'Sync delivery status may legitimately change after historical acceptance']}
    return defines, evidence


def validate_output_paths(defines_path, evidence_path, inputs):
    paths = {Path(item).resolve() for item in inputs}
    target, evidence = defines_path.resolve(), evidence_path.resolve()
    require(target.is_relative_to((ROOT / 'tmp').resolve()) and target.suffix == '.json'
        and target not in paths, 'Credentials output must be a separate ignored JSON under repo/tmp')
    ignored = subprocess.run(['git', 'check-ignore', '-q', '--', str(target)], cwd=ROOT,
        capture_output=True, check=False)
    require(ignored.returncode == 0, 'Credentials output must be ignored by Git')
    require(evidence.is_relative_to((ROOT / 'docs/production/evidence').resolve())
        and evidence.suffix == '.json' and evidence not in paths and evidence != target,
        'Sanitized evidence must be a separate JSON under docs/production/evidence')


def execute(runtime, client, approval, defines_path):
    settings = validate_inputs(runtime, client)
    database = Database(settings.database_url)
    try:
        with Session(database.engine) as session, session.begin():
            defines, evidence = ensure_fixture(session, settings, client, approval)
            if defines_path.exists():
                require(json.loads(defines_path.read_text(encoding='utf-8-sig')) == defines,
                    'Existing defines disagree; refusing to replace credentials')
        evidence['verified_at'] = datetime.now(timezone.utc).isoformat()
        return defines, evidence
    finally:
        database.dispose()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-json', required=True, type=Path)
    parser.add_argument('--client-defines', required=True, type=Path)
    parser.add_argument('--wave1-gate', type=Path, default=ROOT / 'docs/production/evidence/wave1-acceptance.json')
    parser.add_argument('--isolation-evidence', type=Path, default=ROOT / ISOLATION_EVIDENCE)
    parser.add_argument('--android-evidence', type=Path, default=ROOT / ANDROID_EVIDENCE)
    parser.add_argument('--output-defines', required=True, type=Path)
    parser.add_argument('--output-evidence', required=True, type=Path)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args(argv)
    try:
        runtime = json.loads(args.runtime_json.read_text(encoding='utf-8-sig'))
        client = json.loads(args.client_defines.read_text(encoding='utf-8-sig'))
        validate_inputs(runtime, client)
        approval = load_approval(args.wave1_gate, args.isolation_evidence, args.android_evidence)
        validate_output_paths(args.output_defines, args.output_evidence,
            [args.runtime_json, args.client_defines, args.wave1_gate, args.isolation_evidence, args.android_evidence])
        if not args.execute:
            print(json.dumps({'status': 'local_inputs_validated', 'remote_access': False,
                'course_id': COURSE_ID, 'course_must_be_absent': True, 'personas': list(PERSONAS)}))
            return
        defines, evidence = execute(runtime, client, approval, args.output_defines)
        for path, value in [(args.output_defines, defines), (args.output_evidence, evidence)]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print(json.dumps({'status': evidence['status'], 'created': evidence['created'],
            'course_absent': True, 'events_preserved': evidence['original_unchanged']['all_events_count']}))
    except SeedSafetyError as error:
        raise SystemExit(str(error)) from None
    except (SQLAlchemyError, HTTPException, OSError, json.JSONDecodeError, ValueError, KeyError, TypeError):
        raise SystemExit('Dynamic QA preparation failed; credentials and database rows are omitted') from None


if __name__ == '__main__':
    main()
