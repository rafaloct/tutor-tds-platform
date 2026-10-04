"""Opt-in PostgreSQL proof; never use a shared database or a real provider."""
import os
from uuid import uuid4
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.certificate_emission import _authorized
from test_certificate_emission_candidate import (
    candidate, requests_api,
    test_concurrent_api_reservation_sends_at_most_once as _concurrent,
)
from test_certificate_policy_candidate import (
    institutional,
    test_capacitado_is_separate_and_full_document_signatures_lead_to_candidate_valid as _policy_lifecycle,
)


@pytest.fixture
def requests_database_url():
    admin = os.getenv("TDS_CERTIFICATE_PG_ADMIN_URL")
    if not admin:
        pytest.skip("Set disposable loopback TDS_CERTIFICATE_PG_ADMIN_URL")
    parsed = urlsplit(admin)
    if (parsed.scheme != "postgresql" or parsed.hostname != "127.0.0.1"
            or parsed.port != 15439 or parsed.username != "qa_certificate"
            or parsed.password or parsed.path != "/postgres" or parsed.query or parsed.fragment):
        raise RuntimeError("Refusing non-disposable PostgreSQL target")
    name = "qa_certificate_" + uuid4().hex
    with psycopg.connect(admin, autocommit=True) as conn:
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    url = admin.rsplit("/", 1)[0] + "/" + name
    try:
        yield url.replace("postgresql://", "postgresql+psycopg://", 1)
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))


def test_postgres_empty_upgrade_downgrade_and_reupgrade(requests_database_url):
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", requests_database_url)
    command.upgrade(config, "head")
    engine = create_engine(requests_database_url)
    try:
        with engine.connect() as conn:
            assert conn.scalar(text("SELECT version()" )).startswith("PostgreSQL 17.11")
            assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261003_0026"
            assert conn.scalar(text("SELECT count(*) FROM certificate_emission_attempts")) == 0
        command.downgrade(config, "20261001_0020")
        command.upgrade(config, "head")
        with engine.connect() as conn:
            assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261003_0026"
    finally:
        engine.dispose()


def test_postgres_candidate_authorization_holds_request_row_lock(candidate):
    _, engine, _, request_id = candidate
    with Session(engine) as holder:
        _authorized(holder, request_id, "learner")
        with engine.connect() as contender:
            contender.execute(text("SET LOCAL lock_timeout = '200ms'"))
            with pytest.raises(OperationalError) as failure:
                contender.execute(text("SELECT id FROM certificate_requests WHERE id = :id FOR UPDATE"), {"id": request_id})
            assert getattr(failure.value.orig, "sqlstate", None) == "55P03"
            contender.rollback()
        holder.rollback()
    with engine.begin() as conn:
        result = conn.scalar(text("SELECT id FROM certificate_requests WHERE id = :id FOR UPDATE NOWAIT"), {"id": request_id})
        assert result == request_id


def test_postgres_concurrent_candidate_sends_at_most_once(candidate):
    _concurrent(candidate)
    _, engine, _, _ = candidate
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", str(engine.url))
    with pytest.raises(RuntimeError, match="emission history"):
        command.downgrade(config, "20261001_0020")
    with engine.connect() as conn:
        assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261003_0026"
        assert conn.scalar(text("SELECT count(*) FROM certificate_emission_attempts")) == 1


def test_postgres_institutional_policy_generated_capacitado_and_valid_are_distinct(institutional):
    _policy_lifecycle(institutional)


def test_postgres_populated_0020_upgrade_preserves_context_and_policy_guard(candidate):
    _, engine, _, request_id = candidate
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", str(engine.url))
    command.downgrade(config, "20261001_0020")
    with engine.connect() as conn:
        before = conn.execute(text("SELECT id, user_id, enrollment_id, course_version_id FROM certificate_requests WHERE id = :id"), {"id": request_id}).one()
        baseline_count = conn.scalar(text("SELECT count(*) FROM student_baselines"))
    command.upgrade(config, "head")
    with engine.begin() as conn:
        after = conn.execute(text("SELECT id, user_id, enrollment_id, course_version_id FROM certificate_requests WHERE id = :id"), {"id": request_id}).one()
        assert after == before
        assert conn.scalar(text("SELECT count(*) FROM student_baselines")) == baseline_count
        conn.execute(text("UPDATE classes SET certificate_policy = '{}' WHERE id = 'c1'"))
    with pytest.raises(RuntimeError, match="policy and lifecycle"):
        command.downgrade(config, "20261003_0021")
    with engine.connect() as conn:
        assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261003_0026"
