#!/usr/bin/env python3
"""Exercise Evidence check-in ordering against a deployed staging database."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse
from uuid import uuid4


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
        raise RuntimeError(f"{method} {path} returned HTTP {exc.code}") from exc


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def login(base_url: str, role: str) -> str:
    status, response = request(
        base_url,
        "/auth/login",
        method="POST",
        body={
            "cpf": required(f"STAGING_SEED_{role}_CPF"),
            "password": required(f"STAGING_SEED_{role}_PASSWORD"),
        },
    )
    if status != 200 or not isinstance(response, dict):
        raise RuntimeError(f"Invalid login response for {role}")
    token = response.get("access_token")
    if not isinstance(token, str):
        raise RuntimeError(f"Missing access token for {role}")
    return token


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: staging_evidence_smoke.py BASE_URL")
    base_url = sys.argv[1].rstrip("/")
    parsed_base = urlparse(base_url)
    if parsed_base.scheme != "https" or "staging" not in base_url.lower():
        raise SystemExit("Refusing non-HTTPS target without 'staging' in the URL")
    teacher_token = login(base_url, "TEACHER")
    student_token = login(base_url, "STUDENT")
    now = datetime.now(timezone.utc)
    status, created = request(
        base_url,
        "/admin/classes/staging-qa-class/sessions",
        method="POST",
        token=teacher_token,
        body={
            "starts_at": (now - timedelta(minutes=2)).isoformat(),
            "ends_at": (now + timedelta(minutes=30)).isoformat(),
        },
    )
    if status != 201 or not isinstance(created, dict):
        raise RuntimeError("Evidence session was not created")
    session_id = created.get("id")
    checkin_token = created.get("checkin_token")
    if not isinstance(session_id, str) or not isinstance(checkin_token, str):
        raise RuntimeError("Evidence session omitted its creation token")

    checkin_key = f"staging-fk-checkin-{uuid4()}"
    path = f"/classes/staging-qa-class/sessions/{session_id}/checkins"
    checkin_body = {
        "kind": "checkin",
        "idempotency_key": checkin_key,
        "token": checkin_token,
    }
    first_status, first = request(
        base_url, path, method="POST", token=student_token, body=checkin_body
    )
    retry_status, retry = request(
        base_url, path, method="POST", token=student_token, body=checkin_body
    )
    if first_status != 201 or retry_status != 200 or first != retry:
        raise RuntimeError("Check-in creation/retry contract failed")

    rotate_status, rotated = request(
        base_url,
        f"/classes/staging-qa-class/sessions/{session_id}/token",
        method="POST",
        token=teacher_token,
    )
    if rotate_status != 200 or not isinstance(rotated, dict):
        raise RuntimeError("Token rotation failed")
    checkout_token = rotated.get("checkin_token")
    if not isinstance(checkout_token, str) or checkout_token == checkin_token:
        raise RuntimeError("Token rotation did not issue a new token")

    checkout_body = {
        "kind": "checkout",
        "idempotency_key": f"staging-fk-checkout-{uuid4()}",
        "token": checkout_token,
    }
    checkout_status, checkout = request(
        base_url, path, method="POST", token=student_token, body=checkout_body
    )
    checkout_retry_status, checkout_retry = request(
        base_url, path, method="POST", token=student_token, body=checkout_body
    )
    if checkout_status != 201 or checkout_retry_status != 200 or checkout != checkout_retry:
        raise RuntimeError("Check-out creation/retry contract failed")

    close_status, report = request(
        base_url,
        f"/classes/staging-qa-class/sessions/{session_id}/close?confirm_pending=true",
        method="POST",
        token=teacher_token,
    )
    if close_status != 200 or not isinstance(report, dict):
        raise RuntimeError("Synthetic Evidence session was not closed")
    summary = report.get("summary")
    if not isinstance(summary, dict) or summary.get("checkin_count") != 2:
        raise RuntimeError("Evidence report did not contain both attendance records")

    print(
        "Evidence staging smoke passed: "
        "checkin=201/retry=200, token rotation=200, "
        "checkout=201/retry=200, closed report checkin_count=2."
    )


if __name__ == "__main__":
    main()
