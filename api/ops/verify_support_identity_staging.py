"""Authenticated staging smoke; prints metadata only, never tokens or hashes."""
import json
import os
from urllib.request import Request, urlopen

BASE = os.getenv("STAGING_PUBLIC_API_BASE_URL", "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api")


def read_seed() -> dict[str, str]:
    result = {}
    with open(os.getenv("STAGING_SEED_ENV", "/opt/tutor-tds-staging/.staging-seed.env"), encoding="utf-8") as source:
        for line in source:
            if "=" in line and not line.startswith("#"):
                key, value = line.rstrip("\r\n").split("=", 1)
                result[key] = value.strip('"')
    return result


def main() -> None:
    seed = read_seed()
    body = json.dumps({"cpf": seed["STAGING_SEED_STUDENT_CPF"], "password": seed["STAGING_SEED_STUDENT_PASSWORD"]}).encode()
    login = Request(BASE + "/auth/login", data=body, headers={"Content-Type": "application/json"})
    with urlopen(login, timeout=15) as response:
        token = json.load(response)["access_token"]
    identity = Request(BASE + "/support/identity", headers={"Authorization": "Bearer " + token})
    with urlopen(identity, timeout=15) as response:
        data = json.load(response)
        assert response.status == 200
    identifier = data["identifier"]
    assert identifier.startswith("tds-staging:")
    assert len(data["identifier_hash"]) == 64
    print(f"support identity pass: namespace={identifier.split(':', 1)[0]} hash_length=64")


if __name__ == "__main__":
    main()
