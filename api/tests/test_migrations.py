from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

from app.models import Base


def test_migration_up_and_down(tmp_path: Path) -> None:
    database_path = tmp_path / "migration.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)

    engine = create_engine(database_url)
    command.upgrade(config, "20260920_0001")
    assert "password_digest" not in {
        column["name"] for column in inspect(engine).get_columns("users")
    }

    command.upgrade(config, "head")
    tables = set(inspect(engine).get_table_names())
    assert tables == set(Base.metadata.tables) | {"alembic_version"}
    assert "password_digest" in {
        column["name"] for column in inspect(engine).get_columns("users")
    }

    command.downgrade(config, "20260920_0001")
    assert "password_digest" not in {
        column["name"] for column in inspect(engine).get_columns("users")
    }
    command.downgrade(config, "base")
    remaining = set(inspect(engine).get_table_names())
    assert remaining == {"alembic_version"} or remaining == set()
    engine.dispose()
