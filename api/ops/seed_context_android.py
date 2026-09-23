"""Synthetic Wave 1 data, restricted to the dedicated disposable QA database."""
import argparse
from datetime import date
import json
import os
import re

from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import select, func
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import AuthService, RegisterRequest
from app.config import Settings
from app.context_memberships import backfill_context_bindings
from app.database import Database, normalize_database_url
from app.models import User, Institution, Program, Course, CourseVersion, ProgramCourse, ProgramMembership, Enrollment, Classroom, ClassEnrollment


APPROVED_SUPABASE_PROJECT = 'lgtphbbpgqnzduhtyate'


class SeedSafetyError(RuntimeError):
    """A target or precondition was rejected without exposing connection secrets."""


def validate_target(database_url, *, environment=None, approved_supabase_project=None):
    try:
        target = make_url(normalize_database_url(database_url))
    except (ArgumentError, ValueError):
        raise SeedSafetyError('Invalid QA database URL') from None
    if target.get_backend_name() != 'postgresql':
        raise SeedSafetyError('QA seed requires PostgreSQL')
    # The private VPS runner retains its original dedicated database guard.
    if approved_supabase_project is None:
        if target.database != 'tds_context_staging_qa':
            raise SeedSafetyError('Use the dedicated VPS QA database or explicitly approved Supabase project')
        return 'vps'
    if approved_supabase_project != APPROVED_SUPABASE_PROJECT:
        raise SeedSafetyError('Supabase project is not approved for this QA seed')
    if environment != 'staging':
        raise SeedSafetyError('Supabase QA seed requires TUTOR_ENVIRONMENT=staging')
    if target.database != 'postgres':
        raise SeedSafetyError('Approved Supabase QA database must be postgres')
    forbidden = {'host', 'hostaddr', 'port', 'user', 'password', 'dbname', 'database', 'service', 'servicefile'}
    if forbidden.intersection(key.lower() for key in target.query):
        raise SeedSafetyError('Connection target overrides are forbidden for QA seed')
    if target.query.get('sslmode') not in {'require', 'verify-ca', 'verify-full'}:
        raise SeedSafetyError('Supabase QA seed requires explicit TLS')
    direct = target.host == f'db.{approved_supabase_project}.supabase.co'
    pooler = (
        re.fullmatch(r'[a-z0-9-]+\.pooler\.supabase\.com', target.host or '') is not None
        and target.username == f'postgres.{approved_supabase_project}'
    )
    if not (direct or pooler):
        raise SeedSafetyError('Connection does not match the approved Supabase project')
    return 'supabase'


def validate_empty_head(session, *, migration_config='alembic.ini'):
    expected = set(ScriptDirectory.from_config(Config(migration_config)).get_heads())
    current = set(MigrationContext.configure(session.connection()).get_current_heads())
    if not expected or current != expected:
        raise SeedSafetyError('QA seed requires the current Alembic schema head')
    if session.scalar(select(func.count()).select_from(User)) != 0:
        raise SeedSafetyError('Seed only an empty QA database')
    return sorted(current)


def seed_context(session, settings, *, student_password, teacher_password):
    """The existing synthetic course and cohort; caller owns the transaction."""
    service = AuthService(session, settings)
    student = service.register(RegisterRequest(name='Aluno QA Contexto', cpf='12345678909', phone='61999990000', password=student_password))
    teacher = service.register(RegisterRequest(name='Instrutor QA Contexto', cpf='11144477735', phone='61999990000', password=teacher_password))
    session.add(Institution(id='qa-org', name='Organização sintética QA'))
    session.flush()
    session.add(Program(id='qa-program', institution_id='qa-org', name='Formação QA'))
    content = {'id':'qa-course', 'title':'Curso da turma QA — edição 1', 'author':'Tutor TDS QA', 'sections':[
        {'id':'qa-module-1','title':'Conservação do solo','messages':[
            {'type':'bot','content':'A cobertura vegetal ajuda a conservar a umidade do solo.'},
            {'type':'quiz','content':'O que ajuda a conservar a umidade do solo?', 'options':[
                {'label':'Manter cobertura vegetal','isCorrect':True,'feedback':'Correto! A cobertura protege o solo.'},
                {'label':'Deixar o solo descoberto','isCorrect':False,'feedback':'Revise a função da cobertura.'}]},
            {'type':'bot','content':'A atividade desta etapa foi concluída. Continue para revisar.'}]},
        {'id':'qa-module-2','title':'Revisão da turma','messages':[
            {'type':'bot','content':'Revisão QA: preservar a cobertura vegetal favorece o solo.'}]}]}
    current = {**content, 'title':'Catálogo QA — edição 2'}
    session.add(Course(id='qa-course', title=current['title'], author='Tutor TDS QA', content=current, active=True))
    session.flush()
    session.add_all([ProgramCourse(program_id='qa-program', course_id='qa-course', planned_seconds=120),
        ProgramMembership(user_id=student.id, program_id='qa-program', role='student'),
        ProgramMembership(user_id=teacher.id, program_id='qa-program', role='teacher'),
        CourseVersion(id='qa-edition-1', course_id='qa-course', version_number=1, revision=1, status='archived', content=content),
        CourseVersion(id='qa-edition-2', course_id='qa-course', version_number=2, revision=1, status='published', content=current)])
    session.flush()
    session.add(Enrollment(id='qa-legacy-enrollment', user_id=student.id, program_id='qa-program', course_id='qa-course'))
    session.add(Classroom(id='qa-cohort', program_id='qa-program', course_id='qa-course', course_version_id='qa-edition-1',
        teacher_id=teacher.id, name='Turma QA Context Core', start_date=date(2026,1,1), end_date=date(2027,12,31), status='active'))
    session.flush()
    session.add(ClassEnrollment(class_id='qa-cohort', user_id=student.id, enrollment_id='qa-legacy-enrollment',
        program_id='qa-program', course_id='qa-course', status='active'))
    session.flush()
    backfill_context_bindings(session)
    return {'student_id':student.id,'teacher_id':teacher.id,'cohort_id':'qa-cohort',
        'course_id':'qa-course','course_version_id':'qa-edition-1','initial_events':0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--approved-supabase-project')
    parser.add_argument('--preflight-only', action='store_true')
    args = parser.parse_args()
    settings = Settings.from_environment()
    try:
        provider = validate_target(settings.database_url, environment=os.getenv('TUTOR_ENVIRONMENT'),
            approved_supabase_project=args.approved_supabase_project)
        database = Database(settings.database_url)
        try:
            with Session(database.engine) as session, session.begin():
                schema_heads = validate_empty_head(session)
                if args.preflight_only:
                    result = {'status':'preflight_passed', 'provider':provider, 'schema_heads':schema_heads, 'users':0}
                else:
                    passwords = [os.getenv('QA_STUDENT_PASSWORD', ''), os.getenv('QA_TEACHER_PASSWORD', '')]
                    if any(not 12 <= len(value) <= 128 for value in passwords):
                        raise SeedSafetyError('Set both QA passwords to 12–128 characters before seeding')
                    result = seed_context(session, settings,
                        student_password=passwords[0], teacher_password=passwords[1])
            print(json.dumps(result))
        finally:
            database.dispose()
    except SeedSafetyError as error:
        raise SystemExit(str(error)) from None
    except SQLAlchemyError:
        # Driver/SQL exceptions may include connection parameters or row values.
        raise SystemExit('QA database operation failed; no connection details are emitted') from None


if __name__ == '__main__':
    main()
