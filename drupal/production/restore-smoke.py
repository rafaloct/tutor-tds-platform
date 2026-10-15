#!/usr/bin/env python3
"""Explicit, isolated live-copy rehearsal. Does not decrypt an offsite backup."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import stat
import subprocess
import tarfile
import tempfile
import time
import urllib.request
import uuid

REG = Path('/etc/dokploy/tds-drupal-ops/source/registration.json')
LIMIT = 16 * 1024 * 1024
HOST = 'portal.ipexdesenvolvimento.cloud'
DB_IMAGE = 'mariadb:11.8@sha256:6422478cb8e159f080fb1d8ccf65101e26fe51385787fde7d16c3b165a331f15'


class Failure(Exception):
    pass


def command(args, stage, data=None, limit=LIMIT, timeout=120):
    # Spooling bounded stdout avoids an unbounded communicate() allocation.
    available = os.statvfs('/dev/shm')
    if available.f_bavail * available.f_frsize < (len(data) if data else 0) + limit + 2 * 1024 * 1024:
        raise Failure('tmpfs_capacity')
    with tempfile.TemporaryFile(dir='/dev/shm') as output, tempfile.TemporaryFile(dir='/dev/shm') as error, tempfile.TemporaryFile(dir='/dev/shm') as input_file:
        if data:
            input_file.write(data)
        input_file.seek(0)
        with subprocess.Popen(args, stdin=input_file, stdout=output, stderr=error) as process:
            end = time.monotonic() + timeout
            while process.poll() is None:
                if output.tell() > limit or error.tell() > 1024 * 1024 or time.monotonic() > end:
                    process.kill()
                    process.wait()
                    raise Failure(stage)
                time.sleep(.1)
            if process.returncode or output.tell() > limit:
                raise Failure(stage)
        output.seek(0)
        return output.read(limit + 1)


def private_read(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o077 or info.st_size > LIMIT:
        raise Failure('private_configuration')
    return path.read_bytes()


def dotenv(data):
    values = {}
    for line in data.decode().splitlines():
        if not line or line.startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key) or key in values:
            raise Failure('environment_format')
        if len(value) >= 2 and value[0] == value[-1] == "'":
            value = value[1:-1]
        elif any(c in value for c in "'\"$\\"):
            raise Failure('environment_format')
        if '\n' in value or '\r' in value or '\x00' in value:
            raise Failure('environment_format')
        values[key] = value
    return values


def source(project, service):
    ids = command(['docker', 'ps', '--filter', f'label=com.docker.compose.project={project}', '--filter', f'label=com.docker.compose.service={service}', '--format', '{{.ID}}'], 'source_lookup', limit=4096).decode().split()
    if len(ids) != 1 or not re.fullmatch('[a-f0-9]{12,64}', ids[0]):
        raise Failure('source_count')
    info = json.loads(command(['docker', 'inspect', '--format', '{"image":{{json .Image}},"labels":{{json .Config.Labels}},"mounts":{{json .Mounts}}}', ids[0]], 'source_identity', limit=65536))
    if info['labels'].get('com.docker.compose.project') != project or info['labels'].get('com.docker.compose.service') != service:
        raise Failure('source_identity')
    expected = ['/var/lib/mysql'] if service == 'db' else ['/var/www/html/web/sites/default/files', '/var/www/private']
    if any(not any(m['Destination'] == target and m['Type'] == 'volume' and m.get('Name', '').startswith(project + '_') for m in info['mounts']) for target in expected):
        raise Failure('source_mount_identity')
    return ids[0], info['image']


def sql(container, statement):
    return command(['docker', 'exec', '-i', container, 'sh', '-ec', 'export MYSQL_PWD="$MARIADB_PASSWORD"; exec mariadb --batch --skip-column-names --user="$MARIADB_USER" "$MARIADB_DATABASE"'], 'database_query', statement.encode())


def counts(container):
    tables = sql(container, 'SHOW FULL TABLES WHERE Table_type="BASE TABLE";').decode().splitlines()
    names = [line.split('\t')[0] for line in tables]
    if not names or len(names) > 500 or any(not re.fullmatch('[A-Za-z0-9_]+', name) for name in names):
        raise Failure('table_names')
    query = ' UNION ALL '.join(f"SELECT '{name}', COUNT(*) FROM `{name}`" for name in names) + ';'
    result = {}
    for line in sql(container, query).decode().splitlines():
        name, count = line.split('\t')
        result[name] = int(count)
    if set(result) != set(names):
        raise Failure('table_count_result')
    return result


def file_hashes(payload):
    hashes = {}
    with tarfile.open(fileobj=io.BytesIO(payload), mode='r:') as archive:
        for member in archive:
            normalized = member.name.removeprefix('./')
            if member.name.startswith('/') or '..' in Path(member.name).parts or member.issym() or member.islnk() or not (member.isfile() or member.isdir()):
                raise Failure('archive_unsafe_entry')
            if member.isfile():
                if member.size > LIMIT or normalized in hashes:
                    raise Failure('archive_size_or_duplicate')
                with archive.extractfile(member) as content:
                    hashes[normalized] = hashlib.sha256(content.read(LIMIT + 1)).hexdigest()
    return hashes


def request(path):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    req = urllib.request.Request('http://127.0.0.1:18089' + path, headers={'Host': HOST})
    with opener.open(req, timeout=10) as response:
        return response.status, response.read(1024 * 1024)


def run():
    if os.geteuid() != 0:
        raise Failure('root_required')
    mounts = Path('/proc/mounts').read_text().splitlines()
    if not any(line.split()[1:3] == ['/dev/shm', 'tmpfs'] for line in mounts):
        raise Failure('tmpfs_required')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 18089))
    r = json.loads(private_read(REG))
    project = r.get('appName', '')
    if not re.fullmatch('[a-z0-9][a-z0-9_-]{1,99}', project) or not re.fullmatch('sha256:[a-f0-9]{64}', r.get('imageRef', '')):
        raise Failure('registration')
    env = dotenv(private_read(Path('/etc/dokploy/compose') / project / 'code/.env'))
    salt = env.get('DRUPAL_HASH_SALT', '')
    if not salt or env.get('DRUPAL_IMAGE_REF') != r['imageRef']:
        raise Failure('environment_identity')
    prod_db, _ = source(project, 'db')
    prod_web, image = source(project, 'web')
    if image != r['imageRef']:
        raise Failure('source_image')
    # Bound total duration even if a database unexpectedly contains many tables.
    before = counts(prod_db)
    if len(before) > 500:
        raise Failure('table_count_limit')
    dump = command(['docker', 'exec', prod_db, 'sh', '-ec', 'export MYSQL_PWD="$MARIADB_PASSWORD"; exec mariadb-dump --user="$MARIADB_USER" --single-transaction --quick --skip-lock-tables --hex-blob --no-tablespaces "$MARIADB_DATABASE"'], 'live_dump')
    files = {}
    for target in ['/var/www/html/web/sites/default/files', '/var/www/private']:
        payload = command(['docker', 'exec', prod_web, 'tar', '-C', target, '-cf', '-', '.'], 'live_files')
        files[target] = (payload, file_hashes(payload))
    if counts(prod_db) != before:
        raise Failure('source_changed_during_capture')
    base = 'tds-drupal-restore-210-' + uuid.uuid4().hex
    network, db_name, web_name = base + '-network', base + '-db', base + '-web'
    created = []
    directory = tempfile.mkdtemp(prefix='tds-drupal-restore-', dir='/dev/shm')
    try:
        os.chmod(directory, 0o700)
        password = secrets.token_hex(48)
        db_env = Path(directory) / 'db.env'
        web_env = Path(directory) / 'web.env'
        common = {'MARIADB_DATABASE': 'restore_test', 'MARIADB_USER': 'restore_test', 'MARIADB_PASSWORD': password, 'MARIADB_ROOT_PASSWORD': secrets.token_hex(48)}
        web_values = {'DRUPAL_ENVIRONMENT': 'production', 'DRUPAL_IMAGE_REF': image, 'DRUPAL_DB_HOST': 'restore-db', 'DRUPAL_DB_NAME': 'restore_test', 'DRUPAL_DB_USER': 'restore_test', 'DRUPAL_DB_PASSWORD': password, 'DRUPAL_HASH_SALT': salt, 'DRUPAL_TRUSTED_HOSTS': '^portal\\.ipexdesenvolvimento\\.cloud$', 'DRUPAL_PRIVATE_PATH': '/var/www/private', 'TUTOR_API_BASE_URL': '', 'TDS_ACADEMIC_SESSION_ENABLED': 'false'}
        for file, values in [(db_env, common), (web_env, web_values)]:
            descriptor = os.open(file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, 'w') as output:
                output.write(''.join(f'{k}={v}\n' for k, v in values.items()))
        command(['docker', 'network', 'create', '--internal', network], 'network_create'); created.append(('network', network))
        command(['docker', 'create', '--name', db_name, '--network', network, '--network-alias', 'restore-db', '--memory', '1g', '--cpus', '1', '--env-file', str(db_env), '--tmpfs', '/var/lib/mysql:rw,size=512m', DB_IMAGE], 'db_create'); created.append(('container', db_name))
        command(['docker', 'start', db_name], 'db_start')
        for attempt in range(60):
            try:
                command(['docker', 'exec', db_name, 'healthcheck.sh', '--connect', '--innodb_initialized'], 'db_ready', timeout=5)
                break
            except Failure:
                if attempt == 59:
                    raise
                time.sleep(1)
        command(['docker', 'exec', '-i', db_name, 'sh', '-ec', 'export MYSQL_PWD="$MARIADB_PASSWORD"; exec mariadb --user="$MARIADB_USER" "$MARIADB_DATABASE"'], 'import', dump)
        restored = counts(db_name)
        if before != restored:
            raise Failure('database_counts_differ')
        command(['docker', 'create', '--name', web_name, '--network', network, '--memory', '1g', '--cpus', '1', '--publish', '127.0.0.1:18089:80', '--env-file', str(web_env), '--tmpfs', '/var/www/html/web/sites/default/files:rw,size=64m,uid=33,gid=33', '--tmpfs', '/var/www/private:rw,size=64m,uid=33,gid=33', image], 'web_create'); created.append(('container', web_name))
        command(['docker', 'start', web_name], 'web_start')
        for target, (payload, hashes) in files.items():
            command(['docker', 'exec', '-i', web_name, 'tar', '-C', target, '-xf', '-'], 'restore_files', payload)
            copied = command(['docker', 'exec', web_name, 'tar', '-C', target, '-cf', '-', '.'], 'verify_files')
            if file_hashes(copied) != hashes:
                raise Failure('file_hashes_differ')
        # Discard copied render/catalog caches so home exercises disabled upstream.
        command(['docker', 'exec', '--user', 'www-data', '-w', '/var/www/html', web_name, 'vendor/bin/drush', 'cache:rebuild'], 'restore_cache_rebuild')
        for attempt in range(30):
            try:
                status, body = request('/health')
                health = json.loads(body)
                if status == 200 and health.get('environment') == 'production' and health.get('database') == 'up':
                    break
            except Exception:
                pass
            if attempt == 29:
                raise Failure('health')
            time.sleep(1)
        if request('/')[0] != 200:
            raise Failure('home')
        return {'status': 'LIVE_COPY_RESTORE_VERIFIED', 'tables': len(restored), 'rows': sum(restored.values()), 'files': sum(len(v[1]) for v in files.values()), 'health': 'production/up', 'homeStatus': 200, 'upstreamDisabled': True, 'filesAtomic': False, 'offsiteDecryptVerified': False}
    finally:
        cleanup_failed = False
        for kind, name in reversed(created):
            try:
                command(['docker', 'rm', '-f', name] if kind == 'container' else ['docker', 'network', 'rm', name], 'cleanup', timeout=30)
            except Exception:
                cleanup_failed = True
        shutil.rmtree(directory)
        if cleanup_failed:
            raise Failure('cleanup_requires_attention')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    if not args.run:
        print(json.dumps({'status': 'PLAN_ONLY', 'productionWrites': False, 'offsiteDecryptVerified': False}))
        return 0
    try:
        result = run()
        print(json.dumps(result))
        return 0
    except Exception as error:
        print(json.dumps({'status': 'RESTORE_REHEARSAL_FAILED', 'stage': str(error) if isinstance(error, Failure) else 'local_or_contract_error', 'offsiteDecryptVerified': False}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
