#!/usr/bin/env python3
"""End-to-end smoke test for the synthetic staging media lifecycle.

The script creates a disposable media record, publishes it, validates student
playback/events/rating, blocks it and always attempts to archive it.  It only
accepts the fixed synthetic staging lineage and credentials through environment
variables so it cannot accidentally operate on production data.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urljoin, urlparse


STAGING_IDS = {
    "institution_id": "staging-qa-institution",
    "program_id": "staging-qa-program",
    "course_id": "staging-qa-course",
}


class Response:
    def __init__(self, status: int, body: object, headers: Any) -> None:
        self.status = status
        self.body = body
        self.headers = headers


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
    if token:
        headers["Authorization"] = f"Bearer {token}"
    opener = urllib.request.build_opener()
    if not follow_redirects:
        opener = urllib.request.build_opener(_NoRedirect())
    target = (
        path
        if path.startswith(("https://", "http://"))
        else base_url.rstrip("/") + path
    )
    req = urllib.request.Request(
        target,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with opener.open(req, timeout=20) as response:
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
            parsed = payload.decode(errors="replace")
        return Response(exc.code, parsed, exc.headers)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        return None


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


def resolve_same_origin_redirects(base_url: str, target: str) -> Response:
    """Follow proxy canonicalization, but stop before provider playback."""
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
    raise RuntimeError("Too many same-origin playback redirects")


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


def event(
    run_id: str,
    index: int,
    kind: str,
    media_id: str,
    session_id: str,
    occurred_at: datetime,
    extra: dict[str, str] | None = None,
) -> dict[str, object]:
    payload = {"media_id": media_id, "module_id": "modulo-smoke"}
    if extra:
        payload.update(extra)
    return {
        "event_id": f"staging-media-smoke-{run_id}-{index}",
        "event_type": kind,
        "course_id": STAGING_IDS["course_id"],
        "session_id": session_id,
        "occurred_at": occurred_at.isoformat().replace("+00:00", "Z"),
        "payload": payload,
    }


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: staging_media_smoke.py BASE_URL")
    base_url = sys.argv[1].rstrip("/")
    if "staging" not in base_url.lower():
        raise SystemExit("Refusing target without 'staging' in the URL")

    admin = login(base_url, "ADMIN")
    student = login(base_url, "STUDENT")
    run_id = secrets.token_hex(6)
    media_id: str | None = None
    current_status: str | None = None

    try:
        created = expect(
            request(
                base_url,
                "/admin/media",
                method="POST",
                token=admin,
                body={
                    **STAGING_IDS,
                    "module_id": "modulo-smoke",
                    "title": f"Mídia sintética smoke {run_id} [STAGING]",
                    "description": "Registro descartável para smoke automatizado de staging.",
                    "competency_id": "competencia-smoke",
                    "provider": "youtube",
                    "provider_asset_id": f"smoke_{run_id}",
                    "duration_seconds": 600,
                    "thumbnail_url": "https://example.com/synthetic-smoke.jpg",
                    "captions": [
                        {
                            "language": "pt-BR",
                            "label": "Português",
                            "format": "vtt",
                            "reference": "https://example.com/synthetic-smoke.vtt",
                        }
                    ],
                    "visibility": "enrolled",
                    "offline_policy": "forbidden",
                    "rights_confirmed": True,
                    "followup_activity_id": "quiz-smoke",
                },
            ),
            201,
            "create media",
        )
        if not isinstance(created, dict) or not isinstance(created.get("id"), str):
            raise RuntimeError("Invalid media creation response")
        media_id = created["id"]
        current_status = "draft"

        published = expect(
            request(
                base_url,
                f"/admin/media/{media_id}/publish",
                method="POST",
                token=admin,
            ),
            200,
            "publish media",
        )
        if not isinstance(published, dict) or published.get("status") != "published":
            raise RuntimeError("Media was not published")
        current_status = "published"

        expect(
            request(
                base_url,
                f"/media/{media_id}/rating",
                method="PUT",
                token=student,
                body={"rating": 5},
            ),
            409,
            "rating before completion",
        )

        playback = expect(
            request(
                base_url,
                f"/media/{media_id}/playback-authorizations",
                method="POST",
                token=student,
            ),
            201,
            "playback authorization",
        )
        if not isinstance(playback, dict) or not isinstance(
            playback.get("playback_url"), str
        ):
            raise RuntimeError("Invalid playback authorization response")
        playback_path = playback["playback_url"]
        resolved = resolve_same_origin_redirects(base_url, playback_path)
        expect(resolved, 307, "playback resolution")
        if resolved.headers.get("Location") != f"https://www.youtube-nocookie.com/embed/smoke_{run_id}":
            raise RuntimeError("Playback redirect target diverged")
        expect(
            resolve_same_origin_redirects(base_url, playback_path + "x"),
            401,
            "tampered playback",
        )

        session_id = f"staging-media-smoke-{run_id}"
        started_at = datetime.now(timezone.utc) - timedelta(minutes=15)
        specs = [
            ("video_started", {}),
            ("video_checkpoint", {"checkpoint": "25", "position_seconds": "155"}),
            ("video_checkpoint", {"checkpoint": "50", "position_seconds": "305"}),
            ("video_checkpoint", {"checkpoint": "75", "position_seconds": "455"}),
            ("video_completed", {"position_seconds": "590"}),
            ("video_followup_completed", {"followup_type": "quiz"}),
            ("video_saved", {}),
        ]
        events = [
            event(
                run_id,
                index,
                kind,
                media_id,
                session_id,
                started_at + timedelta(minutes=index),
                extra,
            )
            for index, (kind, extra) in enumerate(specs, start=1)
        ]
        for index, item in enumerate(events, start=1):
            expect(
                request(base_url, "/events", method="POST", token=student, body=item),
                201,
                f"media event {index}",
            )
        expect(
            request(base_url, "/events", method="POST", token=student, body=events[2]),
            200,
            "event idempotency retry",
        )

        rating = expect(
            request(
                base_url,
                f"/media/{media_id}/rating",
                method="PUT",
                token=student,
                body={"rating": 5},
            ),
            201,
            "rating after completion",
        )
        if not isinstance(rating, dict) or rating.get("rating") != 5:
            raise RuntimeError("Rating response diverged")
        expect(
            request(
                base_url,
                f"/media/{media_id}/rating",
                method="PUT",
                token=student,
                body={"rating": 5},
            ),
            200,
            "rating idempotency retry",
        )

        expect(
            request(
                base_url,
                f"/admin/media/{media_id}/block",
                method="POST",
                token=admin,
                body={"reason": "Bloqueio sintético do smoke de staging."},
            ),
            200,
            "block media",
        )
        current_status = "blocked"
        expect(
            resolve_same_origin_redirects(base_url, playback_path),
            404,
            "revoked playback grant",
        )
        history = expect(
            request(
                base_url,
                f"/admin/media/{media_id}/history",
                token=admin,
            ),
            200,
            "editorial history",
        )
        if not isinstance(history, list) or [item.get("to_status") for item in history] != [
            "draft",
            "published",
            "blocked",
        ]:
            raise RuntimeError("Editorial transition history diverged")
    finally:
        if media_id is not None and current_status != "archived":
            archived = request(
                base_url,
                f"/admin/media/{media_id}/archive",
                method="POST",
                token=admin,
                body={"reason": "Arquivamento automático após smoke de staging."},
            )
            if archived.status == 200:
                current_status = "archived"
            else:
                print(
                    f"WARNING: automatic archive returned HTTP {archived.status}",
                    file=sys.stderr,
                )

    if current_status != "archived":
        raise RuntimeError("Disposable media was not archived")
    print(
        "Staging media smoke passed: playback authorization/redirect/tamper, "
        "ordered telemetry/idempotency, rating gate/idempotency, block/revoke/history/archive."
    )


if __name__ == "__main__":
    main()
