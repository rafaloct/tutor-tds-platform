#!/usr/bin/env python3
"""Validate the safe certificate boundary in synthetic staging."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from urllib.parse import urlparse


def request(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    token: str | None = None,
) -> tuple[int, object]:
    headers = {"Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                base_url.rstrip("/") + path,
                data=data,
                headers=headers,
                method=method,
            ),
            timeout=15,
        ) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        try:
            payload = json.load(exc)
        except Exception:
            payload = {}
        return exc.code, payload


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def login(base_url: str, role: str) -> str:
    status, payload = request(
        base_url,
        "/auth/login",
        method="POST",
        body={
            "cpf": required(f"STAGING_SEED_{role}_CPF"),
            "password": required(f"STAGING_SEED_{role}_PASSWORD"),
        },
    )
    if status != 200 or not isinstance(payload, dict):
        raise RuntimeError(f"Invalid login response for {role}")
    token = payload.get("access_token")
    if not isinstance(token, str):
        raise RuntimeError(f"Missing access token for {role}")
    return token


def contains_private_identity(value: object) -> bool:
    if isinstance(value, dict):
        return any(
            str(key).lower() in {"cpf", "phone", "cpf_digest"}
            or contains_private_identity(item)
            for key, item in value.items()
        )
    if isinstance(value, list):
        return any(contains_private_identity(item) for item in value)
    return False


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: staging_certificate_gate_smoke.py BASE_URL")
    base_url = sys.argv[1].rstrip("/")
    parsed_base = urlparse(base_url)
    if parsed_base.scheme != "https" or "staging" not in base_url.lower():
        raise SystemExit("Refusing non-HTTPS target without 'staging' in the URL")
    student = login(base_url, "STUDENT")
    teacher = login(base_url, "TEACHER")

    unauthenticated_status, _ = request(base_url, "/certificates")
    if unauthenticated_status != 401:
        raise RuntimeError("Certificate wallet did not require authentication")

    student_status, student_wallet = request(
        base_url, "/certificates", token=student
    )
    teacher_status, teacher_wallet = request(
        base_url, "/certificates", token=teacher
    )
    if student_status != 200 or teacher_status != 200:
        raise RuntimeError("Certificate wallet was unavailable")
    if contains_private_identity(student_wallet) or contains_private_identity(
        teacher_wallet
    ):
        raise RuntimeError("Certificate wallet exposed CPF/phone fields")
    if not isinstance(teacher_wallet, dict) or teacher_wallet.get("certificates") != []:
        raise RuntimeError("Certificate wallet leaked another student's records")

    disabled_status, disabled = request(
        base_url,
        "/certificates/references",
        method="POST",
        token=student,
        body={
            "id": "staging-gate-certificate-disabled",
            "program_id": "staging-qa-program",
            "course_id": "staging-qa-course",
            "class_id": "staging-qa-class",
            "issued_at": datetime.now(timezone.utc).isoformat(),
            "verification_url": "https://invalid.example/certificates/disabled",
            "content_hash": "0" * 64,
        },
    )
    if disabled_status != 503 or not isinstance(disabled, dict):
        raise RuntimeError("Unconfigured certificate origin did not fail closed")

    print(
        "Certificate staging boundary passed: auth=401, wallets=200, "
        "cross-user isolation=yes, CPF/phone fields=absent, emitter gate=503."
    )


if __name__ == "__main__":
    main()
