"""Isolated physical access fixture. Never modifies a previously approved cohort.

Creates a new synthetic cohort using existing HTTP commands. The revoke phase
changes only its learner bindings as a test fixture (no administrative revocation
API exists yet). This is not an implementation of a production revocation flow.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import Database
from app.models import Classroom, ClassEnrollment, CohortMembership
from ops.bootstrap_dynamic_learning_qa import (
    API_BASE, ROOT, HostHttp, Bootstrap, capture_history,
    require_preserved_history, validate_defines, read_session, require,
)


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=['prepare', 'revoke', 'verify'], required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    require(re.fullmatch(r'[a-f0-9]{32}', args.run_id) is not None, 'Invalid run ID')
    if not args.execute:
        print(json.dumps({'phase': args.phase, 'run_id': args.run_id, 'remote_access': False}))
        return
    run = ROOT / 'tmp' / f'classroom-access-{args.run_id}'
    state_path = run / 'fixture.json'
    source = ROOT / 'tmp/dynamic-learning-android-3c2d38851f024a1eb50667aa86dc7ce0/host-defines.json'
    defines = json.loads(source.read_text(encoding='utf-8-sig'))
    runtime = json.loads((ROOT / 'tmp/cloud-staging-runtime.json').read_text(encoding='utf-8-sig'))
    validate_defines(defines, runtime, '3c2d38851f024a1eb50667aa86dc7ce0')
    name = f'Turma QA Acesso {args.run_id}'
    learner = defines['QA_DYNAMIC_LEARNER_ID']
    database = Database(runtime['DATABASE_URL'])
    http = HostHttp()
    flow = Bootstrap(defines, None, http)
    try:
        if args.phase == 'prepare':
            require(not run.exists(), 'Preserve existing run; no reset or automatic retry')
            run.mkdir()
            with read_session(database.engine) as session:
                require(session.scalar(select(Classroom.id).where(Classroom.name == name)) is None, 'QA cohort already exists')
                baseline = capture_history(session)
            write(run / 'baseline.json', baseline)
            flow.login(['OPERATOR', 'LEARNER'])
            created = http.request('POST', '/admin/classes', token=flow.tokens['OPERATOR'], expected=201, body={
                'program_id': defines['QA_DYNAMIC_PROGRAM_ID'], 'course_id': defines['QA_DYNAMIC_COURSE_ID'],
                'teacher_id': defines['QA_DYNAMIC_AUTHOR_ID'], 'name': name,
                'start_date': '2026-10-01', 'end_date': '2027-12-31', 'status': 'active'})
            state = {'run_id': args.run_id, 'class_id': created['id'], 'course_id': created['course_id'],
                'version_id': created['course_version_id'], 'name': name, 'learner_id': learner, 'status': 'cohort_created'}
            write(state_path, state)
            http.request('POST', f"/admin/classes/{state['class_id']}/students/{learner}", token=flow.tokens['OPERATOR'], expected=201)
            context = flow.read('LEARNER', f"/classes/{state['class_id']}/learning-context")
            state.update(status='prepared', context=context['context'], initial_progress=context['progress'])
            write(state_path, state)
            client = {k: defines[k] for k in ['TUTOR_ENVIRONMENT', 'TUTOR_API_URL', 'TUTOR_STAGING_API_URL', 'LEARNING_CONTEXT_ENABLED', 'DURABLE_LEARNING_OUTBOX_ENABLED']}
            client.update(DYNAMIC_QA_ISOLATED_PACKAGE='true', DYNAMIC_QA_RUN_ID=args.run_id,
                JOURNEY_TRACEABILITY_ENABLED='true', QA_ACCESS_RUN_ID=args.run_id,
                QA_ACCESS_COHORT_ID=state['class_id'], QA_ACCESS_COURSE_ID=state['course_id'],
                QA_ACCESS_VERSION_ID=state['version_id'], QA_ACCESS_CLASS_NAME=name)
            for target, persona in [('STUDENT', 'LEARNER'), ('OUTSIDER', 'PUBLISHER')]:
                for field in ['ID', 'CPF', 'PASSWORD']:
                    client[f'QA_{target}_{field}'] = defines[f'QA_DYNAMIC_{persona}_{field}']
            write(run / 'defines.json', client)
        else:
            state = json.loads(state_path.read_text(encoding='utf-8'))
            require(state['run_id'] == args.run_id and state['name'] == name and state['learner_id'] == learner, 'Fixture identity mismatch')
            baseline = json.loads((run / 'baseline.json').read_text(encoding='utf-8'))
            if args.phase == 'revoke':
                require(state['status'] == 'prepared', 'Never repeat revocation automatically')
                with Session(database.engine) as session:
                    cohort = session.get(Classroom, state['class_id'])
                    link = session.get(ClassEnrollment, (state['class_id'], learner))
                    require(cohort is not None and cohort.name == name and cohort.course_id == state['course_id'], 'Cohort ownership mismatch')
                    require(link is not None and link.status == 'active' and link.context_id == state['context']['enrollment_id'], 'Unexpected learner binding')
                    membership = session.get(CohortMembership, link.membership_id)
                    require(membership is not None and membership.class_id == cohort.id and membership.user_id == learner and membership.status == 'active', 'Unexpected membership')
                    link.status = membership.status = 'inactive'
                    session.commit()
                state.update(status='revoked_for_qa', revocation_method='Scoped fixture update; no administrative revocation endpoint')
                write(state_path, state)
            else:
                require(state['status'] == 'revoked_for_qa', 'Revocation fixture missing')
        with read_session(database.engine) as session:
            final = capture_history(session)
            require_preserved_history(baseline, final)
        evidence = {'status': 'passed', 'phase': args.phase, 'run_id': args.run_id,
            'class_id': state['class_id'], 'course_id': state['course_id'], 'version_id': state['version_id'],
            'fixture_status': state['status'], 'initial_events_preserved': len(baseline['events']),
            'initial_core_records_preserved': sum(len(v) for v in baseline['core'].values()),
            'requests': http.requests, 'production_changed': False, 'verified_at': datetime.now(timezone.utc).isoformat()}
        evidence_path = ROOT / 'docs/production/evidence' / f'classroom-access-{args.run_id}-{args.phase}.json'
        require(not evidence_path.exists(), 'Never overwrite evidence')
        write(evidence_path, evidence)
        print(json.dumps({'status': 'passed', 'phase': args.phase, 'run_id': args.run_id}))
    finally:
        database.dispose()


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        raise SystemExit(f'QA fixture stopped ({type(exc).__name__}); preserve run files; no automatic retry') from None
