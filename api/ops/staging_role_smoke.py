#!/usr/bin/env python3
"""Authenticated smoke test for the synthetic staging hierarchy."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def request(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    token: str | None = None,
) -> object:
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
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{method} {path} returned HTTP {exc.code}") from exc


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: staging_role_smoke.py BASE_URL")
    base_url = sys.argv[1]
    tokens: dict[str, str] = {}
    for role in ("ADMIN", "TEACHER", "MONITOR", "STUDENT"):
        session = request(
            base_url,
            "/auth/login",
            method="POST",
            body={
                "cpf": required(f"STAGING_SEED_{role}_CPF"),
                "password": required(f"STAGING_SEED_{role}_PASSWORD"),
            },
        )
        if not isinstance(session, dict) or not isinstance(
            session.get("access_token"), str
        ):
            raise RuntimeError(f"Invalid login response for {role}")
        tokens[role] = session["access_token"]

    class_counts: dict[str, int] = {}
    for role, token in tokens.items():
        page = request(base_url, "/classes", token=token)
        if not isinstance(page, dict) or not isinstance(page.get("classes"), list):
            raise RuntimeError(f"Invalid class page for {role}")
        class_counts[role] = len(page["classes"])
        if class_counts[role] < 1:
            raise RuntimeError(f"Synthetic class not visible to {role}")

    dashboard = request(
        base_url,
        "/classes/staging-qa-class/dashboard",
        token=tokens["TEACHER"],
    )
    if not isinstance(dashboard, dict) or not isinstance(
        dashboard.get("students"), list
    ):
        raise RuntimeError("Invalid dashboard for TEACHER")

    monitor_exceptions = request(
        base_url,
        "/classes/staging-qa-class/monitor-exceptions",
        token=tokens["MONITOR"],
    )
    if not isinstance(monitor_exceptions, dict) or not isinstance(
        monitor_exceptions.get("students"), list
    ):
        raise RuntimeError("Invalid exception view for MONITOR")

    sessions = request(
        base_url,
        "/classes/staging-qa-class/sessions/open",
        token=tokens["STUDENT"],
    )
    if (
        not isinstance(sessions, dict)
        or not isinstance(sessions.get("id"), str)
        or sessions.get("class_id") != "staging-qa-class"
        or sessions.get("status") != "open"
    ):
        raise RuntimeError("Synthetic open session was not recovered")
    if "checkin_token" in sessions and sessions["checkin_token"] is not None:
        raise RuntimeError("Read endpoint exposed a check-in token")

    attempts = request(
        base_url,
        "/assessment-attempts",
        token=tokens["STUDENT"],
    )
    if not isinstance(attempts, dict) or not isinstance(
        attempts.get("attempts"), list
    ):
        raise RuntimeError("Invalid assessment page")

    media = request(base_url, "/media", token=tokens["STUDENT"])
    if not isinstance(media, dict) or not isinstance(media.get("media"), list):
        raise RuntimeError("Invalid media page")

    counts = ", ".join(
        f"{role.lower()}={count}" for role, count in class_counts.items()
    )
    print(
        "Authenticated staging smoke passed: "
        f"classes[{counts}], attempts={len(attempts['attempts'])}, "
        f"media={len(media['media'])}."
    )


if __name__ == "__main__":
    main()
