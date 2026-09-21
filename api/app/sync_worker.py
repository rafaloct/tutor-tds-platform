from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import logging
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Protocol
from urllib import error, parse, request
from uuid import uuid4

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import LearningEventRecord, SyncDeletionRequest, SyncLog

LOGGER = logging.getLogger("tutor_tds.sync")
SHEETS_SCOPE = "https://www.googleapis.com/auth/spreadsheets"
HEADER = [
    "event_id",
    "occurred_at",
    "user_id",
    "course_id",
    "event_type",
    "session_id",
    "active_seconds",
    "validated_seconds",
    "payload_json",
    "synced_at",
]


@dataclass(frozen=True)
class SyncRow:
    event_id: str
    values: list[object]


class EventSink(Protocol):
    def append_missing(self, rows: list[SyncRow]) -> set[str]: ...

    def event_ids(self) -> list[str]: ...
    def delete_event_ids(self, event_ids: list[str]) -> None: ...


class GoogleSheetsSink:
    """Espelho idempotente por event_id usando uma aba exclusiva da API."""

    def __init__(
        self,
        *,
        spreadsheet_id: str,
        cell_range: str,
        service_account_json: str | None,
        service_account_file: str | None,
    ) -> None:
        if not spreadsheet_id:
            raise RuntimeError("GOOGLE_SHEET_ID não configurado.")
        if not service_account_json and not service_account_file:
            raise RuntimeError(
                "Configure GOOGLE_SERVICE_ACCOUNT_JSON ou "
                "GOOGLE_SERVICE_ACCOUNT_FILE."
            )
        self.spreadsheet_id = spreadsheet_id
        self.cell_range = cell_range
        self.credentials = _credentials(
            service_account_json=service_account_json,
            service_account_file=service_account_file,
        )

    def event_ids(self) -> list[str]:
        return self._event_column()[1:]

    def _event_column(self) -> list[str]:
        # A primeira coluna é reservada ao event_id. Ler antes do append torna
        # seguro repetir um lote após timeout/crash entre o Google e o commit.
        first_column = self.cell_range.split(":", 1)[0]
        url = self._values_url(first_column) + "?majorDimension=COLUMNS"
        response = self._request("GET", url)
        values = response.get("values", [])
        if not values:
            return []
        column = [str(value) for value in values[0]]
        if column and column[0] != "event_id":
            raise RuntimeError("A aba de eventos não possui o cabeçalho esperado.")
        return [value for value in column if value]

    def delete_event_ids(self, event_ids: list[str]) -> None:
        if not event_ids:
            return
        first_column = self.cell_range.split(":", 1)[0]
        values = self._request("GET", self._values_url(first_column) + "?majorDimension=COLUMNS").get("values", [])
        column = values[0] if values else []
        wanted = set(event_ids)
        sheet = self.cell_range.split("!", 1)[0]
        end_column = self.cell_range.rsplit(":", 1)[-1]
        ranges = [f"{sheet}!A{index}:{end_column}{index}" for index, value in enumerate(column, start=1) if value in wanted]
        if ranges:
            spreadsheet_id = parse.quote(self.spreadsheet_id, safe="")
            self._request("POST", f"https://sheets.googleapis.com/v4/spreadsheets/{spreadsheet_id}/values:batchClear", {"ranges": ranges})

    def append_missing(self, rows: list[SyncRow]) -> set[str]:
        if not rows:
            return set()
        column = self._event_column()
        existing = set(column[1:])
        missing = [row for row in rows if row.event_id not in existing]
        values: list[list[object]] = []
        if not column:
            values.append(HEADER)
        values.extend(row.values for row in missing)
        if values:
            query = parse.urlencode(
                {"valueInputOption": "RAW", "insertDataOption": "INSERT_ROWS"}
            )
            self._request(
                "POST",
                f"{self._values_url(self.cell_range)}:append?{query}",
                {"majorDimension": "ROWS", "values": values},
            )
        return {row.event_id for row in rows}

    def _values_url(self, cell_range: str) -> str:
        spreadsheet_id = parse.quote(self.spreadsheet_id, safe="")
        encoded_range = parse.quote(cell_range, safe="")
        return (
            "https://sheets.googleapis.com/v4/spreadsheets/"
            f"{spreadsheet_id}/values/{encoded_range}"
        )

    def _request(
        self,
        method: str,
        url: str,
        body: dict[str, object] | None = None,
    ) -> dict[str, object]:
        from google.auth.transport.requests import Request as GoogleRequest

        if not self.credentials.valid:
            self.credentials.refresh(GoogleRequest())
        data = json.dumps(body).encode() if body is not None else None
        headers = {"Authorization": f"Bearer {self.credentials.token}"}
        if data is not None:
            headers["Content-Type"] = "application/json"
        call = request.Request(url, data=data, headers=headers, method=method)
        try:
            with request.urlopen(call, timeout=20) as response:
                return json.loads(response.read() or b"{}")
        except error.HTTPError as exc:
            # Não registrar corpo da resposta: ele pode conter detalhes da
            # conta Google. O status é suficiente para o retry operacional.
            raise RuntimeError(f"Google Sheets respondeu HTTP {exc.code}.") from exc
        except error.URLError as exc:
            raise RuntimeError("Google Sheets indisponível.") from exc


class SyncWorker:
    def __init__(
        self,
        database: Database,
        sink: EventSink,
        *,
        batch_size: int = 100,
        max_attempts: int = 3,
        lease_seconds: int = 300,
        pseudonym_secret: str,
    ) -> None:
        self.database = database
        self.sink = sink
        self.batch_size = max(1, min(batch_size, 500))
        self.max_attempts = max(1, max_attempts)
        self.lease_seconds = max(30, lease_seconds)
        if len(pseudonym_secret) < 32:
            raise RuntimeError("SHEETS_PSEUDONYM_SECRET deve ter pelo menos 32 caracteres.")
        self.pseudonym_secret = pseudonym_secret

    def run_once(self, *, now: datetime | None = None) -> int:
        current = now or datetime.now(timezone.utc)
        self._purge(current)
        event_ids = self._claim(current)
        if not event_ids:
            return 0
        with Session(self.database.engine) as session:
            records = list(
                session.scalars(
                    select(LearningEventRecord)
                    .where(LearningEventRecord.event_id.in_(event_ids))
                    .order_by(
                        LearningEventRecord.occurred_at,
                        LearningEventRecord.event_id,
                    )
                ).all()
            )
        rows = [_sync_row(record, current, self.pseudonym_secret) for record in records]
        try:
            completed = self.sink.append_missing(rows)
            if completed != {row.event_id for row in rows}:
                raise RuntimeError("O destino não confirmou o lote completo.")
        except Exception as exc:
            self._fail(event_ids, current, _safe_error(exc))
            LOGGER.warning("sync_batch_failed size=%s", len(event_ids))
            return 0
        self._complete(event_ids, current)
        LOGGER.info("sync_batch_completed size=%s", len(event_ids))
        return len(event_ids)

    def reconcile(self) -> dict[str, object]:
        sheet_ids = self.sink.event_ids()
        with Session(self.database.engine) as session:
            database_ids = {
                _pseudonym(self.pseudonym_secret, item)
                for item in session.scalars(select(LearningEventRecord.event_id))
            }
        sheet_set = set(sheet_ids)
        duplicates = sorted(
            event_id for event_id in sheet_set if sheet_ids.count(event_id) > 1
        )
        return {
            "database_count": len(database_ids),
            "sheet_count": len(sheet_ids),
            "missing_in_sheet": sorted(database_ids - sheet_set),
            "unknown_in_sheet": sorted(sheet_set - database_ids),
            "duplicate_in_sheet": duplicates,
        }

    def _purge(self, now: datetime) -> None:
        with Session(self.database.engine) as session:
            requests = list(session.scalars(select(SyncDeletionRequest).where(
                SyncDeletionRequest.status.in_({"pending", "failed"}),
                SyncDeletionRequest.attempts < self.max_attempts,
            ).limit(self.batch_size)))
            if not requests:
                return
            for item in requests:
                item.attempts += 1
            session.commit()
            try:
                self.sink.delete_event_ids([
                    _pseudonym(self.pseudonym_secret, item.event_id) for item in requests
                ])
            except Exception as exc:
                for item in requests:
                    item.status = "failed"; item.last_error = _safe_error(exc)
                session.commit(); return
            for item in requests:
                item.status = "purged"; item.completed_at = now; item.last_error = None
            session.commit()

    def _claim(self, now: datetime) -> list[str]:
        stale_at = now - timedelta(seconds=self.lease_seconds)
        with Session(self.database.engine) as session:
            statement = (
                select(LearningEventRecord)
                .where(
                    LearningEventRecord.sync_attempts < self.max_attempts,
                    or_(
                        LearningEventRecord.sync_status == "pending",
                        (
                            (LearningEventRecord.sync_status == "failed")
                            & or_(
                                LearningEventRecord.sync_next_attempt_at.is_(None),
                                LearningEventRecord.sync_next_attempt_at <= now,
                            )
                        ),
                        (
                            (LearningEventRecord.sync_status == "processing")
                            & (LearningEventRecord.sync_claimed_at <= stale_at)
                        ),
                    ),
                )
                .order_by(
                    LearningEventRecord.occurred_at,
                    LearningEventRecord.event_id,
                )
                .limit(self.batch_size)
                .with_for_update(skip_locked=True)
            )
            records = list(session.scalars(statement).all())
            for record in records:
                record.sync_status = "processing"
                record.sync_attempts += 1
                record.sync_claimed_at = now
                record.sync_next_attempt_at = None
            session.commit()
            return [record.event_id for record in records]

    def _complete(self, event_ids: list[str], now: datetime) -> None:
        with Session(self.database.engine) as session:
            records = session.scalars(
                select(LearningEventRecord).where(
                    LearningEventRecord.event_id.in_(event_ids),
                    LearningEventRecord.sync_status == "processing",
                )
            ).all()
            for record in records:
                record.sync_status = "synced"
                record.sync_claimed_at = None
                record.sync_next_attempt_at = None
                session.add(
                    SyncLog(
                        id=str(uuid4()),
                        event_id=record.event_id,
                        status="synced",
                        attempted_at=now,
                    )
                )
            session.commit()

    def _fail(self, event_ids: list[str], now: datetime, detail: str) -> None:
        with Session(self.database.engine) as session:
            records = session.scalars(
                select(LearningEventRecord).where(
                    LearningEventRecord.event_id.in_(event_ids),
                    LearningEventRecord.sync_status == "processing",
                )
            ).all()
            for record in records:
                record.sync_status = "failed"
                record.sync_claimed_at = None
                if record.sync_attempts < self.max_attempts:
                    delay = min(300, 2 ** record.sync_attempts * 5)
                    record.sync_next_attempt_at = now + timedelta(seconds=delay)
                else:
                    record.sync_next_attempt_at = None
                session.add(
                    SyncLog(
                        id=str(uuid4()),
                        event_id=record.event_id,
                        status="failed",
                        detail=detail,
                        attempted_at=now,
                    )
                )
            session.commit()


def _sync_row(record: LearningEventRecord, synced_at: datetime, secret: str) -> SyncRow:
    occurred_at = _utc(record.occurred_at)
    return SyncRow(
        event_id=_pseudonym(secret, record.event_id),
        values=[
            _pseudonym(secret, record.event_id),
            occurred_at.isoformat(),
            _pseudonym(secret, record.user_id),
            record.course_id,
            record.event_type,
            _pseudonym(secret, record.session_id),
            record.active_seconds,
            record.validated_seconds,
            json.dumps(record.payload, ensure_ascii=False, sort_keys=True),
            _utc(synced_at).isoformat(),
        ],
    )


def _pseudonym(secret: str, value: str) -> str:
    return hmac.new(secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def _credentials(
    *,
    service_account_json: str | None,
    service_account_file: str | None,
):
    from google.oauth2.service_account import Credentials

    if service_account_json:
        try:
            info = json.loads(service_account_json)
        except json.JSONDecodeError as exc:
            raise RuntimeError("GOOGLE_SERVICE_ACCOUNT_JSON inválido.") from exc
        return Credentials.from_service_account_info(info, scopes=[SHEETS_SCOPE])
    assert service_account_file is not None
    path = Path(service_account_file)
    if not path.is_file():
        raise RuntimeError("GOOGLE_SERVICE_ACCOUNT_FILE não encontrado.")
    return Credentials.from_service_account_file(path, scopes=[SHEETS_SCOPE])


def _utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _safe_error(error_value: Exception) -> str:
    return f"{type(error_value).__name__}: {error_value}"[:500]


def _sink(settings: Settings) -> GoogleSheetsSink:
    return GoogleSheetsSink(
        spreadsheet_id=settings.google_sheet_id or "",
        cell_range=settings.google_sheet_range,
        service_account_json=settings.google_service_account_json,
        service_account_file=settings.google_service_account_file,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync Tutor TDS -> Google Sheets")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--reconcile", action="store_true")
    arguments = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    settings = Settings.from_environment()
    database = Database(settings.database_url)
    worker = SyncWorker(
        database,
        _sink(settings),
        batch_size=settings.sync_batch_size,
        max_attempts=settings.sync_max_attempts,
        lease_seconds=settings.sync_lease_seconds,
        pseudonym_secret=settings.sheets_pseudonym_secret or "",
    )
    try:
        if arguments.reconcile:
            print(json.dumps(worker.reconcile(), ensure_ascii=False, sort_keys=True))
            return
        while True:
            processed = worker.run_once()
            if arguments.once:
                return
            if processed == 0:
                time.sleep(max(5, settings.sync_poll_seconds))
    finally:
        database.dispose()


if __name__ == "__main__":
    main()
