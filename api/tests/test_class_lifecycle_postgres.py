"""Opt-in disposable PostgreSQL proof for Issue #138 classroom lifecycle."""

from __future__ import annotations

import os
from datetime import date
from urllib.parse import urlsplit
from uuid import uuid4

import psycopg
import pytest
from alembic import command as migration
from alembic.config import Config
from psycopg import sql
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session

from app.models import (
    Classroom,
    Course,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)
from test_class_lifecycle import (
    lifecycle_api,
    requests_api,
    test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited as _capacity,
    test_plan_team_and_strict_lifecycle_authority as _lifecycle_authority,
    test_prepare_pins_published_version_separates_territory_and_replays as _prepare,
)


@pytest.fixture
def requests_database_url():
    admin = os.getenv("TDS_CLASS_LIFECYCLE_PG_ADMIN_URL")
    if not admin:
        pytest.skip("Disposable loopback PostgreSQL lifecycle proof is opt-in")
    parsed = urlsplit(admin)
    if (
        parsed.scheme != "postgresql"
        or parsed.hostname != "127.0.0.1"
        or parsed.port != 15438
        or parsed.username != "qa_class_lifecycle"
        or parsed.password
        or parsed.path != "/postgres"
        or parsed.query
        or parsed.fragment
    ):
        raise RuntimeError("Refusing non-disposable lifecycle PostgreSQL target")
    name = "qa_class_lifecycle_" + uuid4().hex
    with psycopg.connect(admin, autocommit=True) as conn:
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    try:
        yield (
            admin.rsplit("/", 1)[0] + "/" + name
        ).replace("postgresql://", "postgresql+psycopg://", 1)
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(
                sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name))
            )


def test_postgres_prepare_receipt_and_territory(lifecycle_api):
    _prepare(lifecycle_api)


def test_postgres_capacity_and_coordinator_override(lifecycle_api):
    _capacity(lifecycle_api)


def test_postgres_open_session_blocks_close_other_warnings_do_not(lifecycle_api):
    _lifecycle_authority(lifecycle_api)


def test_postgres_0027_to_0028_constraints_and_downgrade_guards(
    requests_database_url,
):
    engine = create_engine(requests_database_url)
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", requests_database_url)

    migration.upgrade(config, "20261005_0027")
    with engine.connect() as connection:
        assert (
            connection.scalar(text("SELECT version_num FROM alembic_version"))
            == "20261005_0027"
        )

    migration.upgrade(config, "20261005_0028")
    schema = inspect(engine)
    columns = {item["name"] for item in schema.get_columns("classes")}
    assert {
        "offer_municipality",
        "offer_location",
        "lifecycle_revision",
    } <= columns
    constraint_names = {
        item["name"] for item in schema.get_check_constraints("classes")
    }
    assert {
        "ck_classes_status",
        "ck_classes_lifecycle_revision",
    } <= constraint_names
    assert "classroom_command_receipts" in schema.get_table_names()

    migration.downgrade(config, "20261005_0027")
    with engine.connect() as connection:
        assert (
            connection.scalar(text("SELECT version_num FROM alembic_version"))
            == "20261005_0027"
        )
    assert "classroom_command_receipts" not in inspect(engine).get_table_names()

    migration.upgrade(config, "20261005_0028")
    with Session(engine) as session:
        session.add(Institution(id="pg-i1", name="PG Institution"))
        session.add(
            User(
                id="pg-teacher",
                cpf_digest="pg-teacher",
                phone="61999990138",
                name="PG Teacher",
                password_digest="digest",
                role="student",
            )
        )
        session.flush()
        session.add(
            Program(
                id="pg-p1",
                institution_id="pg-i1",
                name="PG Program",
            )
        )
        session.add(
            Course(
                id="pg-course",
                title="PG Course",
                author="TDS",
                content={"sections": []},
                active=True,
            )
        )
        session.flush()
        session.add(
            ProgramCourse(
                program_id="pg-p1",
                course_id="pg-course",
            )
        )
        session.add(
            ProgramMembership(
                user_id="pg-teacher",
                program_id="pg-p1",
                role="teacher",
                status="active",
            )
        )
        session.flush()
        session.add(
            Classroom(
                id="pg-class",
                program_id="pg-p1",
                course_id="pg-course",
                teacher_id="pg-teacher",
                name="PG Territorial Class",
                offer_municipality="Palmas",
                offer_location="Disposable PostgreSQL",
                start_date=date(2026, 10, 11),
                end_date=date(2026, 10, 30),
                status="planned",
                lifecycle_revision=1,
            )
        )
        session.commit()

    with pytest.raises(
        RuntimeError,
        match="Preserve classroom lifecycle history",
    ):
        migration.downgrade(config, "20261005_0027")
    with engine.connect() as connection:
        assert (
            connection.scalar(text("SELECT version_num FROM alembic_version"))
            == "20261005_0028"
        )
    engine.dispose()
