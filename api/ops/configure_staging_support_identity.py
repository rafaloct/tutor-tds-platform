"""Atomically configure Chatwoot identity settings without printing secrets.

Run on the VPS from the staging deployment directory. The secret is read from
stdin (not argv or shell history), the previous env is retained with mode 0600,
and the signed identity feature remains disabled until explicitly requested.
"""
from __future__ import annotations

import os
import secrets
import sys
from pathlib import Path


ENV_PATH = Path(os.environ.get("TUTOR_STAGING_ENV", "/opt/tutor-tds-staging/.env"))


def main() -> int:
    if not ENV_PATH.is_file() or ENV_PATH.is_symlink():
        raise SystemExit("staging .env ausente ou não é arquivo regular")
    secret = sys.stdin.readline().rstrip("\r\n")
    if len(secret) < 32 or "\n" in secret or "\r" in secret:
        raise SystemExit("a chave HMAC deve ter ao menos 32 caracteres")
    namespace = "tds-staging"
    original = ENV_PATH.read_text(encoding="utf-8")
    lines = [line for line in original.splitlines() if not line.startswith((
        "CHATWOOT_IDENTITY_SECRET=",
        "CHATWOOT_IDENTITY_NAMESPACE=",
        "SIGNED_SUPPORT_IDENTITY=",
    ))]
    lines.extend([
        f"CHATWOOT_IDENTITY_SECRET={secret}",
        f"CHATWOOT_IDENTITY_NAMESPACE={namespace}",
        "SIGNED_SUPPORT_IDENTITY=false",
    ])
    backup = ENV_PATH.with_name(ENV_PATH.name + ".before-support-identity")
    if not backup.exists():
        backup.write_text(original, encoding="utf-8")
        os.chmod(backup, 0o600)
    temporary = ENV_PATH.with_name(f".{ENV_PATH.name}.{secrets.token_hex(8)}.tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(temporary, 0o600)
    os.replace(temporary, ENV_PATH)
    os.chmod(ENV_PATH, 0o600)
    print("staging Chatwoot identity configured; feature remains disabled")
    return 0


if __name__ == "__main__":
    main()
