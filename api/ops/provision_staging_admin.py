"""Provision one synthetic staging administrator through the public API."""

from __future__ import annotations

import argparse
import json
import secrets
import urllib.error
import urllib.request
from pathlib import Path


def env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def cpf() -> str:
    digits = [secrets.randbelow(10) for _ in range(9)]
    while len(set(digits)) == 1:
        digits = [secrets.randbelow(10) for _ in range(9)]
    for index in (9, 10):
        total = sum(digits[position] * (index + 1 - position) for position in range(index))
        digits.append((total * 10 % 11) % 10)
    return "".join(map(str, digits))


def call(url: str, payload: dict[str, object], token: str | None = None) -> dict[str, object]:
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=20) as response:  # noqa: S310 - operator URL.
        return json.load(response)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base_url")
    parser.add_argument("seed_file", type=Path)
    parser.add_argument("output_file", type=Path)
    args = parser.parse_args()
    seed = env_file(args.seed_file)
    login = call(
        f"{args.base_url.rstrip('/')}/auth/login",
        {
            "cpf": seed["STAGING_SEED_ADMIN_CPF"],
            "password": seed["STAGING_SEED_ADMIN_PASSWORD"],
        },
    )
    password = secrets.token_urlsafe(24)
    account = {
        "name": "Administrador QA Sintético",
        "cpf": cpf(),
        "phone": "55000000999",
        "password": password,
        "role": "admin",
        "program_id": "staging-qa-program",
    }
    created = call(f"{args.base_url.rstrip('/')}/admin/accounts", account, login["access_token"])
    args.output_file.write_text(
        "TUTOR_ENVIRONMENT=staging\n"
        f"STAGING_MANAGED_ADMIN_CPF={account['cpf']}\n"
        f"STAGING_MANAGED_ADMIN_PASSWORD={password}\n"
        f"STAGING_MANAGED_ADMIN_USER_ID={created['id']}\n",
        encoding="utf-8",
    )
    args.output_file.chmod(0o600)
    print(f"provisioned user_id={created['id']} output={args.output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
