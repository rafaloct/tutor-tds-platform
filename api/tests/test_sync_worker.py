from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import Database
from app.models import Base, LearningEventRecord, SyncDeletionRequest, SyncLog, User
from app.sync_worker import SyncRow, SyncWorker, _pseudonym


class MemorySink:
    def __init__(self, event_ids: list[str] | None = None) -> None:
        self.ids = list(event_ids or [])

    def append_missing(self, rows: list[SyncRow]) -> set[str]:
        for row in rows:
            if row.event_id not in self.ids:
                self.ids.append(row.event_id)
        return {row.event_id for row in rows}

    def event_ids(self) -> list[str]:
        return list(self.ids)

    def delete_event_ids(self, event_ids: list[str]) -> None:
        self.ids = [item for item in self.ids if item not in set(event_ids)]


class FailingSink(MemorySink):
    def append_missing(self, rows: list[SyncRow]) -> set[str]:
        raise RuntimeError("falha transitória sem dados sensíveis")


def database_with_event() -> Database:
    database = Database("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(database.engine)
    with Session(database.engine) as session:
        session.add(
            User(
                id="user-1",
                cpf_digest="a" * 64,
                phone="61999990000",
                name="Estudante",
                password_digest="digest",
                role="student",
            )
        )
        session.add(
            LearningEventRecord(
                event_id="event-1",
                user_id="user-1",
                course_id="course-1",
                event_type="page_viewed",
                session_id="session-1",
                occurred_at=datetime(2026, 9, 20, 12, tzinfo=timezone.utc),
                payload={"page_id": "home"},
                sync_status="pending",
            )
        )
        session.commit()
    return database


def test_worker_syncs_without_duplicating_an_already_appended_event() -> None:
    database = database_with_event()
    pseudonym = _pseudonym("s" * 32, "event-1")
    sink = MemorySink([pseudonym])
    now = datetime(2026, 9, 20, 13, tzinfo=timezone.utc)

    processed = SyncWorker(database, sink, pseudonym_secret="s" * 32).run_once(now=now)

    with Session(database.engine) as session:
        event = session.get(LearningEventRecord, "event-1")
        assert event is not None
        assert event.sync_status == "synced"
        assert event.sync_attempts == 1
        assert session.scalar(select(func.count()).select_from(SyncLog)) == 1
    assert processed == 1
    assert sink.ids == [pseudonym]


def test_worker_retries_three_times_then_exhausts_event() -> None:
    database = database_with_event()
    worker = SyncWorker(database, FailingSink(), max_attempts=3, pseudonym_secret="s" * 32)
    now = datetime(2026, 9, 20, 13, tzinfo=timezone.utc)

    assert worker.run_once(now=now) == 0
    assert worker.run_once(now=now + timedelta(seconds=11)) == 0
    assert worker.run_once(now=now + timedelta(seconds=32)) == 0
    assert worker.run_once(now=now + timedelta(hours=1)) == 0

    with Session(database.engine) as session:
        event = session.get(LearningEventRecord, "event-1")
        assert event is not None
        assert event.sync_status == "failed"
        assert event.sync_attempts == 3
        assert event.sync_next_attempt_at is None
        logs = session.scalars(
            select(SyncLog).order_by(SyncLog.attempted_at)
        ).all()
        assert len(logs) == 3
        assert all(log.status == "failed" for log in logs)


def test_reconciliation_reports_missing_unknown_and_duplicate_ids() -> None:
    database = database_with_event()
    report = SyncWorker(
        database,
        MemorySink(["external", "external"]), pseudonym_secret="s" * 32,
    ).reconcile()

    assert report == {
        "database_count": 1,
        "sheet_count": 2,
        "missing_in_sheet": [_pseudonym("s" * 32, "event-1")],
        "unknown_in_sheet": ["external"],
        "duplicate_in_sheet": ["external"],
    }


def test_deletion_tombstone_purges_already_synced_sheet_row_idempotently() -> None:
    database = database_with_event()
    sink = MemorySink()
    worker = SyncWorker(database, sink, pseudonym_secret="s" * 32)
    assert worker.run_once(now=datetime(2026, 9, 20, 13, tzinfo=timezone.utc)) == 1
    assert sink.ids == [_pseudonym("s" * 32, "event-1")]
    with Session(database.engine) as session:
        session.add(SyncDeletionRequest(id="delete-1", event_id="event-1", status="pending"))
        session.commit()
    assert worker.run_once(now=datetime(2026, 9, 20, 14, tzinfo=timezone.utc)) == 0
    with Session(database.engine) as session:
        request = session.get(SyncDeletionRequest, "delete-1")
        assert request is not None and request.status == "purged"
    assert sink.ids == []
