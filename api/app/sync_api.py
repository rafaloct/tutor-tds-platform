from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .auth import require_roles
from .database import Database
from .models import LearningEventRecord, SyncLog

router = APIRouter(prefix="/admin/sync", tags=["admin", "sync"])
admin_claims = require_roles("admin")


class SyncQueueStatus(BaseModel):
    pending: int
    processing: int
    synced: int
    failed: int
    exhausted: int
    last_success_at: datetime | None
    last_failure_at: datetime | None


@router.get("/status", response_model=SyncQueueStatus)
def sync_status(
    request: Request,
    _: dict[str, str] = Depends(admin_claims),
) -> SyncQueueStatus:
    database: Database = request.app.state.database
    max_attempts: int = request.app.state.settings.sync_max_attempts
    with Session(database.engine) as session:
        counts = dict(
            session.execute(
                select(
                    LearningEventRecord.sync_status,
                    func.count(LearningEventRecord.event_id),
                ).group_by(LearningEventRecord.sync_status)
            ).all()
        )
        exhausted = session.scalar(
            select(func.count(LearningEventRecord.event_id)).where(
                LearningEventRecord.sync_status == "failed",
                LearningEventRecord.sync_attempts >= max_attempts,
            )
        )
        last_success = session.scalar(
            select(func.max(SyncLog.attempted_at)).where(
                SyncLog.status == "synced"
            )
        )
        last_failure = session.scalar(
            select(func.max(SyncLog.attempted_at)).where(
                SyncLog.status == "failed"
            )
        )
    return SyncQueueStatus(
        pending=counts.get("pending", 0),
        processing=counts.get("processing", 0),
        synced=counts.get("synced", 0),
        failed=counts.get("failed", 0),
        exhausted=int(exhausted or 0),
        last_success_at=last_success,
        last_failure_at=last_failure,
    )
