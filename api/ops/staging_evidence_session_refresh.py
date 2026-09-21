#!/usr/bin/env python3
"""Create a fresh synthetic Evidence session and securely persist its token."""

from __future__ import annotations

import json
import os
import stat
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlsplit

SAFE_SESSION_FIELDS = (
    "id",
    "class_id",
    "starts_at",
    "ends_at",
    "status",
    "token_expires_at",
    "token_version",
)
APPROVED_STAGING_HOST = "ead.ipexdesenvolvimento.cloud"
APPROVED_STAGING_PATH = "/tutor-staging-api"


def parse_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("\"'")
    return values


def post(base_url: str, path: str, body: dict[str, object], token: str | None = None) -> dict:
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                base_url.rstrip("/") + path,
                data=json.dumps(body).encode(),
                headers=headers,
                method="POST",
            ),
            timeout=15,
        ) as response:
            payload = json.load(response)
            if response.status not in {200, 201} or not isinstance(payload, dict):
                raise RuntimeError(f"POST {path} returned an invalid response")
            return payload
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"POST {path} returned HTTP {exc.code}") from exc


def replace_token(path: Path, token: str) -> None:
    source = path.read_text(encoding="utf-8")
    lines = source.splitlines()
    replacement = f"STAGING_SEED_CHECKIN_TOKEN={token}"
    indexes = [
        index
        for index, line in enumerate(lines)
        if line.strip().startswith("STAGING_SEED_CHECKIN_TOKEN=")
    ]
    if len(indexes) != 1:
        raise RuntimeError("Expected exactly one STAGING_SEED_CHECKIN_TOKEN entry")
    lines[indexes[0]] = replacement
    temporary = path.with_name(path.name + ".token-refresh.tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write("\n".join(lines) + "\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        os.chmod(path, 0o600)
    finally:
        temporary.unlink(missing_ok=True)


def validate_staging_base_url(value: str) -> str:
    base_url = value.rstrip("/")
    parsed = urlsplit(base_url)
    try:
        port = parsed.port
    except ValueError as exc:
        raise RuntimeError("Refusing non-staging base URL") from exc
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username is not None
        or port is not None
        or parsed.query
        or parsed.fragment
        or parsed.hostname != APPROVED_STAGING_HOST
        or parsed.path != APPROVED_STAGING_PATH
    ):
        raise RuntimeError("Refusing non-staging base URL")
    return base_url


def safe_session_summary(session: dict) -> dict[str, object]:
    return {key: session[key] for key in SAFE_SESSION_FIELDS if key in session}


def require_private_file(path: Path) -> None:
    # Windows does not expose POSIX owner/group bits through chmod/stat. The
    # operational target is Linux, where an exact 0600 check is mandatory.
    if os.name == "posix" and stat.S_IMODE(path.stat().st_mode) != 0o600:
        raise RuntimeError("Seed env file must have mode 0600")


def refresh(base_url: str, env_file: str | Path) -> dict[str, object]:
    base_url = validate_staging_base_url(base_url)
    env_path = Path(env_file).resolve()
    require_private_file(env_path)
    values = parse_env(env_path)
    cpf = values.get("STAGING_SEED_TEACHER_CPF", "")
    password = values.get("STAGING_SEED_TEACHER_PASSWORD", "")
    if not cpf or not password:
        raise RuntimeError("Synthetic teacher credentials are missing")

    login = post(base_url, "/auth/login", {"cpf": cpf, "password": password})
    access_token = login.get("access_token")
    if not isinstance(access_token, str):
        raise RuntimeError("Synthetic teacher login omitted access token")
    now = datetime.now(timezone.utc)
    session = post(
        base_url,
        "/admin/classes/staging-qa-class/sessions",
        {
            "starts_at": (now - timedelta(minutes=2)).isoformat(),
            "ends_at": (now + timedelta(hours=8)).isoformat(),
        },
        token=access_token,
    )
    checkin_token = session.pop("checkin_token", None)
    if not isinstance(checkin_token, str) or len(checkin_token) < 16:
        raise RuntimeError("New session omitted a valid check-in token")
    replace_token(env_path, checkin_token)
    return safe_session_summary(session)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: staging_evidence_session_refresh.py BASE_URL ENV_FILE")
    print(json.dumps(refresh(sys.argv[1], sys.argv[2]), sort_keys=True))


if __name__ == "__main__":
    main()
