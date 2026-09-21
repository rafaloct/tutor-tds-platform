"""Install an existing VPS credential into the isolated staging sync config.

Run on the VPS only. Credentials never leave the server or appear in output.
Does not start services or write to a spreadsheet. Keeps a recoverable env backup.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import secrets
from datetime import datetime, timezone


def configure(env_path: Path, credential_path: Path, sheet_id: str) -> None:
    if env_path.resolve() != Path('/opt/tutor-tds-staging/.env'):
        raise ValueError('This command only configures the staging deployment.')
    if not sheet_id or not all(c.isalnum() or c in '_-' for c in sheet_id):
        raise ValueError('Invalid spreadsheet ID.')
    credentials = json.loads(credential_path.read_text())
    if credentials.get('type') != 'service_account' or not credentials.get('private_key'):
        raise ValueError('Expected an existing service-account credential.')
    original = env_path.read_text()
    # A single-quoted dotenv value preserves JSON backslash escapes.
    encoded = json.dumps(credentials, separators=(',', ':'))
    if "'" in encoded:
        raise ValueError('Unsupported credential quoting.')
    existing = dict(line.split('=', 1) for line in original.splitlines()
                    if '=' in line and not line.lstrip().startswith('#'))
    previous_id = existing.get('STAGING_GOOGLE_SHEET_ID', '').strip("'\"")
    if previous_id and previous_id != sheet_id:
        raise ValueError('Refusing to replace an already configured destination.')
    pseudonym = existing.get('STAGING_SHEETS_PSEUDONYM_SECRET', '').strip("'\"")
    if pseudonym and len(pseudonym) < 32:
        raise ValueError('Existing pseudonym key is invalid; do not rotate silently.')
    updates = {
        'STAGING_GOOGLE_SHEET_ID': sheet_id,
        'STAGING_GOOGLE_SHEET_RANGE': 'EventosAPI-Staging!A:J',
        'STAGING_GOOGLE_SERVICE_ACCOUNT_JSON': "'" + encoded + "'",
        'STAGING_SHEETS_PSEUDONYM_SECRET': pseudonym or secrets.token_hex(32),
        'STAGING_SHEETS_SYNC_ENABLED': 'true',
    }
    backup = env_path.with_name('.env.before-sheets-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f'))
    descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        output.write(original)
    lines = []
    for line in original.splitlines():
        key = line.split('=', 1)[0].strip()
        if key not in updates:
            lines.append(line)
    lines.extend(f'{key}={value}' for key, value in updates.items())
    temporary = env_path.with_name('.env.sheets-' + secrets.token_hex(8))
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        output.write('\n'.join(lines) + '\n')
    os.replace(temporary, env_path)
    print('Staging Sheets configured; secret values omitted. Backup:', backup)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sheet-id', required=True)
    parser.add_argument('--credentials', type=Path, required=True)
    args = parser.parse_args()
    configure(Path('/opt/tutor-tds-staging/.env'), args.credentials, args.sheet_id)
