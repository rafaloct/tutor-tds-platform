#!/usr/bin/env python3
"""Exercise Assessment Sync conflicts against synthetic staging data.

The caller supplies a unique run id and is responsible for deleting the two
synthetic rows after execution. Credentials are read only from environment
variables and are never printed.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone


COURSE_ID = "staging-qa-course"


class Response:
    def __init__(self, status: int, body: object) -> None:
        self.status = status
        self.body = body


def request(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    token: str | None = None,
) -> Response:
    headers = {"Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        base_url.rstrip("/") + path,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            payload = response.read()
            return Response(
                response.status,
                json.loads(payload) if payload else None,
            )
    except urllib.error.HTTPError as exc:
        payload = exc.read()
        try:
            parsed: object = json.loads(payload) if payload else None
        except json.JSONDecodeError:
            parsed = payload.decode(errors="replace")
        return Response(exc.code, parsed)


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def expect(response: Response, status: int, label: str) -> object:
    if response.status != status:
        raise RuntimeError(
            f"{label} returned HTTP {response.status}; expected {status}"
        )
    return response.body


def login(base_url: str, role: str) -> str:
    result = expect(
        request(
            base_url,
            "/auth/login",
            method="POST",
            body={
                "cpf": required(f"STAGING_SEED_{role}_CPF"),
                "password": required(f"STAGING_SEED_{role}_PASSWORD"),
            },
        ),
        200,
        f"{role.lower()} login",
    )
    if not isinstance(result, dict) or not isinstance(result.get("access_token"), str):
        raise RuntimeError(f"Invalid login response for {role}")
    return result["access_token"]


def conflict_code(result: object) -> str | None:
    if not isinstance(result, dict):
        return None
    detail = result.get("detail")
    return detail.get("code") if isinstance(detail, dict) else None


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: staging_assessment_smoke.py BASE_URL RUN_ID")
    base_url = sys.argv[1].rstrip("/")
    run_id = sys.argv[2]
    if "staging" not in base_url.lower():
        raise SystemExit("Refusing target without 'staging' in the URL")
    if not re.fullmatch(r"[a-z0-9-]{6,40}", run_id):
        raise SystemExit("RUN_ID must contain 6-40 lowercase letters, digits or hyphens")

    student = login(base_url, "STUDENT")
    observer = login(base_url, "MONITOR")
    content_id = f"staging-assessment-smoke-content-{run_id}"
    attempt_id = f"staging-assessment-smoke-attempt-{run_id}"
    topic = f"Conflito sintético {run_id}"
    content_path = f"/assessment-contents/{content_id}"
    attempt_path = f"/assessment-attempts/{attempt_id}"

    content = {
        "course_id": COURSE_ID,
        "topic": topic,
        "mode": "exam",
        "title": f"Simulado sintético {run_id}",
        "duration_seconds": 600,
        "questions": [
            {
                "question": "Este registro pertence somente ao smoke de staging?",
                "options": ["Sim", "Não"],
                "correct_index": 0,
                "explanation": "O identificador é sintético e descartável.",
                "topic": "Ambiente de QA",
            }
        ],
    }
    created_content = expect(
        request(base_url, content_path, method="PUT", body=content, token=student),
        201,
        "create assessment content",
    )
    if not isinstance(created_content, dict) or created_content.get("answer_key") is not None:
        raise RuntimeError("Incomplete content exposed the answer key")
    expect(
        request(base_url, content_path, method="PUT", body=content, token=student),
        200,
        "content idempotency retry",
    )
    immutable = expect(
        request(
            base_url,
            content_path,
            method="PUT",
            body=content | {"title": "Divergente"},
            token=student,
        ),
        409,
        "immutable content conflict",
    )
    if conflict_code(immutable) != "assessment_content_immutable":
        raise RuntimeError("Unexpected immutable content conflict")

    started_at = datetime.now(timezone.utc) - timedelta(minutes=5)

    def state(
        revision: int,
        *,
        answers: dict[str, int],
        marked: list[int],
        remaining: int,
        completed: bool = False,
        offset_seconds: int = 0,
    ) -> dict[str, object]:
        return {
            "course_id": COURSE_ID,
            "assessment_content_id": content_id,
            "topic": topic,
            "mode": "exam",
            "revision": revision,
            "answers": answers,
            "marked": marked,
            "current_index": 0,
            "remaining_seconds": remaining,
            "completed": completed,
            "score": 0,
            "updated_at": (
                started_at + timedelta(seconds=offset_seconds)
            ).isoformat().replace("+00:00", "Z"),
        }

    revision_one = state(1, answers={}, marked=[], remaining=600)
    created = expect(
        request(base_url, attempt_path, method="PUT", body=revision_one, token=student),
        201,
        "create attempt",
    )
    if not isinstance(created, dict) or created.get("revision") != 1:
        raise RuntimeError("Attempt was not created at revision 1")
    expect(
        request(base_url, attempt_path, method="PUT", body=revision_one, token=student),
        200,
        "attempt idempotency retry",
    )

    client_a = state(
        2,
        answers={"0": 0},
        marked=[],
        remaining=500,
        offset_seconds=30,
    )
    client_b = state(
        2,
        answers={"0": 1},
        marked=[0],
        remaining=480,
        offset_seconds=31,
    )
    expect(
        request(base_url, attempt_path, method="PUT", body=client_a, token=student),
        200,
        "client A revision 2",
    )
    conflict = expect(
        request(base_url, attempt_path, method="PUT", body=client_b, token=student),
        409,
        "client B stale revision 2",
    )
    if conflict_code(conflict) != "revision_conflict":
        raise RuntimeError("Concurrent writer did not receive revision_conflict")
    expect(
        request(base_url, attempt_path, method="PUT", body=client_a, token=student),
        200,
        "client A revision retry",
    )

    cross_read = request(base_url, attempt_path, token=observer)
    expect(cross_read, 404, "cross-account attempt read")
    cross_content = request(base_url, content_path, token=observer)
    expect(cross_content, 404, "cross-account content read")

    completed_payload = state(
        3,
        answers={"0": 0},
        marked=[],
        remaining=0,
        completed=True,
        offset_seconds=60,
    )
    completed = expect(
        request(
            base_url,
            attempt_path,
            method="PUT",
            body=completed_payload,
            token=student,
        ),
        200,
        "complete attempt",
    )
    if not isinstance(completed, dict) or completed.get("score") != 1:
        raise RuntimeError("Server-side assessment score diverged")
    hydrated = expect(
        request(base_url, attempt_path + "/content", token=student),
        200,
        "hydrate completed content",
    )
    if not isinstance(hydrated, dict) or not isinstance(hydrated.get("answer_key"), list):
        raise RuntimeError("Completed attempt did not release its answer key")
    completed_edit = expect(
        request(
            base_url,
            attempt_path,
            method="PUT",
            body=completed_payload
            | {
                "revision": 4,
                "answers": {"0": 1},
                "updated_at": (
                    started_at + timedelta(seconds=90)
                ).isoformat().replace("+00:00", "Z"),
            },
            token=student,
        ),
        409,
        "completed attempt mutation",
    )
    if conflict_code(completed_edit) != "completed_attempt":
        raise RuntimeError("Completed attempt was not immutable")

    print(
        "Staging assessment smoke passed: immutable content, idempotency, "
        "concurrent CAS conflict, cross-account isolation, server score, "
        "answer-key release and completed-attempt immutability."
    )


if __name__ == "__main__":
    main()
