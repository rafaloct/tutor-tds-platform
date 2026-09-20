from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

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


def test_existing_enrollment_is_backfilled_into_complete_hierarchy(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "legacy-enrollment.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    engine = create_engine(database_url)
    command.upgrade(config, "20260920_0002")

    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO courses "
                "(id, title, author, content, active) "
                "VALUES ('course-1', 'Curso', 'TDS', '{}', 1)"
            )
        )
        connection.execute(
            text(
                "INSERT INTO users "
                "(id, cpf_digest, phone, name, role, password_digest) "
                "VALUES ('user-1', :cpf, '61999990000', 'Pessoa', "
                "'student', 'digest')"
            ),
            {"cpf": "a" * 64},
        )
        connection.execute(
            text(
                "INSERT INTO enrollments (id, user_id, course_id, status) "
                "VALUES ('enrollment-1', 'user-1', 'course-1', 'active')"
            )
        )

    command.upgrade(config, "head")

    with engine.connect() as connection:
        enrollment = connection.execute(
            text(
                "SELECT user_id, program_id, course_id FROM enrollments "
                "WHERE id = 'enrollment-1'"
            )
        ).one()
        membership = connection.execute(
            text(
                "SELECT role, status FROM program_memberships "
                "WHERE user_id = 'user-1' AND program_id = :program_id"
            ),
            {"program_id": enrollment.program_id},
        ).one()
        course_link = connection.execute(
            text(
                "SELECT COUNT(*) FROM program_courses "
                "WHERE program_id = :program_id AND course_id = 'course-1'"
            ),
            {"program_id": enrollment.program_id},
        ).scalar_one()

    assert enrollment.user_id == "user-1"
    assert enrollment.program_id == "legacy-program"
    assert membership == ("student", "active")
    assert course_link == 1
    engine.dispose()
