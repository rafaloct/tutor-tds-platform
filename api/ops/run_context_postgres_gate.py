"""Run the API golden path against a disposable, isolated PostgreSQL container.

Run on the staging host in an extracted API source directory. No existing
container, volume, database or env file is changed. This is NOT release approval.
"""
import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-image', required=True)
    parser.add_argument('--source-sha256', required=True)
    parser.add_argument('--slice', choices=('context', 'journey'), default='context')
    args = parser.parse_args()
    if len(args.source_sha256) != 64 or any(c not in '0123456789abcdef' for c in args.source_sha256):
        raise SystemExit('Invalid source digest')
    root = Path.cwd().resolve()
    if not (root / 'tests/test_context_golden_path.py').is_file():
        raise SystemExit('Run from extracted API source root')
    suffix = secrets.token_hex(5)
    network = f'tds-context-gate-{suffix}'
    database = f'tds-context-gate-db-{suffix}'
    image = f'tutor-tds-context-gate:{args.source_sha256[:12]}'
    password = secrets.token_hex(24)
    created = []

    def run(command, check=True):
        result = subprocess.run(command, capture_output=True, text=True)
        safe = (result.stdout + result.stderr).replace(password, '[REDACTED]')
        if result.returncode and check:
            raise RuntimeError(safe[-8000:])
        return result, safe

    dockerfile = root / 'Dockerfile.context-gate'
    dockerfile.write_text(
        f'FROM {args.base_image}\nWORKDIR /app\n'
        'COPY app ./app\nCOPY migrations ./migrations\nCOPY alembic.ini ./\n'
        'COPY tests ./tests\nCOPY pyproject.toml ./\n'
        'RUN python -m pip install --no-cache-dir pytest==9.1.1 httpx==0.28.1\n',
        encoding='utf-8',
    )
    try:
        run(['docker', 'build', '-f', str(dockerfile), '-t', image, '.'])
        print(json.dumps({'phase': 'image_built', 'image': image}), flush=True)
        run(['docker', 'network', 'create', '--internal', '--label', 'tds.purpose=context-gate', network])
        created.append(('network', network))
        run(['docker', 'run', '-d', '--name', database, '--network', network,
             '--label', 'tds.purpose=context-gate', '--memory', '256m', '--cpus', '1',
             '--tmpfs', '/var/lib/postgresql/data:rw',
             '-e', 'POSTGRES_DB=tds_context_gate', '-e', 'POSTGRES_USER=tds_context_gate',
             '-e', f'POSTGRES_PASSWORD={password}', 'postgres:16-alpine'])
        created.append(('container', database))
        for _ in range(30):
            result, _ = run(['docker', 'exec', database, 'pg_isready', '-U', 'tds_context_gate', '-d', 'tds_context_gate'], check=False)
            if result.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Isolated PostgreSQL did not become ready')
        test_files = ['tests/test_context_memberships.py', 'tests/test_context_golden_path.py'] if args.slice == 'context' else ['tests/test_journey_migration.py']
        result, output = run(['docker', 'run', '--rm', '--network', network,
            '--label', 'tds.purpose=context-gate', '--memory', '512m', '--cpus', '1',
            '-e', f'TDS_CONTEXT_GATE_DATABASE_URL=postgresql+psycopg://tds_context_gate:{password}@{database}:5432/tds_context_gate',
            '-e', f'TDS_CONTEXT_MIGRATION_DATABASE_URL=postgresql+psycopg://tds_context_gate:{password}@{database}:5432/tds_context_gate',
            '-e', f'TDS_JOURNEY_GATE_DATABASE_URL=postgresql+psycopg://tds_context_gate:{password}@{database}:5432/tds_context_gate',
            image, 'python', '-m', 'pytest', *test_files, '-o', 'addopts=', '-q', '--tb=short'])
        record = {'status': 'passed', 'source_sha256': args.source_sha256,
                  'image': image, 'base_image': args.base_image,
                  'tests': test_files, 'slice': args.slice, 'database': 'PostgreSQL 16, isolated tmpfs',
                  'limits': 'API TestClient plus real PostgreSQL; not mobile or public staging HTTP QA',
                  'output': output[-6000:]}
        (root / f'{args.slice}-postgres-gate.json').write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record), flush=True)
    finally:
        for kind, name in reversed(created):
            # Names were generated and registered by this invocation only.
            if kind == 'container':
                run(['docker', 'rm', '-f', name], check=False)
            else:
                run(['docker', 'network', 'rm', name], check=False)


if __name__ == '__main__':
    main()
