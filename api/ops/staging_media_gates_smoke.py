#!/usr/bin/env python3
"""Destructive-only-to-synthetic staging smoke for remaining media gates."""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urljoin, urlparse
from uuid import UUID


STAGING_IDS = {
    "institution_id": "staging-qa-institution",
    "program_id": "staging-qa-program",
    "course_id": "staging-qa-course",
}
DB_MUTATION_CONFIRMATION = "expire-synthetic-grant-and-check-trigger"


class Response:
    def __init__(self, status: int, body: object, headers: Any) -> None:
        self.status = status
        self.body = body
        self.headers = headers


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        return None


def required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def request(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    token: str | None = None,
    follow_redirects: bool = True,
) -> Response:
    headers = {"Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    opener = (
        urllib.request.build_opener()
        if follow_redirects
        else urllib.request.build_opener(_NoRedirect())
    )
    target = path if path.startswith(("https://", "http://")) else base_url + path
    call = urllib.request.Request(target, data=data, headers=headers, method=method)
    try:
        with opener.open(call, timeout=20) as response:
            payload = response.read()
            return Response(
                response.status,
                json.loads(payload) if payload else None,
                response.headers,
            )
    except urllib.error.HTTPError as exc:
        payload = exc.read()
        try:
            parsed: object = json.loads(payload) if payload else None
        except json.JSONDecodeError:
            parsed = None
        return Response(exc.code, parsed, exc.headers)


def expect(response: Response, status: int, label: str) -> object:
    if response.status != status:
        raise RuntimeError(
            f"{label} returned HTTP {response.status}; expected {status}"
        )
    return response.body


def login(base_url: str, role: str) -> str:
    body = expect(
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
    if not isinstance(body, dict) or not isinstance(body.get("access_token"), str):
        raise RuntimeError(f"Invalid login response for {role}")
    return body["access_token"]


def resolve_same_origin(base_url: str, target: str) -> Response:
    base_host = urlparse(base_url).netloc
    current = target
    for _ in range(3):
        result = request(base_url, current, follow_redirects=False)
        location = result.headers.get("Location")
        if result.status not in {301, 302, 308} or not location:
            return result
        absolute = urljoin(current if current.startswith("http") else base_url, location)
        if urlparse(absolute).netloc != base_host:
            return result
        current = absolute
    raise RuntimeError("Too many same-origin redirects")


def run_staging_sql(sql: str, *, expect_append_only_error: bool = False) -> str:
    if os.getenv("STAGING_SYNTHETIC_DB_MUTATION_CONFIRM") != DB_MUTATION_CONFIRMATION:
        raise RuntimeError("Synthetic DB mutation confirmation is missing")
    compose_file = os.getenv("STAGING_COMPOSE_FILE", "docker-compose.staging.yml")
    if compose_file != "docker-compose.staging.yml":
        raise RuntimeError("Only docker-compose.staging.yml is allowed")
    result = subprocess.run(
        [
            "docker", "compose", "-f", compose_file, "exec", "-T",
            "db-staging", "psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
            "-U", "tutor_tds_staging", "-d", "tutor_tds_staging", "-Atc", sql,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if expect_append_only_error:
        if result.returncode == 0 or "append-only" not in result.stderr:
            raise RuntimeError("Editorial append-only trigger was not enforced")
        return ""
    if result.returncode != 0:
        raise RuntimeError("Controlled staging SQL failed")
    return result.stdout.strip()


def event(
    *, run_id: str, index: int, kind: str, media_id: str,
    session_id: str, occurred_at: datetime, extra: dict[str, str] | None = None,
) -> dict[str, object]:
    payload = {"media_id": media_id, "module_id": "modulo-gates-smoke"}
    if extra:
        payload.update(extra)
    return {
        "event_id": f"staging-gates-{run_id}-{index}",
        "event_type": kind,
        "course_id": STAGING_IDS["course_id"],
        "session_id": session_id,
        "occurred_at": occurred_at.isoformat().replace("+00:00", "Z"),
        "payload": payload,
    }


def media_payload(run_id: str) -> dict[str, object]:
    return {
        **STAGING_IDS,
        "module_id": "modulo-gates-smoke",
        "title": f"Mídia sintética gates {run_id} [STAGING]",
        "description": "Registro descartável para gates editoriais de staging.",
        "competency_id": "competencia-gates-smoke",
        "provider": "youtube",
        "provider_asset_id": f"gates_{run_id}",
        "duration_seconds": 600,
        "thumbnail_url": "https://example.com/synthetic-gates.jpg",
        "captions": [{
            "language": "pt-BR", "label": "Português", "format": "vtt",
            "reference": "https://example.com/synthetic-gates.vtt",
        }],
        "visibility": "enrolled",
        "offline_policy": "forbidden",
        "rights_confirmed": True,
        "followup_activity_id": "quiz-gates-smoke",
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: staging_media_gates_smoke.py BASE_URL")
    base_url = sys.argv[1].rstrip("/")
    if urlparse(base_url).scheme != "https" or "staging" not in base_url.lower():
        raise SystemExit("Refusing non-HTTPS target without 'staging' in the URL")

    admin = login(base_url, "ADMIN")
    teacher = login(base_url, "TEACHER")
    student = login(base_url, "STUDENT")
    run_id = secrets.token_hex(6)
    media_id: str | None = None
    current_status: str | None = None

    try:
        expect(
            request(
                base_url, "/admin/media", method="POST", token=teacher,
                body=media_payload(f"denied_{run_id}"),
            ),
            403,
            "teacher media creation denial",
        )
        created = expect(
            request(
                base_url, "/admin/media", method="POST", token=admin,
                body=media_payload(run_id),
            ),
            201,
            "create synthetic media",
        )
        if not isinstance(created, dict) or not isinstance(created.get("id"), str):
            raise RuntimeError("Invalid media creation response")
        media_id = created["id"]
        UUID(media_id)
        current_status = "draft"

        expect(
            request(base_url, f"/admin/media/{media_id}/history", token=student),
            403,
            "student editorial history denial",
        )
        expect(
            request(
                base_url, f"/admin/media/{media_id}/publish",
                method="POST", token=admin,
            ),
            200,
            "publish synthetic media",
        )
        current_status = "published"

        escaped_media_id = str(UUID(media_id))
        for operation in ("UPDATE", "DELETE"):
            statement = (
                "UPDATE media_status_transitions SET reason = 'forbidden mutation' "
                if operation == "UPDATE"
                else "DELETE FROM media_status_transitions "
            )
            run_staging_sql(
                statement + f"WHERE media_id = '{escaped_media_id}';",
                expect_append_only_error=True,
            )

        playback = expect(
            request(
                base_url, f"/media/{media_id}/playback-authorizations",
                method="POST", token=student,
            ),
            201,
            "create expiring playback grant",
        )
        if not isinstance(playback, dict) or not isinstance(
            playback.get("playback_url"), str
        ):
            raise RuntimeError("Invalid playback grant")
        updated_grant = run_staging_sql(
            "UPDATE media_playback_grants "
            "SET expires_at = NOW() - INTERVAL '1 second' "
            f"WHERE media_id = '{escaped_media_id}' AND expires_at > NOW() "
            "RETURNING id;"
        ).splitlines()
        if len(updated_grant) != 1:
            raise RuntimeError("Expected exactly one synthetic grant to expire")
        UUID(updated_grant[0])
        expect(
            resolve_same_origin(base_url, playback["playback_url"]),
            401,
            "expired playback grant",
        )
        removed_grant = run_staging_sql(
            "DELETE FROM media_playback_grants "
            f"WHERE media_id = '{escaped_media_id}' AND expires_at <= NOW() "
            "RETURNING id;"
        ).splitlines()
        if removed_grant != updated_grant:
            raise RuntimeError("Expired synthetic grant cleanup diverged")

        session_id = f"staging-gates-{run_id}"
        started_at = datetime.now(timezone.utc) - timedelta(minutes=20)
        specs = [
            ("video_started", {}),
            ("video_checkpoint", {"checkpoint": "25", "position_seconds": "155"}),
            ("video_checkpoint", {"checkpoint": "50", "position_seconds": "305"}),
            ("video_checkpoint", {"checkpoint": "75", "position_seconds": "455"}),
            ("video_completed", {"position_seconds": "590"}),
            ("video_followup_completed", {"followup_type": "quiz"}),
            ("video_saved", {}),
        ]
        for index, (kind, extra) in enumerate(specs, start=1):
            expect(
                request(
                    base_url, "/events", method="POST", token=student,
                    body=event(
                        run_id=run_id, index=index, kind=kind, media_id=media_id,
                        session_id=session_id,
                        occurred_at=started_at + timedelta(minutes=index * 2),
                        extra=extra,
                    ),
                ),
                201,
                f"qualified event {index}",
            )
        expect(
            request(
                base_url, f"/media/{media_id}/rating", method="PUT",
                token=student, body={"rating": 5},
            ),
            201,
            "explicit rating",
        )

        now = datetime.now(timezone.utc)
        first_window = {
            "media_id": media_id,
            "window_start": (now - timedelta(days=1)).isoformat(),
            "window_end": (now + timedelta(minutes=1)).isoformat(),
        }
        expect(
            request(
                base_url, "/admin/creator-scores/calculate", method="POST",
                token=student, body=first_window,
            ),
            403,
            "student score denial",
        )
        score = expect(
            request(
                base_url, "/admin/creator-scores/calculate", method="POST",
                token=admin, body=first_window,
            ),
            201,
            "creator score v2",
        )
        retry = expect(
            request(
                base_url, "/admin/creator-scores/calculate", method="POST",
                token=admin, body=first_window,
            ),
            200,
            "creator score idempotency",
        )
        overlap_window = {
            "media_id": media_id,
            "window_start": (now - timedelta(hours=12)).isoformat(),
            "window_end": (now + timedelta(minutes=2)).isoformat(),
        }
        overlap = expect(
            request(
                base_url, "/admin/creator-scores/calculate", method="POST",
                token=admin, body=overlap_window,
            ),
            201,
            "overlapping creator score window",
        )
        if not all(isinstance(item, dict) for item in (score, retry, overlap)):
            raise RuntimeError("Invalid score response")
        if score.get("rule_version") != "creator-score-v2":
            raise RuntimeError("Unexpected score rule version")
        if score.get("score_basis_points") != 10_000:
            raise RuntimeError("Synthetic qualified score must equal 10000")
        if retry.get("id") != score.get("id") or overlap.get("id") == score.get("id"):
            raise RuntimeError("Score idempotency/overlap contract diverged")

        expect(
            request(
                base_url, f"/admin/media/{media_id}/block", method="POST",
                token=admin, body={"reason": "Gate editorial sintético."},
            ),
            200,
            "block synthetic media",
        )
        current_status = "blocked"
        archived = expect(
            request(
                base_url, f"/admin/media/{media_id}/archive", method="POST",
                token=admin, body={"reason": "Fim do smoke sintético."},
            ),
            200,
            "archive synthetic media",
        )
        if not isinstance(archived, dict) or archived.get("status") != "archived":
            raise RuntimeError("Synthetic media was not archived")
        current_status = "archived"
        history = expect(
            request(base_url, f"/admin/media/{media_id}/history", token=admin),
            200,
            "editorial history",
        )
        if not isinstance(history, list) or [item.get("to_status") for item in history] != [
            "draft", "published", "blocked", "archived",
        ]:
            raise RuntimeError("Editorial append-only history diverged")
    finally:
        if media_id is not None and current_status != "archived":
            response = request(
                base_url, f"/admin/media/{media_id}/archive", method="POST",
                token=admin, body={"reason": "Limpeza após smoke sintético."},
            )
            if response.status != 200:
                print(
                    f"WARNING: synthetic archive returned HTTP {response.status}",
                    file=sys.stderr,
                )

    print(
        "Staging Onda 4 gates passed: RBAC negative, append-only trigger, "
        "expired grant, Creator Score v2 exact retry and overlapping window; "
        "synthetic media archived and payments untouched."
    )


if __name__ == "__main__":
    main()
