"""Temporary HTTPS staging cutover for Android QA; never changes existing containers.

Uses an already-tested image. Stop removes only resources recorded by this run
after verifying their ownership labels. Existing staging route resumes naturally.
"""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time

PURPOSE = 'tds-context-android-qa'
BASE_URL = 'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api'


def docker(*args, check=True, input=None):
    result = subprocess.run(['docker', *args], input=input, text=True, capture_output=True)
    if check and result.returncode:
        # Command and environment can contain synthetic secrets: do not echo them.
        raise RuntimeError(f'Docker operation failed ({args[0]}), exit {result.returncode}')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['start','status','stop'])
    parser.add_argument('--state-dir', required=True)
    parser.add_argument('--image')
    parser.add_argument('--journey', action='store_true', help='Enable traceability only on this disposable QA stack')
    args = parser.parse_args()
    root = Path(args.state_dir).resolve()
    if root.parent != Path('/opt') or not root.name.startswith('tutor-tds-context-android-qa-'):
        raise SystemExit('Use a dedicated /opt/tutor-tds-context-android-qa-* directory')
    state_file = root/'state.json'
    if args.action != 'start':
        state = json.loads(state_file.read_text())
        for resource in reversed(state['resources']):
            kind, name = resource['kind'], resource['name']
            result = docker(kind, 'inspect', name, check=False)
            if result.returncode: continue
            obj = json.loads(result.stdout)[0]
            labels = obj.get('Labels') if kind == 'network' else obj['Config']['Labels']
            if labels.get('tds.purpose') != PURPOSE or labels.get('tds.run') != state['run']:
                raise RuntimeError('Ownership mismatch; refusing action')
            if args.action == 'stop':
                docker(kind, 'rm', *(['-f'] if kind == 'container' else []), name)
            else:
                print(json.dumps({'kind':kind,'name':name,'state':obj.get('State',{}).get('Status','exists')}))
        if args.action == 'stop':
            state['status']='stopped'; state_file.write_text(json.dumps(state,indent=2)+'\n')
        return
    if state_file.exists(): raise SystemExit('State exists; inspect status, never restart blindly')
    if not args.image or not args.image.startswith('tutor-tds-context-gate:'):
        raise SystemExit('Use a verified context gate image')
    docker('image','inspect',args.image)
    existing = json.loads(docker('inspect','tutor-tds-staging-api-staging-1').stdout)[0]
    expected_rule = 'Host(`ead.ipexdesenvolvimento.cloud`) && PathPrefix(`/tutor-staging-api`)'
    assert existing['Config']['Labels']['traefik.http.routers.tutor-tds-api-staging.rule'] == expected_rule
    assert existing['Config']['Labels']['traefik.http.routers.tutor-tds-api-staging.priority'] == '210'
    run = secrets.token_hex(5)
    prefix = f'tds-context-android-{run}'
    database, api, network = prefix+'-db', prefix+'-api', prefix+'-internal'
    root.mkdir(mode=0o700, parents=False)
    root.chmod(0o700)
    state = {'run':run,'image':args.image,'status':'preparing','resources':[],
             'previous_staging_container':existing['Id'],'base_url':BASE_URL}
    def remember(kind,name):
        state['resources'].append({'kind':kind,'name':name})
        state_file.write_text(json.dumps(state,indent=2)+'\n');state_file.chmod(0o600)
    password = secrets.token_urlsafe(32)
    student_password, teacher_password = secrets.token_urlsafe(24), secrets.token_urlsafe(24)
    env = {'DATABASE_URL':f'postgresql+psycopg://tds_context_qa:{password}@{database}:5432/tds_context_staging_qa',
        'JWT_SECRET':secrets.token_urlsafe(48),'CPF_PEPPER':secrets.token_urlsafe(48),
        'PUBLIC_API_BASE_URL':BASE_URL,'LEARNING_CONTEXT_ENABLED':'true','PAYMENT_ADAPTER':'disabled',
        'QA_STUDENT_PASSWORD':student_password,'QA_TEACHER_PASSWORD':teacher_password}
    if args.journey:
        env.update(JOURNEY_TRACEABILITY_ENABLED='true', SHEETS_PSEUDONYM_SECRET=secrets.token_urlsafe(48))
    env_file=root/'api.env';env_file.write_text(''.join(f'{k}={v}\n' for k,v in env.items()));env_file.chmod(0o600)
    labels=['--label',f'tds.purpose={PURPOSE}','--label',f'tds.run={run}']
    docker('network','create','--internal',*labels,network);remember('network',network)
    docker('run','-d','--name',database,'--network',network,*labels,'--memory','256m','--cpus','1',
        '--tmpfs','/var/lib/postgresql/data:rw','-e','POSTGRES_DB=tds_context_staging_qa',
        '-e','POSTGRES_USER=tds_context_qa','-e',f'POSTGRES_PASSWORD={password}','postgres:16-alpine')
    remember('container',database)
    for _ in range(30):
        if docker('exec',database,'pg_isready','-U','tds_context_qa','-d','tds_context_staging_qa',check=False).returncode == 0: break
        time.sleep(1)
    else: raise RuntimeError('QA database not ready; inspect recorded resources')
    route={
      'traefik.enable':'true','traefik.docker.network':'dokploy-network',
      f'traefik.http.routers.{prefix}.rule':expected_rule,
      f'traefik.http.routers.{prefix}.priority':'211',
      f'traefik.http.routers.{prefix}.entrypoints':'websecure',
      f'traefik.http.routers.{prefix}.tls':'true',
      f'traefik.http.routers.{prefix}.tls.certresolver':'letsencrypt',
      f'traefik.http.routers.{prefix}.middlewares':prefix+'-strip',
      f'traefik.http.middlewares.{prefix}-strip.stripprefix.prefixes':'/tutor-staging-api',
      f'traefik.http.services.{prefix}.loadbalancer.server.port':'8000'}
    route_labels=[part for k,v in route.items() for part in ('--label',f'{k}={v}')]
    docker('run','-d','--name',api,'--network',network,*labels,*route_labels,'--memory','512m','--cpus','1',
        '--env-file',str(env_file),args.image,'sh','-c','alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000')
    remember('container',api)
    for _ in range(40):
        if docker('exec',api,'python','-c',"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=2)",check=False).returncode == 0: break
        time.sleep(1)
    else: raise RuntimeError('QA API not ready; inspect recorded resources')
    seed=(Path(__file__).parent/'seed_context_android.py').read_text()
    seeded=json.loads(docker('exec','-i',api,'python','-',input=seed).stdout)
    state.update(seeded)
    client={'TUTOR_ENVIRONMENT':'staging','TUTOR_API_URL':BASE_URL,'TUTOR_STAGING_API_URL':BASE_URL,
        'LEARNING_CONTEXT_ENABLED':'true','DURABLE_LEARNING_OUTBOX_ENABLED':'true',
        'QA_STUDENT_CPF':'12345678909','QA_TEACHER_CPF':'11144477735',
        'QA_STUDENT_PASSWORD':student_password,'QA_TEACHER_PASSWORD':teacher_password,
        'QA_STUDENT_ID':seeded['student_id'],'QA_TEACHER_ID':seeded['teacher_id']}
    if args.journey:
        client['JOURNEY_TRACEABILITY_ENABLED'] = 'true'
    client_file=root/'client-defines.json';client_file.write_text(json.dumps(client,indent=2)+'\n');client_file.chmod(0o600)
    # Only now expose the fully migrated, seeded API on the existing staging route.
    docker('network','connect','dokploy-network',api)
    # Refresh Docker discovery after attaching the routed network. Otherwise
    # Traefik can retain the private DB-network IP discovered at container start.
    # Only this run-owned API is restarted; existing services are untouched.
    docker('restart',api)
    state['status']='running';state_file.write_text(json.dumps(state,indent=2)+'\n')
    print(json.dumps({'status':'running','state_dir':str(root),'api':api,'database':database,'base_url':BASE_URL,
        'production_changed':False,'existing_staging_containers_changed':False}))


if __name__=='__main__': main()
