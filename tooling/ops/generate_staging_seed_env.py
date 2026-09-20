"""Print synthetic staging credentials without accepting external input."""

from __future__ import annotations

import secrets


def valid_cpf() -> str:
    while True:
        digits = [secrets.randbelow(10) for _ in range(9)]
        if len(set(digits)) == 1:
            continue
        for index in (9, 10):
            total = sum(
                digits[position] * (index + 1 - position)
                for position in range(index)
            )
            digits.append((total * 10 % 11) % 10)
        return "".join(map(str, digits))


def main() -> None:
    print("TUTOR_ENVIRONMENT=staging")
    print("STAGING_SEED_CONFIRM=SEED_SYNTHETIC_STAGING_DATA")
    used_cpfs: set[str] = set()
    for index, role in enumerate(
        ("ADMIN", "TEACHER", "MONITOR", "STUDENT"),
        start=1,
    ):
        cpf = valid_cpf()
        while cpf in used_cpfs:
            cpf = valid_cpf()
        used_cpfs.add(cpf)
        print(f"STAGING_SEED_{role}_CPF={cpf}")
        print(f"STAGING_SEED_{role}_PHONE=55000000000{index}")
        print(f"STAGING_SEED_{role}_PASSWORD={secrets.token_urlsafe(24)}")
    print(f"STAGING_SEED_CHECKIN_TOKEN={secrets.token_urlsafe(24)}")


if __name__ == "__main__":
    main()
