from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import IntegrityError

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
    inspected_ledger_columns = inspect(engine).get_columns("revenue_ledger")
    ledger_columns = {column["name"] for column in inspected_ledger_columns}
    assert "creator_score_id" in ledger_columns
    ledger_nullability = {
        column["name"]: column["nullable"] for column in inspected_ledger_columns
    }
    assert ledger_nullability["creator_score_id"] is False
    assert ledger_nullability["source_event_id"] is False
    ledger_fks = {tuple(item["constrained_columns"]) for item in inspect(engine).get_foreign_keys("revenue_ledger")}
    assert ("creator_score_id",) in ledger_fks
    assert ("source_event_id",) in ledger_fks
    ledger_uniques = {tuple(item["column_names"]) for item in inspect(engine).get_unique_constraints("revenue_ledger")}
    assert ("source_event_id", "rule_version", "entry_type") in ledger_uniques
    attempt_columns = {
        column["name"]: column["nullable"]
        for column in inspect(engine).get_columns("assessment_attempts")
    }
    assert attempt_columns["owner_id"] is False
    assert attempt_columns["revision"] is False
    assert attempt_columns["updated_at"] is False
    assert attempt_columns["assessment_content_id"] is True
    attempt_fks = {
        tuple(item["constrained_columns"])
        for item in inspect(engine).get_foreign_keys("assessment_attempts")
    }
    assert ("owner_id",) in attempt_fks
    assert ("course_id",) in attempt_fks
    assert ("assessment_content_id",) in attempt_fks
    attempt_indexes = {
        item["name"] for item in inspect(engine).get_indexes("assessment_attempts")
    }
    assert "ix_assessment_attempts_owner_updated" in attempt_indexes
    assert "ix_assessment_attempts_content" in attempt_indexes
    content_columns = {
        column["name"]
        for column in inspect(engine).get_columns("assessment_contents")
    }
    assert content_columns == {
        "id", "owner_id", "course_id", "topic", "mode", "title",
        "duration_seconds", "questions", "answer_key", "content_digest",
        "created_at",
    }
    transition_columns = {
        column["name"] for column in inspect(engine).get_columns("media_status_transitions")
    }
    assert transition_columns == {
        "id", "media_id", "from_status", "to_status", "actor_user_id",
        "actor_role", "reason", "occurred_at",
    }
    rating_pk = inspect(engine).get_pk_constraint("media_ratings")["constrained_columns"]
    assert set(rating_pk) == {"media_id", "user_id"}
    grant_columns = {
        column["name"]
        for column in inspect(engine).get_columns("media_playback_grants")
    }
    assert grant_columns == {
        "id", "token_digest", "media_id", "user_id", "expires_at", "created_at"
    }
    with engine.connect() as connection:
        trigger_names = {
            row[0]
            for row in connection.execute(
                text("SELECT name FROM sqlite_master WHERE type = 'trigger'")
            )
        }
    assert {
        "media_status_transitions_no_update",
        "media_status_transitions_no_delete",
        "assessment_contents_immutable",
    } <= trigger_names

    command.downgrade(config, "20260920_0001")
    assert "password_digest" not in {
        column["name"] for column in inspect(engine).get_columns("users")
    }
    command.downgrade(config, "base")
    remaining = set(inspect(engine).get_table_names())
    assert remaining == {"alembic_version"} or remaining == set()
    engine.dispose()


def test_cpf_activation_issuer_index_upgrade_and_downgrade(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "cpf-activation-index.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    engine = create_engine(database_url)

    command.upgrade(config, "20261003_0026")
    foreign_keys = inspect(engine).get_foreign_keys("cpf_activation_tokens")
    issuer_foreign_key = next(
        item for item in foreign_keys if item["constrained_columns"] == ["issued_by"]
    )
    assert issuer_foreign_key["options"]["ondelete"] == "SET NULL"
    assert "ix_cpf_activation_tokens_issued_by" not in {
        item["name"] for item in inspect(engine).get_indexes("cpf_activation_tokens")
    }

    command.upgrade(config, "head")
    indexes = {
        item["name"]: item["column_names"]
        for item in inspect(engine).get_indexes("cpf_activation_tokens")
    }
    assert indexes["ix_cpf_activation_tokens_issued_by"] == ["issued_by"]

    command.downgrade(config, "20261003_0026")
    assert "ix_cpf_activation_tokens_issued_by" not in {
        item["name"] for item in inspect(engine).get_indexes("cpf_activation_tokens")
    }
    foreign_keys = inspect(engine).get_foreign_keys("cpf_activation_tokens")
    issuer_foreign_key = next(
        item for item in foreign_keys if item["constrained_columns"] == ["issued_by"]
    )
    assert issuer_foreign_key["options"]["ondelete"] == "SET NULL"
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

    command.upgrade(config, "20260920_0012")

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
    with engine.begin() as connection:
        connection.execute(text(
            "INSERT INTO classes (id, program_id, course_id, teacher_id, name, start_date, end_date, status) "
            "VALUES ('class-ledger', :program_id, 'course-1', 'user-1', 'Turma', '2026-01-01', '2026-12-01', 'active')"
        ), {"program_id": enrollment.program_id})
        connection.execute(text(
            "INSERT INTO media_assets (id, institution_id, program_id, course_id, module_id, creator_user_id, title, description, competency_id, provider, provider_asset_id, duration_seconds, captions, visibility, offline_policy, status, rights_confirmed, followup_activity_id) "
            "VALUES ('media-1', 'legacy-institution', :program_id, 'course-1', 'module-1', 'user-1', 'Video', '', 'competency-1', 'youtube', 'abcDEF12345', 60, '[]', 'enrolled', 'forbidden', 'published', 1, 'quiz-1')"
        ), {"program_id": enrollment.program_id})
        connection.execute(text(
            "INSERT INTO media_events (event_id, media_id, user_id, enrollment_id, course_id, module_id, session_id, event_type, qualified, occurred_at) "
            "VALUES ('media-event-1', 'media-1', 'user-1', 'enrollment-1', 'course-1', 'module-1', 'session-1', 'video_completed', 1, '2026-09-20 12:00:00')"
        ))
        connection.execute(text(
            "INSERT INTO creator_scores (id, institution_id, program_id, creator_user_id, media_id, rule_version, window_start, window_end, score_basis_points, calculation_snapshot) "
            "VALUES ('score-1', 'legacy-institution', :program_id, 'user-1', 'media-1', 'creator-score-v1', '2026-09-01', '2026-10-01', 5000, '{}')"
        ), {"program_id": enrollment.program_id})
        connection.execute(text(
            "INSERT INTO revenue_ledger (id, creator_score_id, institution_id, program_id, creator_user_id, media_id, source_event_id, rule_version, entry_type, amount_minor, currency, status, idempotency_key, calculation_snapshot) "
            "VALUES ('ledger-1', 'score-1', 'legacy-institution', :program_id, 'user-1', 'media-1', 'media-event-1', 'creator-score-v1', 'accrual', 100, 'BRL', 'simulated', 'ledger:key:1', '{}')"
        ), {"program_id": enrollment.program_id})
        connection.execute(text(
            "INSERT INTO class_sessions (id, class_id, starts_at, ends_at, status, opened_by, checkin_token_digest, token_expires_at) "
            "VALUES ('evidence-session-1', 'class-ledger', '2026-09-20 10:00:00', '2026-09-20 12:00:00', 'open', 'user-1', :digest, '2026-09-20 10:10:00')"
        ), {"digest": "d" * 64})
        connection.execute(text(
            "INSERT INTO evidence_items (id, class_id, session_id, user_id, evidence_type, occurred_at, confidence_basis_points, review_status, item_digest, metadata_json) "
            "VALUES ('evidence-1', 'class-ledger', 'evidence-session-1', 'user-1', 'attendance', '2026-09-20 10:01:00', 10000, 'pending', :digest, '{}')"
        ), {"digest": "e" * 64})
        connection.execute(text(
            "INSERT INTO assessment_attempts (attempt_id, owner_id, course_id, topic, mode, revision, answers, marked, current_index, remaining_seconds, completed, score, updated_at) "
            "VALUES ('attempt-1', 'user-1', 'course-1', 'Tópico', 'quiz', 1, '{\"0\": 2}', '[1]', 1, 0, 0, 0, '2026-09-20 12:00:00')"
        ))
        assert connection.execute(text("SELECT COUNT(*) FROM revenue_ledger")).scalar_one() == 1
        assert connection.execute(text("SELECT COUNT(*) FROM evidence_items")).scalar_one() == 1
        assert connection.execute(text("SELECT COUNT(*) FROM assessment_attempts")).scalar_one() == 1

    command.upgrade(config, "head")

    with engine.begin() as connection:
        legacy_version = connection.execute(text(
            "SELECT id, content, status FROM course_versions WHERE course_id = 'course-1'"
        )).one()
        assert legacy_version.status == "published"
        assert connection.execute(text(
            "SELECT course_version_id FROM classes WHERE id = 'class-ledger'"
        )).scalar_one() == legacy_version.id
        backfilled = connection.execute(text(
            "SELECT from_status, to_status, actor_user_id, actor_role "
            "FROM media_status_transitions WHERE media_id = 'media-1'"
        )).one()
        assert backfilled == (None, "published", "user-1", "migration")
        legacy_content_id = connection.execute(text(
            "SELECT assessment_content_id FROM assessment_attempts "
            "WHERE attempt_id = 'attempt-1'"
        )).scalar_one_or_none()
        assert legacy_content_id is None
        connection.execute(text(
            "INSERT INTO assessment_contents "
            "(id, owner_id, course_id, topic, mode, title, duration_seconds, "
            "questions, answer_key, content_digest) VALUES "
            "('content-1', 'user-1', 'course-1', 'Tópico', 'quiz', 'Quiz', 0, "
            ":questions, :answer_key, :digest)"
        ), {
            "questions": '[{"question":"Q?","options":["A","B"],"topic":"T"}]',
            "answer_key": '[{"correct_index":0,"explanation":"E"}]',
            "digest": "c" * 64,
        })
        connection.execute(text(
            "UPDATE assessment_attempts SET assessment_content_id = 'content-1' "
            "WHERE attempt_id = 'attempt-1'"
        ))
        connection.execute(text(
            "INSERT INTO media_status_transitions (id, media_id, from_status, to_status, actor_user_id, actor_role, reason) "
            "VALUES ('transition-1', 'media-1', 'published', 'blocked', 'user-1', 'coordinator', 'approved')"
        ))
        connection.execute(text(
            "INSERT INTO media_ratings (media_id, user_id, enrollment_id, rating) "
            "VALUES ('media-1', 'user-1', 'enrollment-1', 5)"
        ))
        connection.execute(text(
            "INSERT INTO media_playback_grants (id, token_digest, media_id, user_id, expires_at) "
            "VALUES ('grant-1', :digest, 'media-1', 'user-1', '2026-09-20 12:05:00')"
        ), {"digest": "f" * 64})
        assert connection.execute(text("SELECT COUNT(*) FROM media_status_transitions")).scalar_one() == 2
        assert connection.execute(text("SELECT COUNT(*) FROM media_ratings")).scalar_one() == 1
        assert connection.execute(text("SELECT COUNT(*) FROM media_playback_grants")).scalar_one() == 1
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "UPDATE assessment_contents SET title = 'Mutado' WHERE id = 'content-1'"
        ))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "UPDATE media_status_transitions SET reason = 'rewritten' "
            "WHERE id = 'transition-1'"
        ))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "DELETE FROM media_status_transitions WHERE id = 'transition-1'"
        ))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "INSERT INTO media_ratings (media_id, user_id, enrollment_id, rating) "
            "VALUES ('media-1', 'user-1', 'enrollment-1', 6)"
        ))
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "INSERT INTO revenue_ledger (id, creator_score_id, institution_id, program_id, creator_user_id, media_id, source_event_id, rule_version, entry_type, amount_minor, currency, status, idempotency_key, calculation_snapshot) "
            "VALUES ('ledger-null-source', 'score-1', 'legacy-institution', :program_id, 'user-1', 'media-1', NULL, 'creator-score-v1', 'accrual', 100, 'BRL', 'simulated', 'ledger:key:null-source', '{}')"
        ), {"program_id": enrollment.program_id})
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "INSERT INTO revenue_ledger (id, creator_score_id, institution_id, program_id, creator_user_id, media_id, source_event_id, rule_version, entry_type, amount_minor, currency, status, idempotency_key, calculation_snapshot) "
            "VALUES ('ledger-null-score', NULL, 'legacy-institution', :program_id, 'user-1', 'media-1', 'media-event-1', 'creator-score-v1', 'adjustment', 100, 'BRL', 'simulated', 'ledger:key:null-score', '{}')"
        ), {"program_id": enrollment.program_id})
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text(
            "INSERT INTO assessment_attempts (attempt_id, owner_id, course_id, topic, mode, revision, answers, marked, current_index, remaining_seconds, completed, score, updated_at) "
            "VALUES ('attempt-invalid-score', 'user-1', 'course-1', 'Tópico', 'quiz', 1, '{}', '[]', 0, 0, 0, 1, '2026-09-20 12:00:00')"
        ))
    engine.dispose()
