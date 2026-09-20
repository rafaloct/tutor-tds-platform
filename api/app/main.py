from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
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
        yield
        database.dispose()

    application = FastAPI(
        title="Tutor TDS API",
        version="0.1.0",
        lifespan=lifespan,
    )
    application.state.database = database

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
