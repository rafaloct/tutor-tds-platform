"""Create synthetic teacher/monitor accounts in staging through the admin API."""
from __future__ import annotations
import json, secrets, urllib.request
from pathlib import Path

BASE = "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
SEED = Path("/opt/tutor-tds-staging/.staging-seed.env")
OUT = Path("/opt/tutor-tds-staging/.managed-staff.env")

def values(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, val = line.split("=", 1); out[key] = val
    return out

def cpf() -> str:
    digits = [secrets.randbelow(10) for _ in range(9)]
    while len(set(digits)) == 1: digits = [secrets.randbelow(10) for _ in range(9)]
    for index in (9, 10):
        total = sum(digits[pos] * (index + 1 - pos) for pos in range(index))
        digits.append((total * 10 % 11) % 10)
    return "".join(map(str, digits))

def post(path: str, payload: dict, token: str | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if token: headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=json.dumps(payload).encode(), headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=20) as response: return json.load(response)

def main() -> None:
    seed = values(SEED)
    admin = post("/auth/login", {"cpf": seed["STAGING_SEED_ADMIN_CPF"], "password": seed["STAGING_SEED_ADMIN_PASSWORD"]})
    lines = ["TUTOR_ENVIRONMENT=staging"]
    for role, suffix, phone in (("teacher", "Professor QA Sintético", "55000000997"), ("monitor", "Monitor QA Sintético", "55000000998")):
        password = secrets.token_urlsafe(24); identity = cpf()
        created = post("/admin/accounts", {"name": suffix, "cpf": identity, "phone": phone, "password": password, "role": role, "program_id": "staging-qa-program"}, admin["access_token"])
        key = role.upper()
        lines += [f"STAGING_MANAGED_{key}_CPF={identity}", f"STAGING_MANAGED_{key}_PASSWORD={password}", f"STAGING_MANAGED_{key}_USER_ID={created['id']}"]
    OUT.write_text("\n".join(lines) + "\n"); OUT.chmod(0o600)
    print(f"provisioned roles=teacher,monitor output={OUT}")

if __name__ == "__main__": main()
