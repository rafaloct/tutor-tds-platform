"""Opt-in PostgreSQL proof; never use a shared database or a real provider."""
import os
from datetime import date, datetime, timezone
from uuid import uuid4
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import MetaData, Table, create_engine, inspect, text
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session

from app.certificate_emission import _authorized
from app.context_memberships import bind_student
from app.models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    ClassEnrollment,
    Classroom,
    Course,
    CourseVersion,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)
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
            assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261007_0030"
            assert conn.scalar(text("SELECT count(*) FROM certificate_emission_attempts")) == 0
        command.downgrade(config, "20261001_0020")
        command.upgrade(config, "head")
        with engine.connect() as conn:
            assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261007_0030"
    finally:
        engine.dispose()


@pytest.mark.parametrize("starting_revision", ["20261003_0024", "20261006_0029"])
def test_postgres_dynamic_activity_upgrade_preserves_legacy_attempt(
    requests_database_url, starting_revision
):
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", requests_database_url)
    command.upgrade(config, starting_revision)
    engine = create_engine(requests_database_url)
    try:
        metadata = MetaData()
        users = Table("users", metadata, autoload_with=engine)
        courses = Table("courses", metadata, autoload_with=engine)
        attempts = Table("assessment_attempts", metadata, autoload_with=engine)
        with engine.begin() as conn:
            conn.execute(
                users.insert().values(
                    id="dynamic-migration-user",
                    cpf_digest="d" * 64,
                    phone="61999990000",
                    name="Dynamic migration user",
                    role="student",
                    password_digest="digest",
                )
            )
            conn.execute(
                courses.insert().values(
                    id="dynamic-migration-course",
                    title="Dynamic migration course",
                    author="TDS",
                    content={"sections": []},
                    active=True,
                )
            )
            conn.execute(
                attempts.insert().values(
                    attempt_id="dynamic-legacy-attempt",
                    owner_id="dynamic-migration-user",
                    course_id="dynamic-migration-course",
                    topic="Legacy practice",
                    mode="quiz",
                    revision=1,
                    answers={"0": 1},
                    marked=[],
                    current_index=0,
                    remaining_seconds=0,
                    completed=True,
                    score=1,
                    updated_at=datetime(2026, 10, 7, 12, tzinfo=timezone.utc),
                )
            )

        command.upgrade(config, "head")

        columns = {
            column["name"]
            for column in inspect(engine).get_columns("assessment_attempts")
        }
        assert {"origin", "enrollment_id", "block_version_id"} <= columns
        with engine.connect() as conn:
            assert conn.scalar(
                text("SELECT version_num FROM alembic_version")
            ) == "20261007_0030"
            row = conn.execute(
                text(
                    "SELECT revision, answers, score, origin, organization_id, "
                    "program_id, class_id, membership_id, enrollment_id, "
                    "legacy_enrollment_id, course_version_id, section_id, "
                    "section_version_id, block_id, block_version_id "
                    "FROM assessment_attempts "
                    "WHERE attempt_id = 'dynamic-legacy-attempt'"
                )
            ).one()
        assert row.revision == 1
        assert row.answers == {"0": 1}
        assert row.score == 1
        assert row.origin == "practice"
        assert all(value is None for value in row[4:])
    finally:
        engine.dispose()


def test_postgres_dynamic_activity_provenance_and_one_attempt_constraint(
    requests_database_url,
):
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", requests_database_url)
    command.upgrade(config, "head")
    engine = create_engine(requests_database_url)
    try:
        with Session(engine) as session:
            session.add(Institution(id="dynamic-org", name="Dynamic org"))
            session.flush()
            session.add(Program(id="dynamic-program", institution_id="dynamic-org", name="Dynamic"))
            session.add(
                Course(
                    id="dynamic-course",
                    title="Dynamic course",
                    author="TDS",
                    content={"sections": []},
                    active=True,
                )
            )
            session.add(
                User(
                    id="dynamic-owner",
                    cpf_digest="e" * 64,
                    phone="61999990000",
                    name="Dynamic owner",
                    password_digest="digest",
                    role="teacher",
                )
            )
            session.flush()
            session.add(ProgramCourse(program_id="dynamic-program", course_id="dynamic-course"))
            session.add(
                ProgramMembership(
                    user_id="dynamic-owner",
                    program_id="dynamic-program",
                    role="teacher",
                    status="active",
                )
            )
            session.flush()
            session.add(
                CourseVersion(
                    id="dynamic-version",
                    course_id="dynamic-course",
                    program_id="dynamic-program",
                    creator_user_id="dynamic-owner",
                    version_number=1,
                    revision=1,
                    status="published",
                    content={"sections": []},
                )
            )
            session.flush()
            session.add(
                Classroom(
                    id="dynamic-class",
                    program_id="dynamic-program",
                    course_id="dynamic-course",
                    course_version_id="dynamic-version",
                    teacher_id="dynamic-owner",
                    name="Dynamic class",
                    start_date=date(2026, 1, 1),
                    end_date=date(2026, 12, 31),
                    status="active",
                )
            )
            session.add(
                Enrollment(
                    id="dynamic-legacy-enrollment",
                    user_id="dynamic-owner",
                    program_id="dynamic-program",
                    course_id="dynamic-course",
                    status="active",
                )
            )
            session.flush()
            link = ClassEnrollment(
                class_id="dynamic-class",
                user_id="dynamic-owner",
                enrollment_id="dynamic-legacy-enrollment",
                program_id="dynamic-program",
                course_id="dynamic-course",
                status="active",
            )
            session.add(link)
            session.flush()
            bind_student(session, session.get(Classroom, "dynamic-class"), link)
            session.commit()
            context = {
                "organization_id": "dynamic-org",
                "program_id": "dynamic-program",
                "class_id": "dynamic-class",
                "membership_id": link.membership_id,
                "enrollment_id": link.context_id,
                "legacy_enrollment_id": "dynamic-legacy-enrollment",
                "course_version_id": "dynamic-version",
                "section_id": "section",
                "section_version_id": "section-version",
                "block_id": "block",
                "block_version_id": "block-version",
            }

        def attempt(identity: str) -> AssessmentAttemptRecord:
            return AssessmentAttemptRecord(
                attempt_id=identity,
                owner_id="dynamic-owner",
                course_id="dynamic-course",
                origin="published_block",
                **context,
                topic="Dynamic",
                mode="quiz",
                revision=1,
                answers={"0": 0},
                marked=[],
                current_index=0,
                remaining_seconds=0,
                completed=True,
                score=1,
                updated_at=datetime(2026, 10, 7, 12, tzinfo=timezone.utc),
            )

        with Session(engine) as session:
            session.add(attempt("dynamic-attempt-one"))
            session.commit()
        with pytest.raises(IntegrityError), Session(engine) as session:
            session.add(attempt("dynamic-attempt-two"))
            session.commit()
        with pytest.raises(IntegrityError), Session(engine) as session:
            session.add(
                AssessmentAttemptRecord(
                    attempt_id="dynamic-incomplete-context",
                    owner_id="dynamic-owner",
                    course_id="dynamic-course",
                    origin="published_block",
                    topic="Dynamic",
                    mode="quiz",
                    revision=1,
                    answers={},
                    marked=[],
                    current_index=0,
                    remaining_seconds=0,
                    completed=False,
                    score=0,
                    updated_at=datetime(2026, 10, 7, 12, tzinfo=timezone.utc),
                )
            )
            session.commit()
        with pytest.raises(IntegrityError), Session(engine) as session:
            session.add(
                AssessmentContentRecord(
                    id="dynamic-invalid-origin",
                    origin="laundered",
                    owner_id="dynamic-owner",
                    course_id="dynamic-course",
                    topic="Dynamic",
                    mode="quiz",
                    title="Dynamic",
                    duration_seconds=0,
                    questions=[],
                    answer_key=[],
                    content_digest="f" * 64,
                )
            )
            session.commit()
        with engine.connect() as conn:
            index_definition = conn.scalar(
                text(
                    "SELECT indexdef FROM pg_indexes "
                    "WHERE schemaname = current_schema() "
                    "AND indexname = 'uq_assessment_attempts_published_block'"
                )
            )
            assert index_definition is not None
            normalized_index = index_definition.lower()
            assert "unique index" in normalized_index
            assert "where" in normalized_index
            assert "origin" in normalized_index
            assert "published_block" in normalized_index
            assert conn.scalar(
                text(
                    "SELECT count(*) FROM assessment_attempts "
                    "WHERE origin = 'published_block'"
                )
            ) == 1
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
        assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261007_0030"
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
        assert conn.scalar(text("SELECT version_num FROM alembic_version")) == "20261007_0030"
