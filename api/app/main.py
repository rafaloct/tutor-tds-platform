from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from .analytics import router as analytics_router
from .assessment_sync import router as assessment_sync_router
from .assessment_sync import content_router as assessment_content_router
from .auth import router as auth_router
from .classrooms import admin_router as classroom_admin_router
from .classrooms import router as classroom_router
from .certificates import router as certificates_router
from .commercial import router as commercial_router
from .config import Settings
from .course_editor import router as course_editor_router, latest_published_version, legacy_version_id
from .database import Database
from .events import router as events_router
from .evidence import router as evidence_router
from .hours import router as hours_router
from .media import admin_router as media_admin_router
from .media import creator_router as creator_media_router
from .media import router as media_router
from .models import Course
from .observability import install_observability
from .organizations import router as organizations_router
from .sync_api import router as sync_router


def create_app(
    *,
    database_url: str | None = None,
    settings: Settings | None = None,
) -> FastAPI:
    resolved = settings or Settings.from_environment()
    database = Database(database_url or resolved.database_url)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        try:
            resolved.require_auth_secrets()
            yield
        finally:
            database.dispose()

    application = FastAPI(
        title="Tutor TDS API",
        version="0.1.0",
        lifespan=lifespan,
    )
    application.state.database = database
    application.state.settings = resolved
    install_observability(application)
    application.include_router(auth_router)
    application.include_router(assessment_content_router)
    application.include_router(assessment_sync_router)
    application.include_router(events_router)
    application.include_router(evidence_router)
    application.include_router(organizations_router)
    application.include_router(classroom_admin_router)
    application.include_router(classroom_router)
    application.include_router(certificates_router)
    application.include_router(commercial_router)
    application.include_router(hours_router)
    application.include_router(media_admin_router)
    application.include_router(media_router)
    application.include_router(creator_media_router)
    application.include_router(analytics_router)
    application.include_router(sync_router)
    application.include_router(course_editor_router)

    @application.exception_handler(RequestValidationError)
    async def validation_error(
        _: Request, error: RequestValidationError
    ) -> JSONResponse:
        sanitized = [
            {
                key: value
                for key, value in item.items()
                if key not in {"input", "ctx"}
            }
            for item in error.errors()
        ]
        return JSONResponse(status_code=422, content={"detail": sanitized})

    if resolved.allowed_origins:
        application.add_middleware(
            CORSMiddleware,
            allow_origins=list(resolved.allowed_origins),
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type"],
        )

    @application.get("/live")
    def live() -> dict[str, str]:
        """Process liveness probe; deliberately does not depend on PostgreSQL."""
        return {"status": "ok"}

    @application.get("/health")
    def health(request: Request) -> dict[str, str]:
        db: Database = request.app.state.database
        with Session(db.engine) as session:
            session.execute(text("SELECT 1"))
        return {"status": "ok", "database": "available"}

    @application.get("/courses")
    def courses(request: Request) -> dict[str, list[dict[str, object]]]:
        db: Database = request.app.state.database
        with Session(db.engine) as session:
            records = session.scalars(
                select(Course).where(Course.active.is_(True)).order_by(Course.title)
            ).all()
            return {"courses": [_serialize_course(record, session) for record in records]}

    @application.get("/courses/{course_id}")
    def course(course_id: str, request: Request) -> dict[str, object]:
        db: Database = request.app.state.database
        with Session(db.engine) as session:
            record = session.get(Course, course_id)
            if record is None or not record.active:
                raise HTTPException(status_code=404, detail="Curso não encontrado.")
            return _serialize_course(record, session)

    return application


def _serialize_course(record: Course, session: Session) -> dict[str, object]:
    item = dict(record.content)
    item.update(id=record.id, title=record.title, author=record.author)
    version = latest_published_version(session, record.id)
    if version is not None:
        item.update(course_version_id=version.id, version_id=version.id,
                    version_number=version.version_number,
                    legacy_progress_compatible=version.id == legacy_version_id(record.id))
    return item


app = create_app()
