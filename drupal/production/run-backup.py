#!/usr/bin/env python3
"""Host scheduler entrypoint: exclusive lock and sanitized durable status."""
import datetime
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path('/etc/dokploy/tds-drupal-ops')
with open('/run/lock/tds-drupal-portal-backup.lock', 'w') as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit(0)
    outcome = {'status': 'BACKUP_FAILED', 'stage': 'runner', 'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        cid = subprocess.check_output(['docker', 'ps', '-q', '--filter', 'name=dokploy.1'], timeout=20, text=True).strip()
        if not cid or '\n' in cid:
            raise ValueError('container count')
        result = subprocess.run(['docker', 'exec', cid, 'node', str(ROOT / 'source/drupal/production/backup-dokploy.mjs'), 'backup'], capture_output=True, text=True, timeout=600)
        for line in result.stdout.splitlines():
            if line.startswith('{'):
                data = json.loads(line)
                outcome.update({key: data[key] for key in ['status', 'stage', 'id', 'key', 'sha256', 'bytes', 'completedAt', 'filesAtomic', 'restoreExecuted'] if key in data})
        if result.returncode:
            outcome['status'] = 'BACKUP_FAILED'
    except Exception:
        pass
    target = ROOT / 'backup-last-result.json'
    temp = ROOT / 'backup-last-result.tmp'
    descriptor = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as out:
        json.dump(outcome, out)
    os.replace(temp, target)
    if outcome['status'] == 'BACKUP_TRANSPORT_VERIFIED':
        good = ROOT / 'backup-last-success.json'
        good.write_text(json.dumps(outcome))
        good.chmod(0o600)
    print(json.dumps({'status': outcome['status'], 'receipt': str(target)}))
    sys.exit(0 if outcome['status'] == 'BACKUP_TRANSPORT_VERIFIED' else 1)
