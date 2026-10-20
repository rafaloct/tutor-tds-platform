"""Explicitly authorized portal promotion; requires verified backup. Run on VPS only."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys

WP = 'compose-program-open-source-monitor-szkpni-wordpress-1'
SOURCE = Path('/etc/dokploy/compose/compose-program-open-source-monitor-szkpni/code/tds-child-theme')
PIN = {
    'functions.php': '3f896a20b7d0db98fe20eb6e211ab1785648d7ca322465fd77eb9fc99447c687',
    'pages/cadastro.php': '67e88421dbd1a0883ef5dbb24cd906b6e3082b6d5026c46461b70030d0a8088f',
    'includes/admin-cadastro-aluno.php': 'f34757104fb3f8b4d2d7491e8b3d144a43ba705c01d0ed42a58e4b16cce20e07',
}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def command(*args):
    return subprocess.check_output(args, stderr=subprocess.PIPE, text=True).strip()

def main():
    backup, bundle = map(Path, sys.argv[1:])
    assert command('hostname') == 'srv1533541'
    assert backup.parent == Path('/opt/tds-institutional-backups')
    restore = json.loads((backup / 'restore-equivalence.json').read_text())
    assert restore['status'] == 'PASS_DATA_AND_SCHEMA_EQUIVALENCE'
    assert restore['original_sha256'] == sha(backup / 'wordpress.sql')
    assert restore['restored_sha256'] == sha(backup / 'restored-retry.sql')
    assert all(sha(SOURCE / name) == value for name, value in PIN.items()), 'SOURCE_CHANGED'
    root = json.loads(command('docker', 'inspect', WP))[0]
    html = Path(next(m['Source'] for m in root['Mounts'] if m['Destination'] == '/var/www/html'))
    destination = html / 'wp-content/plugins/tds-learnpress-editorial'
    assert not destination.exists(), 'PLUGIN_ALREADY_PRESENT'
    assert not (SOURCE / 'includes/tds-registration-course.php').exists()
    candidate = backup / 'patched-theme-lf'
    assert not candidate.exists()
    shutil.copytree(SOURCE, candidate)
    patch_dir = bundle / 'wordpress/institutional-patches/issue-299'
    spec = importlib.util.spec_from_file_location('patch', patch_dir / 'prepare_patch.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    diff = module.prepare(candidate)
    assert hashlib.sha256(diff.encode()).hexdigest() == 'a7d67bb7884f967d7ae108abe39f8563fb4e9e8596ba0d6b106fcec693d61c45'
    plugin = bundle / 'wordpress/tds-learnpress-editorial'
    manifest = json.loads((bundle / 'runtime-hashes.json').read_text())
    for relative, expected in manifest.items():
        assert sha(bundle / relative) == expected, relative
    for file in [candidate / 'functions.php', candidate / 'pages/cadastro.php', candidate / 'includes/tds-registration-course.php']:
        subprocess.run(['docker', 'run', '--rm', '--network', 'none', '--entrypoint', 'php', '-v', f'{file}:/check.php:ro', root['Image'], '-l', '/check.php'], check=True, stdout=subprocess.DEVNULL)
    # Capture precise rollback files, never restore the whole live DB after real registrations.
    rollback = backup / 'promotion-rollback'
    rollback.mkdir(mode=0o700)
    for name in ('functions.php', 'pages/cadastro.php'):
        target = rollback / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE / name, target)
    old_plugins = command('docker', 'exec', WP, 'wp', '--allow-root', '--skip-plugins', '--skip-themes', 'option', 'get', 'active_plugins', '--format=json')
    (rollback / 'active-plugins.json').write_text(old_plugins)
    touched = []
    try:
        destination.mkdir(mode=0o755)
        destination.chmod(0o755)
        for relative in manifest:
            if not relative.startswith('wordpress/tds-learnpress-editorial/'):
                continue
            target = destination / Path(relative).relative_to('wordpress/tds-learnpress-editorial')
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            target.parent.chmod(0o755)
            shutil.copyfile(bundle / relative, target)
            target.chmod(0o644)
        # Helper first; handler last. No QA files or sanitized credentials deployed.
        for name in ('includes/tds-registration-course.php', 'pages/cadastro.php', 'functions.php'):
            target = SOURCE / name
            staging = target.with_name(target.name + '.tds-promoting')
            assert not staging.exists()
            shutil.copyfile(candidate / name, staging)
            staging.chmod(0o644)
            if target.exists():
                os.chown(staging, target.stat().st_uid, target.stat().st_gid)
            else:
                os.chown(staging, 33, 33)
            os.replace(staging, target)
            touched.append(name)
        command('docker', 'exec', WP, 'wp', '--allow-root', 'plugin', 'activate', 'tds-learnpress-editorial')
        assert command('docker', 'exec', WP, 'wp', '--allow-root', 'plugin', 'get', 'tds-learnpress-editorial', '--field=status') == 'active'
        result = {'status': 'DEPLOYED_PENDING_HTTP', 'plugin_version': '0.1.0', 'source_sha': '16a57e66303e2b7bea2aef9d179976283c4e933f',
                  'theme_before': PIN, 'theme_after': {n: sha(SOURCE / n) for n in touched},
                  'plugin_hashes': {str(p.relative_to(destination)): sha(p) for p in destination.rglob('*') if p.is_file()},
                  'backup': str(backup), 'no_editorial_authorizations_changed': True}
        (backup / 'promotion.json').write_text(json.dumps(result, indent=2))
        print(json.dumps(result))
    except Exception:
        subprocess.run(['docker', 'exec', WP, 'wp', '--allow-root', '--skip-themes', 'plugin', 'deactivate', 'tds-learnpress-editorial'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for name in reversed(touched):
            if (rollback / name).exists():
                shutil.copy2(rollback / name, SOURCE / name)
            elif name == 'includes/tds-registration-course.php':
                (SOURCE / name).unlink()
        # Preserve inactive plugin for inspection; no recursive deletion.
        print('PROMOTION_FAILED_THEME_ROLLED_BACK; plugin retained inactive')
        raise

if __name__ == '__main__':
    main()
