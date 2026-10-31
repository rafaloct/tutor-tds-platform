"""Outbound LearnPress projection for self-enrollments.

Canonical enrollment lives in PostgreSQL; this worker only projects it to the
legacy WordPress/LearnPress site via the tds/v1 API. Failures never revoke the
canonical enrollment: exhausted items stay 'failed' for reconciliation.
"""
from __future__ import annotations

import argparse
import json
import logging
import re
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Protocol
from urllib import error, parse, request

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import ExternalSyncRequest, User
from .self_enrollment import LEARNPRESS_KIND

LOGGER = logging.getLogger("tutor_tds.learnpress_sync")


class WordPressEnrollmentSink(Protocol):
    def wp_user_id(self, user: User) -> int: ...

    def enroll(self, wp_user_id: int, course_slug: str) -> None: ...


class WordPressTdsClient:
    """Minimal tds/v1 client; X-API-Key never leaves the server side."""

    def __init__(self, base_url: str, api_key: str, *, timeout: int = 20) -> None:
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout

    def _call(
        self,
        method: str,
        path: str,
        body: dict[str, object] | None = None,
        *,
        allowed: tuple[int, ...] = (200, 201),
    ) -> tuple[int, dict[str, object]]:
        data = json.dumps(body).encode() if body is not None else None
        headers = {"X-API-Key": self.api_key}
        if data is not None:
            headers["Content-Type"] = "application/json"
        call = request.Request(
            f"{self.base_url}/wp-json/tds/v1{path}",
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with request.urlopen(call, timeout=self.timeout) as response:
                status = response.status
                payload = json.loads(response.read() or b"{}")
        except error.HTTPError as exc:
            status = exc.code
            if status not in allowed:
                # Response body may contain site details; status is enough.
                raise RuntimeError(f"WordPress respondeu HTTP {status}.") from exc
            payload = json.loads(exc.read() or b"{}")
        except error.URLError as exc:
            raise RuntimeError("WordPress indisponível.") from exc
        if status not in allowed:
            raise RuntimeError(f"WordPress respondeu HTTP {status}.")
        return status, payload if isinstance(payload, dict) else {}

    def wp_user_id(self, user: User) -> int:
        phone = re.sub(r"\D", "", user.phone or "")
        if not phone:
            raise RuntimeError("Usuário sem telefone para localizar no WordPress.")
        status, payload = self._call(
            "GET",
            f"/user-by-phone/{parse.quote(phone)}",
            allowed=(200, 404),
        )
        if status == 200 and payload.get("user_id"):
            return int(payload["user_id"])
        _, created = self._call(
            "POST",
            "/register",
            {"name": user.name, "phone": phone, "tds_user_id": user.id},
        )
        user_id = created.get("user_id")
        if not user_id:
            raise RuntimeError("WordPress não retornou user_id no registro.")
        return int(user_id)

    def enroll(self, wp_user_id: int, course_slug: str) -> None:
        self._call(
            "POST",
            "/enroll",
            {"user_id": wp_user_id, "course_slug": course_slug},
        )


@dataclass(frozen=True)
class ClaimedItem:
    id: str


class LearnPressSyncWorker:
    def __init__(
        self,
        database: Database,
        sink: WordPressEnrollmentSink,
        *,
        batch_size: int = 50,
        max_attempts: int = 5,
        lease_seconds: int = 300,
    ) -> None:
        self.database = database
        self.sink = sink
        self.batch_size = max(1, min(batch_size, 500))
        self.max_attempts = max(1, max_attempts)
        self.lease_seconds = max(30, lease_seconds)

    def run_once(self, *, now: datetime | None = None) -> int:
        current = now or datetime.now(timezone.utc)
        item_ids = self._claim(current)
        processed = 0
        for item_id in item_ids:
            try:
                self._deliver(item_id, current)
            except Exception as exc:
                self._fail(item_id, current, _safe_error(exc))
                LOGGER.warning("learnpress_sync_failed id=%s", item_id)
                continue
            processed += 1
        if processed:
            LOGGER.info("learnpress_sync_completed size=%s", processed)
        return processed

    def _claim(self, now: datetime) -> list[str]:
        stale_at = now - timedelta(seconds=self.lease_seconds)
        with Session(self.database.engine) as session:
            statement = (
                select(ExternalSyncRequest)
                .where(
                    ExternalSyncRequest.kind == LEARNPRESS_KIND,
                    ExternalSyncRequest.attempts < self.max_attempts,
                    or_(
                        ExternalSyncRequest.status == "pending",
                        (
                            (ExternalSyncRequest.status == "failed")
                            & or_(
                                ExternalSyncRequest.next_attempt_at.is_(None),
                                ExternalSyncRequest.next_attempt_at <= now,
                            )
                        ),
                        (
                            (ExternalSyncRequest.status == "processing")
                            & (ExternalSyncRequest.claimed_at <= stale_at)
                        ),
                    ),
                )
                .order_by(ExternalSyncRequest.created_at, ExternalSyncRequest.id)
                .limit(self.batch_size)
                .with_for_update(skip_locked=True)
            )
            records = list(session.scalars(statement).all())
            for record in records:
                record.status = "processing"
                record.attempts += 1
                record.claimed_at = now
                record.next_attempt_at = None
            session.commit()
            return [record.id for record in records]

    def _deliver(self, item_id: str, now: datetime) -> None:
        with Session(self.database.engine) as session:
            record = session.get(ExternalSyncRequest, item_id)
            if record is None or record.status != "processing":
                return
            user = session.get(User, record.user_id)
            if user is None:
                raise RuntimeError("Usuário da projeção não existe.")
            course_slug = str(record.payload.get("course_slug") or record.course_id)
            wp_user_id = self.sink.wp_user_id(user)
            self.sink.enroll(wp_user_id, course_slug)
            record.status = "done"
            record.claimed_at = None
            record.next_attempt_at = None
            record.completed_at = now
            record.last_error = None
            session.commit()

    def _fail(self, item_id: str, now: datetime, detail: str) -> None:
        with Session(self.database.engine) as session:
            record = session.get(ExternalSyncRequest, item_id)
            if record is None:
                return
            record.status = "failed"
            record.claimed_at = None
            record.last_error = detail
            if record.attempts < self.max_attempts:
                delay = min(600, 2 ** record.attempts * 5)
                record.next_attempt_at = now + timedelta(seconds=delay)
            else:
                record.next_attempt_at = None
            session.commit()


def _safe_error(error_value: Exception) -> str:
    return f"{type(error_value).__name__}: {error_value}"[:500]


def _sink(settings: Settings) -> WordPressTdsClient:
    base_url, api_key = settings.require_wordpress_sync()
    return WordPressTdsClient(base_url, api_key)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Projeção de auto-matrículas Tutor TDS -> LearnPress"
    )
    parser.add_argument("--once", action="store_true")
    arguments = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    settings = Settings.from_environment()
    database = Database(settings.database_url)
    worker = LearnPressSyncWorker(
        database,
        _sink(settings),
        batch_size=settings.external_sync_batch_size,
        max_attempts=settings.external_sync_max_attempts,
        lease_seconds=settings.external_sync_lease_seconds,
    )
    try:
        while True:
            processed = worker.run_once()
            if arguments.once:
                return
            if processed == 0:
                time.sleep(max(5, settings.external_sync_poll_seconds))
    finally:
        database.dispose()


if __name__ == "__main__":
    main()
