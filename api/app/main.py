from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from .auth import router as auth_router
from .config import Settings
from .database import Database
from .events import router as events_router
from .models import Course


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
    application.include_router(auth_router)
    application.include_router(events_router)

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
            allow_methods=["GET", "POST"],
            allow_headers=["Authorization", "Content-Type"],
        )

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
        return {"courses": [_serialize_course(record) for record in records]}

    @application.get("/courses/{course_id}")
    def course(course_id: str, request: Request) -> dict[str, object]:
        db: Database = request.app.state.database
        with Session(db.engine) as session:
            record = session.get(Course, course_id)
            if record is None or not record.active:
                raise HTTPException(status_code=404, detail="Curso não encontrado.")
            return _serialize_course(record)

    return application


def _serialize_course(record: Course) -> dict[str, object]:
    item = dict(record.content)
    item.update(id=record.id, title=record.title, author=record.author)
    return item


app = create_app()
