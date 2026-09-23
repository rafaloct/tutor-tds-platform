from __future__ import annotations

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import password_hash
from app.config import Settings
from app.database import Database
from app.models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    Base,
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    CohortMembership,
    ClassSession,
    Course,
    CourseVersion,
    CourseVersionTransition,
    Enrollment,
    EvidenceImport,
    EvidenceItem,
    Institution,
    LearningEventRecord,
    MediaAsset,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)
from app.staging_seed import (
    CERTIFICATE_PLANNED_SECONDS,
    CONFIRMATION,
    IDS,
    SeedAccount,
    SeedCredentials,
    seed_staging_data,
    validate_staging_target,
)


def _credentials() -> SeedCredentials:
    return SeedCredentials(
        admin=SeedAccount("123.456.789-09", "550000000001", "senha-admin-sintetica-2026"),
        teacher=SeedAccount("987.654.321-00", "550000000002", "senha-professor-sintetica-2026"),
        monitor=SeedAccount("529.982.247-25", "550000000003", "senha-monitor-sintetica-2026"),
        student=SeedAccount("168.995.350-09", "550000000004", "senha-aluno-sintetica-2026"),
        checkin_token="token-sintetico-checkin-2026",
    )


def test_staging_target_guard_fails_closed() -> None:
    valid_url = "postgresql+psycopg://user:secret@db-staging:5432/tutor_tds_staging"
    validate_staging_target(
        environment="staging",
        database_url=valid_url,
        confirmation=CONFIRMATION,
    )

    rejected = [
        {"environment": "production", "database_url": valid_url, "confirmation": CONFIRMATION},
        {"environment": "staging", "database_url": valid_url, "confirmation": "yes"},
        {"environment": "staging", "database_url": "postgresql+psycopg://user:secret@db:5432/tutor_tds_staging", "confirmation": CONFIRMATION},
        {"environment": "staging", "database_url": "postgresql+psycopg://user:secret@db-staging:5432/tutor_tds", "confirmation": CONFIRMATION},
        {"environment": "staging", "database_url": "sqlite+pysqlite:///staging.db", "confirmation": CONFIRMATION},
    ]
    for case in rejected:
        with pytest.raises(RuntimeError):
            validate_staging_target(**case)
    with pytest.raises(RuntimeError, match="STAGING_SEED_ADMIN_CPF"):
        SeedCredentials.from_environment({})


def test_staging_seed_is_synthetic_complete_and_idempotent() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="j" * 32,
        cpf_pepper="p" * 32,
    )
    database = Database(settings.database_url)
    Base.metadata.create_all(database.engine)
    credentials = _credentials()

    first = seed_staging_data(database.engine, settings, credentials)
    second = seed_staging_data(database.engine, settings, credentials)

    with Session(database.engine) as session:
        expected_counts = {
            User: 4,
            Institution: 1,
            Program: 1,
            Course: 1,
            ProgramCourse: 1,
            ProgramMembership: 4,
            Enrollment: 1,
            Classroom: 1,
            CohortMembership: 3,
            CourseVersion: 1,
            CourseVersionTransition: 1,
            ClassEnrollment: 1,
            ClassMonitor: 1,
            ClassSession: 1,
            EvidenceImport: 1,
            EvidenceItem: 1,
            AssessmentAttemptRecord: 1,
            AssessmentContentRecord: 1,
            MediaAsset: 1,
            LearningEventRecord: 2,
        }
        for model, expected in expected_counts.items():
            assert session.scalar(select(func.count()).select_from(model)) == expected

        teacher = session.get(User, IDS["teacher"])
        teacher_membership = session.get(
            ProgramMembership,
            (IDS["teacher"], IDS["program"]),
        )
        course = session.get(Course, IDS["course"])
        media = session.get(MediaAsset, IDS["media"])
        class_session = session.get(ClassSession, IDS["session"])
        attempt = session.get(AssessmentAttemptRecord, IDS["assessment"])
        certificate_hours = session.scalar(
            select(func.sum(LearningEventRecord.validated_seconds)).where(
                LearningEventRecord.enrollment_id == IDS["enrollment"],
                LearningEventRecord.event_type == "study_activity",
            )
        )

        assert teacher is not None and teacher.role == "student"
        assert password_hash.verify(credentials.teacher.password, teacher.password_digest)
        assert teacher_membership is not None and teacher_membership.role == "teacher"
        assert course is not None and course.title.endswith("[STAGING]")
        assert course.content["sections"][0]["messages"]
        assert media is not None and media.status == "published"
        assert media.visibility == "institution"
        assert media.provider_asset_id.endswith(".m3u8")
        assert class_session is not None and class_session.status == "open"
        assert class_session.token_version == 1
        assert attempt is not None and attempt.owner_id == IDS["student"]
        assert attempt.completed is False
        assert certificate_hours == CERTIFICATE_PLANNED_SECONDS

    database.dispose()
    assert first.total_created == 29
    assert second.total_created == 0
