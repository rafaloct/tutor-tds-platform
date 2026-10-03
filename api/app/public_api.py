from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query, Request, Response
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from .course_editor import latest_published_version
from .database import Database
from .models import Course

router = APIRouter(prefix="/public", tags=["public"])

_CACHE_CONTROL = "public, max-age=60, stale-while-revalidate=300"


class PublicCourseProjection(BaseModel):
    slug: str
    title: str
    status: Literal["published"]
    published_version_label: str
    updated_at: datetime
    summary: str | None = None
    cover_public_url: str | None = None
    public_workload_text: str | None = None
    public_audience_text: str | None = None


class PublicCourseCatalog(BaseModel):
    courses: list[PublicCourseProjection]
    offset: int
    limit: int
    total: int


def _explicit_text(content: dict[str, Any], key: str) -> str | None:
    value = content.get(key)
    if not isinstance(value, str):
        return None
    normalized = value.strip()
    return normalized or None


def _public_url(content: dict[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = _explicit_text(content, key)
        if value is not None and value.startswith("https://"):
            return value
    return None


def _serialize_public_course(record: Course, version_number: int) -> dict[str, object]:
    content = record.content if isinstance(record.content, dict) else {}
    payload: dict[str, object] = {
        "slug": record.id,
        "title": record.title,
        "status": "published",
        "published_version_label": f"v{version_number}",
        "updated_at": record.updated_at.isoformat(),
    }

    optional_fields = {
        "summary": _explicit_text(content, "summary"),
        "cover_public_url": _public_url(content, "cover_public_url", "thumbnailUrl"),
        "public_workload_text": _explicit_text(content, "public_workload_text"),
        "public_audience_text": _explicit_text(content, "public_audience_text"),
    }
    payload.update({key: value for key, value in optional_fields.items() if value is not None})
    return payload


def _published_projection(session: Session, record: Course) -> dict[str, object] | None:
    if not record.active:
        return None
    version = latest_published_version(session, record.id)
    if version is None:
        return None
    return _serialize_public_course(record, version.version_number)


@router.get("/courses", response_model=PublicCourseCatalog, response_model_exclude_none=True)
def public_courses(
    request: Request,
    response: Response,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict[str, object]:
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        records = session.scalars(
            select(Course).where(Course.active.is_(True)).order_by(Course.title)
        ).all()
        items = [
            projection
            for record in records
            if (projection := _published_projection(session, record)) is not None
        ]

    response.headers["Cache-Control"] = _CACHE_CONTROL
    return {
        "courses": items[offset : offset + limit],
        "offset": offset,
        "limit": limit,
        "total": len(items),
    }


@router.get("/courses/{slug}", response_model=PublicCourseProjection, response_model_exclude_none=True)
def public_course(slug: str, request: Request, response: Response) -> dict[str, object]:
    db: Database = request.app.state.database
    with Session(db.engine) as session:
        record = session.get(Course, slug)
        projection = None if record is None else _published_projection(session, record)

    if projection is None:
        raise HTTPException(status_code=404, detail="Curso não encontrado.")

    response.headers["Cache-Control"] = _CACHE_CONTROL
    return projection
