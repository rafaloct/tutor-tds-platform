"""Restore a read-only production dump into isolated PostgreSQL and rehearse.

Run on the VPS. Existing API, DB, networks, configuration and credentials are
never modified. Only newly generated, ownership-labelled containers are removed.
The protected backup and evidence remain for the promotion review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time


def legacy_projection_matches(old, new):
    """Permit additive object fields; preserve every legacy value and list order."""
    if isinstance(old, dict):
        return isinstance(new, dict) and all(
            key in new and legacy_projection_matches(value, new[key])
            for key, value in old.items()
        )
    if isinstance(old, list):
        return (isinstance(new, list) and len(old) == len(new)
                and all(legacy_projection_matches(a, b) for a, b in zip(old, new)))
    return type(old) is type(new) and old == new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-image', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'tutor-tds-(?:context-gate|candidate):[a-z0-9.-]+', args.candidate_image):
        raise SystemExit('Use an inspected Tutor candidate image')
    os.umask(0o077)
    run_id = secrets.token_hex(6)
    purpose = 'tds-production-rehearsal'
    prefix = f'tds-rehearsal-{run_id}'
    root = Path('/opt') / prefix
    root.mkdir(mode=0o700)
    resources = []
    secret_values = []

    def docker(*command, input=None, check=True):
        result = subprocess.run(['docker', *command], input=input, capture_output=True)
        if result.returncode and check:
            # Errors can contain URLs/DSNs. Persist a redacted diagnostic only.
            error = result.stderr.decode(errors='replace')[-5000:]
            for value in secret_values:
                error = error.replace(value, '[REDACTED]')
            (root/'error.txt').write_text(error)
            raise RuntimeError(f'Docker {command[0]} failed; see protected diagnostic')
        return result

    def inspect(name):
        return json.loads(docker('inspect', name).stdout)[0]

    def sql(container, query):
        return docker('exec', container, 'psql', '-U', 'tutor_tds', '-d',
                      'tutor_tds', '-At', '-v', 'ON_ERROR_STOP=1', '-c', query).stdout.decode().strip()

    def fingerprint(container, columns):
        data = {}
        for table, fields in columns.items():
            assert re.fullmatch(r'[a-z_]+', table)
            assert all(re.fullmatch(r'[a-z_]+', field) for field in fields)
            projection = ','.join('"'+field+'"' for field in fields)
            query = f'''SELECT count(*) || ':' || coalesce(md5(string_agg(row_to_json(x)::text,
                E'\\n' ORDER BY row_to_json(x)::text)), 'empty')
                FROM (SELECT {projection} FROM "{table}") x'''
            data[table] = sql(container, query)
        return data

    def get(container, path):
        # Probe inside the owned container: an internal Docker network deliberately
        # has no published ports or route to production services.
        script = ('import json,urllib.request; '
                  f'print(urllib.request.urlopen("http://127.0.0.1:8000{path}", '
                  'timeout=10).read().decode())')
        result = docker('exec', container, 'python', '-c', script, check=False)
        if result.returncode:
            raise RuntimeError('Isolated HTTP probe failed')
        return json.loads(result.stdout)

    def health(container):
        for _ in range(40):
            try:
                get(container, '/health')
                return
            except Exception:
                time.sleep(1)
        raise RuntimeError('Isolated API health check failed')

    def start_api(name, image):
        docker('run', '-d', '--name', name, '--network', network,
               '--label', f'tds.purpose={purpose}', '--label', f'tds.run={run_id}',
               '--memory', '512m', '--cpus', '1', '--env-file', str(root/'candidate.env'),
               image, 'uvicorn', 'app.main:app',
               '--host', '0.0.0.0', '--port', '8000', '--no-access-log')
        resources.append(('container', name))
        health(name)
        return name

    production_api = inspect('tutor-tds-api-api-1')
    production_db = inspect('tutor-tds-api-db-1')
    candidate_id = inspect(args.candidate_image)['Id']
    assert production_api['State']['Running'] and production_db['State']['Running']
    old_image = production_api['Image']
    columns_rows = json.loads(sql('tutor-tds-api-db-1', """SELECT json_agg(x) FROM
        (SELECT table_name, column_name FROM information_schema.columns
        WHERE table_schema='public' AND table_name != 'alembic_version'
        ORDER BY table_name, ordinal_position) x"""))
    columns = {}
    for row in columns_rows:
        columns.setdefault(row['table_name'], []).append(row['column_name'])
    before = fingerprint('tutor-tds-api-db-1', columns)
    revision_before = sql('tutor-tds-api-db-1', 'SELECT version_num FROM alembic_version')
    dump = docker('exec', 'tutor-tds-api-db-1', 'pg_dump', '-U', 'tutor_tds', '-d',
                  'tutor_tds', '--format=custom', '--no-owner', '--no-privileges').stdout
    assert len(dump) > 100
    backup = root/'production-before.dump'
    backup.write_bytes(dump)
    report = {'status':'running', 'run_id':run_id, 'state_dir':str(root),
              'candidate_image':args.candidate_image, 'candidate_image_id':candidate_id,
              'production_image_id':old_image, 'production_revision':revision_before,
              'backup':{'path':str(backup),'bytes':len(dump),'sha256':hashlib.sha256(dump).hexdigest()},
              'production_before':before, 'production_writes':False}
    (root/'evidence.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'phase':'backup_created', 'state_dir':str(root), 'production_revision':revision_before}), flush=True)
    network, database = prefix+'-internal', prefix+'-db'
    password = secrets.token_hex(24)
    secret_values.append(password)
    env = {'DATABASE_URL':f'postgresql+psycopg://tutor_tds:{password}@{database}:5432/tutor_tds',
           'JWT_SECRET':secrets.token_hex(32), 'CPF_PEPPER':secrets.token_hex(32),
           'SHEETS_PSEUDONYM_SECRET':secrets.token_hex(32),
           'LEARNING_CONTEXT_ENABLED':'true', 'JOURNEY_TRACEABILITY_ENABLED':'true',
           'PAYMENT_ADAPTER':'disabled', 'COMMERCIAL_SIMULATION_ENABLED':'false',
           'ALLOWED_ORIGINS':'https://cartilhas.ipexdesenvolvimento.cloud',
           'PUBLIC_API_BASE_URL':'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api'}
    secret_values.extend(env[k] for k in ('DATABASE_URL','JWT_SECRET','CPF_PEPPER','SHEETS_PSEUDONYM_SECRET'))
    (root/'candidate.env').write_text(''.join(f'{key}={value}\n' for key,value in env.items()))
    try:
        docker('network','create','--internal','--label',f'tds.purpose={purpose}','--label',f'tds.run={run_id}',network)
        resources.append(('network',network))
        docker('run','-d','--name',database,'--network',network,'--memory','512m',
               '--label',f'tds.purpose={purpose}','--label',f'tds.run={run_id}',
               '--tmpfs','/var/lib/postgresql/data:rw','-e','POSTGRES_DB=tutor_tds',
               '-e','POSTGRES_USER=tutor_tds','-e',f'POSTGRES_PASSWORD={password}','postgres:16-alpine')
        resources.append(('container',database))
        for _ in range(30):
            # The image's bootstrap server accepts only Unix sockets, then exits.
            # TCP readiness proves the final server is ready for the restore.
            if docker('exec',database,'pg_isready','-h','127.0.0.1','-U','tutor_tds','-d','tutor_tds',check=False).returncode==0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Isolated PostgreSQL not ready')
        docker('exec','-i',database,'pg_restore','--exit-on-error','--no-owner','--no-privileges',
               '-U','tutor_tds','-d','tutor_tds',input=dump)
        assert fingerprint(database,columns)==before, 'Restored source differs'
        report['restore_verified']=True
        docker('run','--rm','--network',network,'--env-file',str(root/'candidate.env'),
               '--label',f'tds.purpose={purpose}',args.candidate_image,'alembic','upgrade','head')
        after = fingerprint(database,columns)
        assert after==before, 'Migration changed original column data'
        report['clone_revision']=sql(database,'SELECT version_num FROM alembic_version')
        assert report['clone_revision']=='20261001_0020'
        report['original_columns_preserved']=True
        report['ia_course_version']=json.loads(sql(database,"""SELECT row_to_json(x) FROM
            (SELECT id,course_id,version_number,status FROM course_versions
             WHERE course_id='ia-cartilha' AND status='published') x"""))
        print(json.dumps({'phase':'restore_and_upgrade_passed','revision':report['clone_revision']}),flush=True)
        new_base=start_api(prefix+'-candidate',args.candidate_image)
        old_base=start_api(prefix+'-rollback',old_image)
        candidate_openapi=get(new_base,'/openapi.json')
        old_openapi=get(old_base,'/openapi.json')
        from ops.promotion_preflight import compare
        comparison=compare(old_openapi,candidate_openapi)
        assert not comparison['only_production'] and not comparison['aab_14_missing_in_candidate']
        new_courses=get(new_base,'/courses')
        old_courses=get(old_base,'/courses')
        report['catalog_additive_fields'] = sorted(set(new_courses['courses'][0]) - set(old_courses['courses'][0]))
        assert legacy_projection_matches(old_courses,new_courses), 'Legacy public course fields changed'
        report['public_catalog_compatible']=True
        report['old_image_runs_on_upgraded_database']=True
        report['openapi_comparison']=comparison
        assert fingerprint('tutor-tds-api-db-1',columns)==before, 'Source changed during rehearsal'
        assert sql('tutor-tds-api-db-1','SELECT version_num FROM alembic_version')==revision_before
        assert inspect('tutor-tds-api-api-1')['Id']==production_api['Id']
        report['production_unchanged']=True
        report['status']='passed'
    except Exception as error:
        report['status']='failed'
        report['failure_type']=type(error).__name__
        report['failure']=str(error)
        raise
    finally:
        for kind,name in reversed(resources):
            item=json.loads(docker(kind,'inspect',name).stdout)[0]
            labels=item.get('Labels',{}) if kind=='network' else item['Config']['Labels']
            assert labels.get('tds.purpose')==purpose and labels.get('tds.run')==run_id
            docker(kind,'rm',*(['-f'] if kind=='container' else []),name)
        report['isolated_resources_removed']=True
        (root/'evidence.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report),flush=True)


if __name__=='__main__':
    main()
