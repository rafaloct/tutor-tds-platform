"""Read installed code only; build a sanitized fixture, never read production DB/config."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

source = Path('/etc/dokploy/compose/compose-program-open-source-monitor-szkpni/code/tds-child-theme')
destination = Path(sys.argv[1])
evidence = Path(sys.argv[2])
expected = {
    'functions.php': '3f896a20b7d0db98fe20eb6e211ab1785648d7ca322465fd77eb9fc99447c687',
    'pages/cadastro.php': '67e88421dbd1a0883ef5dbb24cd906b6e3082b6d5026c46461b70030d0a8088f',
    'includes/admin-cadastro-aluno.php': 'f34757104fb3f8b4d2d7491e8b3d144a43ba705c01d0ed42a58e4b16cce20e07',
}
digest = lambda value: hashlib.sha256(value).hexdigest()
for name, sha in expected.items():
    if digest((source / name).read_bytes()) != sha:
        raise SystemExit('BLOCKED institutional source changed: ' + name)
if destination.exists():
    raise SystemExit('Refusing to overwrite a fixture')
manifest = []
for path in sorted(source.rglob('*')):
    if path.is_symlink():
        raise SystemExit('Refusing a theme symlink')
    if not path.is_file():
        continue
    relative = path.relative_to(source)
    raw = path.read_bytes()
    clean = raw
    redactions = 0
    if str(relative) == 'functions.php':
        clean, redactions = re.subn(
            rb"define\('TDS_CHATWOOT_TOKEN',\s*'[^']*'\);",
            b"define('TDS_CHATWOOT_TOKEN', ''); // QA: integration token removed", raw)
        if redactions != 1:
            raise SystemExit('BLOCKED unexpected integration credential syntax')
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(clean)
    manifest.append({'file': str(relative), 'original_sha256': digest(raw),
                     'fixture_sha256': digest(clean), 'redactions': redactions})
evidence.joinpath('theme-provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('PASS faithful theme acquisition; one integration token removed; no database/config copied')
