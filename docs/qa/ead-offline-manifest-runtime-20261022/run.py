"""Disposable native WP/LP/MariaDB acceptance. Never connects to production.

Prerequisites are cached official images/archive/phar with the exact pins below.
Only resources created with this invocation's unique label are removed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tarfile
import tempfile
import time

WP = 'wordpress@sha256:10f35d0dd608ee9f907c22aa3f2bbb9ac64fee72726503e53f2afd298d2a09f1'
DB = 'mariadb@sha256:250e1609e93c0e6aecf64bfbab2d84d5e89d2481540fe77447ff6c855c3b1873'
LP_SHA = '56f80d7981611c05723c7b45134f2b6d25d8214c52b07c5b338df86dbae6b441'
CLI_SHA = 'ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c'


def command(*args, check=True):
    result = subprocess.run(args, capture_output=True, text=True, timeout=90)
    if check and result.returncode:
        # Do not print argv: fixture env/password arguments may be present.
        raise RuntimeError(f'Command failed ({args[0]}, rc={result.returncode}): {result.stderr[:1400]} {result.stderr[-500:]} {result.stdout[:500]}')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--diagnose', action='store_true')
    parser.add_argument('--diagnose-republish', action='store_true')
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    fixture = Path(__file__).resolve().with_name('fixture.php')
    archive, cli = args.cache / 'learnpress-4.3.6-built.tar.gz', args.cache / 'wp-cli.phar'
    for path, sha in ((archive, LP_SHA), (cli, CLI_SHA)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != sha:
            raise RuntimeError(f'Cached prerequisite digest mismatch: {path.name}')
    run = 'tds-offline-336-' + secrets.token_hex(5)
    label = 'tds.qa.run=' + run
    resources = []
    receipt = {'run': run, 'source_sha': command('git', '-C', str(repo), 'rev-parse', 'HEAD').stdout.strip(),
               'harness_sha256': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (Path(__file__), fixture)},
               'learnpress_built_archive_sha256': LP_SHA,
               'learnpress_source_archive_sha256': '79c9607437a81fd85ae2fd2dcf8902c4607b7d4667659421672b5506329cf715',
               'images': {'wordpress': WP, 'database': DB}, 'learnpress_commit': '84edad0aea35bcac86018a825d0a42f8188d6ead',
               'cases': [], 'boundary': 'Real WordPress/LearnPress/MariaDB, synthetic records/bytes, internal Docker HTTP; no TLS, browser form or Android proof',
               'result': 'FAIL', 'cleanup': {}}
    wp_name, db_name = run + '-wp', run + '-db'

    def verify(ok, name):
        receipt['cases'].append({'case': name, 'result': 'PASS' if ok else 'FAIL'})
        print(('PASS ' if ok else 'FAIL ') + name, flush=True)
        if not ok:
            raise RuntimeError(name)

    def docker_create(kind, name, *extra):
        command('docker', kind, 'create', '--label', label, *extra, name)
        resources.append((kind, name))

    def wp(*extra):
        return command('docker', 'exec', wp_name, 'php', '/tmp/wp-cli.phar', '--allow-root', '--path=/var/www/html', *extra).stdout

    def action(name):
        output = wp('eval-file', '/qa/fixture.php', name)
        for line in reversed(output.splitlines()):
            if line.startswith('{"qa":'):
                return json.loads(line)['qa']
        raise RuntimeError('Missing fixture JSON: ' + output[-2000:])

    def http(route, method='GET', etag=None):
        cmd = ['docker', 'exec', wp_name, 'curl', '--noproxy', '*', '-sS', '--max-time', '15', '-i',
               '-H', 'Host: ead.ipexdesenvolvimento.cloud', '-H', 'X-Forwarded-Proto: https']
        if method == 'HEAD': cmd += ['--head']
        if etag: cmd += ['-H', 'If-None-Match: ' + etag]
        cmd += ['http://127.0.0.1' + (route if route.startswith('/wp-content/') else '/?rest_route=' + route)]
        raw = command(*cmd).stdout
        header, _, body = raw.partition('\n\n')
        status = int(header.splitlines()[0].split()[1])
        headers = dict(line.split(': ', 1) for line in header.splitlines()[1:] if ': ' in line)
        headers = {key.lower(): value for key, value in headers.items()}
        return status, headers, body

    try:
        with tempfile.TemporaryDirectory(prefix='tds-offline-prerequisites-') as temp:
            extracted = Path(temp) / 'learnpress'
            extracted.mkdir()
            # Official pinned archive only; Python's data filter rejects escaping links.
            with tarfile.open(archive) as tar:
                prefix = tar.getmembers()[0].name.split('/')[0] + '/'
                for member in tar.getmembers():
                    if member.name.startswith(prefix) and member.name != prefix:
                        member.name = member.name[len(prefix):]
                        tar.extract(member, extracted, filter='data')
            docker_create('network', run, '--internal')
            docker_create('volume', run + '-dbdata')
            docker_create('volume', run + '-wpdata')
            db_password, admin_password = secrets.token_hex(24), secrets.token_hex(24)
            command('docker', 'run', '-d', '--name', db_name, '--label', label, '--network', run,
                    '--mount', f'type=volume,src={run}-dbdata,dst=/var/lib/mysql',
                    '-e', 'MARIADB_ROOT_PASSWORD=' + db_password, '-e', 'MARIADB_DATABASE=tds_synthetic', DB)
            resources.append(('container', db_name))
            for _ in range(50):
                if command('docker', 'exec', db_name, 'healthcheck.sh', '--connect', '--innodb_initialized', check=False).returncode == 0:
                    break
                time.sleep(1)
            else: raise RuntimeError('Disposable database readiness timeout')
            extra = "define('WP_HOME','https://ead.ipexdesenvolvimento.cloud'); define('WP_SITEURL','https://ead.ipexdesenvolvimento.cloud'); define('WP_ENVIRONMENT_TYPE','local'); define('WP_HTTP_BLOCK_EXTERNAL',true); define('DISABLE_WP_CRON',true); define('AUTOMATIC_UPDATER_DISABLED',true);"
            command('docker', 'run', '-d', '--name', wp_name, '--label', label, '--network', run,
                    '--mount', f'type=volume,src={run}-wpdata,dst=/var/www/html',
                    '--mount', f'type=bind,src={fixture.parent},dst=/qa,readonly',
                    '-e', 'WORDPRESS_DB_HOST=' + db_name, '-e', 'WORDPRESS_DB_USER=root',
                    '-e', 'WORDPRESS_DB_PASSWORD=' + db_password, '-e', 'WORDPRESS_DB_NAME=tds_synthetic',
                    '-e', 'WORDPRESS_CONFIG_EXTRA=' + extra, '-e', 'TDS_OFFLINE_RUNTIME_QA=' + run, WP)
            resources.append(('container', wp_name))
            command('docker', 'cp', str(cli), wp_name + ':/tmp/wp-cli.phar')
            for _ in range(40):
                if command('docker', 'exec', wp_name, 'test', '-f', '/var/www/html/wp-config.php', check=False).returncode == 0:
                    break
                time.sleep(1)
            else: raise RuntimeError('WordPress core readiness timeout')
            wp('core', 'install', '--url=https://ead.ipexdesenvolvimento.cloud', '--title=Synthetic offline QA',
               '--admin_user=qa_admin', '--admin_email=qa-admin@qa-synthetic.test', '--admin_password=' + admin_password, '--skip-email')
            command('docker', 'cp', str(extracted), wp_name + ':/var/www/html/wp-content/plugins/learnpress')
            command('docker', 'cp', str(repo / 'wordpress/tds-learnpress-editorial'), wp_name + ':/var/www/html/wp-content/plugins/tds-learnpress-editorial')
            # docker cp retains this cloud workspace's private 0700/0600 modes.
            # Normalize only the run-owned plugin copies, never host sources.
            for plugin in ('learnpress', 'tds-learnpress-editorial'):
                target = '/var/www/html/wp-content/plugins/' + plugin
                command('docker', 'exec', wp_name, 'find', target, '-type', 'd', '-exec', 'chmod', '0755', '{}', '+')
                command('docker', 'exec', wp_name, 'find', target, '-type', 'f', '-exec', 'chmod', '0644', '{}', '+')
                entry = target + ('/learnpress.php' if plugin == 'learnpress' else '/tds-learnpress-editorial.php')
                verify(command('docker', 'exec', '--user', 'www-data', wp_name, 'test', '-r', entry, check=False).returncode == 0,
                       'Apache user can read copied plugin ' + plugin)
            wp('plugin', 'activate', 'learnpress', 'tds-learnpress-editorial')
            hashes = {}
            for path in (repo / 'wordpress/tds-learnpress-editorial').rglob('*.php'):
                relative = str(path.relative_to(repo / 'wordpress/tds-learnpress-editorial'))
                expected = hashlib.sha256(path.read_bytes()).hexdigest()
                observed = command('docker', 'exec', wp_name, 'sha256sum', '/var/www/html/wp-content/plugins/tds-learnpress-editorial/' + relative).stdout.split()[0]
                verify(expected == observed, 'exact plugin source ' + relative)
                hashes[relative] = expected
            receipt['plugin_hashes'] = hashes
            seed = action('seed')
            receipt['versions'] = {k: seed[k] for k in ('wordpress', 'learnpress')}
            ids = seed['ids']
            verify(seed['rights'] == '1' and seed['public'] == '1' and seed['parent_status'] == 'publish', 'real LP save hook source approval persisted')
            verify(all(value['count'] == 0 for value in seed['academic'].values()), 'no academic records seeded')
            route = f"/tds-learning/v1/courses/{ids['course']}/lessons/{ids['lesson']}/offline-manifest"
            native = http(f"/learnpress/v1/courses/{ids['course']}")
            receipt['native_diagnostic'] = {'status': native[0], 'headers': native[1], 'body_prefix': native[2][:1600]}
            if args.diagnose:
                receipt['internal_diagnostic'] = action('diagnose')
                index = http('/')
                receipt['http_namespaces'] = json.loads(index[2]).get('namespaces')
                receipt['apache_diagnostic'] = command('docker', 'logs', wp_name, check=False).stderr[-3500:]
                receipt['result'] = 'BLOCKED_DIAGNOSTIC_ONLY'
                return 2
            verify(native[0] == 200 and len(json.loads(native[2])['sections']) == 1, 'native LearnPress REST curriculum, no stub')
            verify(http(route)[0] == 404, 'unmeasured native lesson fails closed')
            verify(action('prepare')['asset_count'] == 2, 'local byte preparation persists measured MP4 and VTT')
            before = action('snapshot')
            status, headers, body = http(route)
            verify(status == 200, 'anonymous actual HTTP manifest 200')
            manifest = json.loads(body)
            receipt['manifest'] = manifest
            verify(set(manifest) == {'schema_version','course_id','lesson_id','mobile_content','rights_approved','mp4','vtt','content_revision'}, 'exact Flutter JSON keys from real WP')
            verify(manifest['course_id'] == ids['course'] and manifest['lesson_id'] == ids['lesson'], 'native course lesson identity preserved')
            verify(manifest['mp4']['sha256'] == hashlib.sha256(b'synthetic MP4 bytes - not a playback fixture').hexdigest(), 'actual MP4 byte digest')
            verify(manifest['vtt']['length'] == 37 and manifest['mp4']['length'] == 44, 'actual byte lengths')
            for kind in ('mp4', 'vtt'):
                path = manifest[kind]['url'].removeprefix('https://ead.ipexdesenvolvimento.cloud')
                asset_status, _, asset_body = http(path)
                verify(asset_status == 200 and hashlib.sha256(asset_body.encode()).hexdigest() == manifest[kind]['sha256'],
                       'actual HTTP asset bytes match manifest ' + kind)
            verify(headers.get('cache-control') == 'no-store' and headers.get('x-content-type-options') == 'nosniff', 'response privacy cache headers')
            verify(http(route, 'HEAD')[0] == 200 and http(route, 'HEAD')[2] == '', 'HEAD no body on real WP transport')
            etag = headers['etag']
            verify(http(route, etag=etag)[0] == 304, 'strong ETag revalidation')
            verify(http(route, etag='W/' + etag)[0] == 304, 'weak ETag revalidation')
            verify(http(route, etag='"different"')[0] == 200, 'unknown ETag full response')
            after = action('snapshot')
            verify(before == after, 'GET HEAD conditional requests do not mutate integrity or academic data')
            action('revoke'); verify(http(route, etag=etag)[0] == 404, 'revocation beats old ETag')
            action('restore'); verify(http(route)[0] == 200, 'restored exact approved source remains readable')
            action('revise'); verify(http(route, etag=etag)[0] == 404, 'lesson revision invalidates measured record')
            action('prepare'); status, headers, _ = http(route)
            verify(status == 200 and headers['etag'] != etag, 'remeasure revision gives new ETag')
            etag = headers['etag']
            action('replace'); verify(http(route, etag=etag)[0] == 404, 'atomic media replacement invalidates measured record')
            action('prepare'); status, headers, _ = http(route)
            verify(status == 200 and headers['etag'] != etag, 'remeasure changed bytes gives new ETag')
            action('share'); verify(http(route)[0] == 404, 'multiple real LP parents denied')
            action('unshare'); verify(http(route)[0] == 200, 'unique parent restored')
            action('protect'); verify(http(route)[0] == 404, 'password-protected course denied')
            action('unprotect'); verify(http(route)[0] == 200, 'unprotected course restored')
            action('draft'); verify(http(route)[0] == 404, 'draft lesson denied')
            action('publish')
            reviewed = action('review')
            receipt['republish_review'] = reviewed
            verify(reviewed['course_status'] == 'publish' and reviewed['rights'] == '1', 'explicit administrator review restores published approved source')
            if args.diagnose_republish:
                receipt['republish_diagnostic'] = action('diagnose')
                receipt['result'] = 'BLOCKED_DIAGNOSTIC_ONLY'
                return 2
            # Native LP cleanup deletes section membership for non-published posts.
            # Publishing the orphan is not a new grant; only explicit editor
            # reattachment to the intended course can restore this boundary.
            verify(http(route)[0] == 404, 'republished orphan stays denied without course association')
            verify(action('reattach')['association_restored'] == 1, 'authorized native LP editor reattaches same lesson to original section')
            action('prepare'); verify(http(route)[0] == 200, 'reviewed reattached source can be remeasured')
            verify(action('snapshot')['academic'] == seed['academic'], 'academic tables unchanged after all editorial transitions')
            receipt['result'] = 'PASS'
    except Exception as error:
        receipt['error'] = str(error)
        print('FAIL ' + str(error), flush=True)
    finally:
        for kind, name in reversed(resources):
            inspect = command('docker', kind, 'inspect', name, '--format', '{{json .Labels}}' if kind != 'container' else '{{json .Config.Labels}}', check=False)
            if inspect.returncode or json.loads(inspect.stdout or '{}').get('tds.qa.run') != run:
                receipt['cleanup'][name] = 'BLOCKED_LABEL_MISMATCH'
                receipt['result'] = 'FAIL'
                continue
            result = command('docker', kind, 'rm', *(('--force',) if kind == 'container' else ()), name, check=False)
            receipt['cleanup'][name] = 'PASS' if result.returncode == 0 else 'FAIL'
            if result.returncode: receipt['result'] = 'FAIL'
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(receipt, indent=2) + '\n')
        print('RESULT=' + receipt['result'] + ' receipt=' + str(args.output), flush=True)
    return 0 if receipt['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
