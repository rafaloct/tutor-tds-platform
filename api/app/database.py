from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool


def normalize_database_url(url: str) -> str:
    """Select the installed PostgreSQL driver without rewriting credentials or TLS."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix):]
    return url


class Database:
    def __init__(self, url: str) -> None:
        url = normalize_database_url(url)
        options: dict[str, object] = {"pool_pre_ping": True}
        if url == "sqlite+pysqlite:///:memory:":
            options.update(
                connect_args={"check_same_thread": False},
                poolclass=StaticPool,
            )
        elif url.startswith("sqlite"):
            options["connect_args"] = {"check_same_thread": False}
        self.engine: Engine = create_engine(url, **options)

    def session(self) -> Iterator[Session]:
        with Session(self.engine) as session:
            yield session

    def dispose(self) -> None:
        self.engine.dispose()
