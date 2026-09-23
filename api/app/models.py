from __future__ import annotations

from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    author: Mapped[str] = mapped_column(String(240), nullable=False)
    content: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    program_links: Mapped[list["ProgramCourse"]] = relationship(
        back_populates="course"
    )
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="course")


class Institution(Base):
    __tablename__ = "institutions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    programs: Mapped[list["Program"]] = relationship(back_populates="institution")


class CourseVersion(Base):
    __tablename__ = "course_versions"
    __table_args__ = (
        Index("ix_course_versions_program_status", "program_id", "status"),
        UniqueConstraint("course_id", "version_number", name="uq_course_version_number"),
        UniqueConstraint("id", "course_id", name="uq_course_version_lineage"),
        CheckConstraint("revision >= 1 AND version_number >= 1", name="ck_course_version_revision"),
        CheckConstraint("status IN ('draft', 'in_review', 'published', 'archived')", name="ck_course_version_status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    program_id: Mapped[str | None] = mapped_column(ForeignKey("programs.id"))
    creator_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    source_version_id: Mapped[str | None] = mapped_column(ForeignKey("course_versions.id"))
    version_number: Mapped[int] = mapped_column(Integer, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    content: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class CourseVersionTransition(Base):
    __tablename__ = "course_version_transitions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    version_id: Mapped[str] = mapped_column(ForeignKey("course_versions.id"), nullable=False)
    from_status: Mapped[str | None] = mapped_column(String(24))
    to_status: Mapped[str] = mapped_column(String(24), nullable=False)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Program(Base):
    __tablename__ = "programs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    institution_id: Mapped[str] = mapped_column(
        ForeignKey("institutions.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    institution: Mapped[Institution] = relationship(back_populates="programs")
    course_links: Mapped[list["ProgramCourse"]] = relationship(
        back_populates="program"
    )
    memberships: Mapped[list["ProgramMembership"]] = relationship(
        back_populates="program"
    )
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="program")


class ProgramCourse(Base):
    __tablename__ = "program_courses"

    program_id: Mapped[str] = mapped_column(
        ForeignKey("programs.id"), primary_key=True
    )
    course_id: Mapped[str] = mapped_column(
        ForeignKey("courses.id"), primary_key=True
    )
    planned_seconds: Mapped[int] = mapped_column(
        Integer, nullable=False, default=40 * 60 * 60
    )
    program: Mapped[Program] = relationship(back_populates="course_links")
    course: Mapped[Course] = relationship(back_populates="program_links")


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    cpf_digest: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    password_digest: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(32), nullable=False, default="student")
    program_memberships: Mapped[list["ProgramMembership"]] = relationship(
        back_populates="user"
    )
    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="user")


class ProgramMembership(Base):
    __tablename__ = "program_memberships"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    program_id: Mapped[str] = mapped_column(
        ForeignKey("programs.id"), primary_key=True
    )
    role: Mapped[str] = mapped_column(String(32), nullable=False, default="student")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="active")
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    user: Mapped[User] = relationship(back_populates="program_memberships")
    program: Mapped[Program] = relationship(back_populates="memberships")


class SessionToken(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    refresh_token_digest: Mapped[str] = mapped_column(
        String(64), unique=True, nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class AssessmentContentRecord(Base):
    __tablename__ = "assessment_contents"
    __table_args__ = (
        CheckConstraint(
            "mode IN ('quiz', 'exam')", name="ck_assessment_content_mode"
        ),
        CheckConstraint(
            "duration_seconds BETWEEN 0 AND 86400",
            name="ck_assessment_content_duration",
        ),
    )

    id: Mapped[str] = mapped_column(String(180), primary_key=True)
    owner_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[str] = mapped_column(
        ForeignKey("courses.id"), nullable=False
    )
    topic: Mapped[str] = mapped_column(String(240), nullable=False)
    mode: Mapped[str] = mapped_column(String(16), nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    questions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    answer_key: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    content_digest: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class AssessmentAttemptRecord(Base):
    __tablename__ = "assessment_attempts"
    __table_args__ = (
        CheckConstraint("revision >= 1", name="ck_assessment_attempt_revision"),
        CheckConstraint("current_index >= 0", name="ck_assessment_attempt_current_index"),
        CheckConstraint("remaining_seconds >= 0", name="ck_assessment_attempt_remaining"),
        CheckConstraint("score >= 0", name="ck_assessment_attempt_score"),
        CheckConstraint("mode IN ('quiz', 'exam')", name="ck_assessment_attempt_mode"),
        CheckConstraint(
            "completed OR score = 0",
            name="ck_assessment_attempt_incomplete_score",
        ),
        CheckConstraint(
            "NOT completed OR remaining_seconds = 0",
            name="ck_assessment_attempt_completed_remaining",
        ),
    )

    attempt_id: Mapped[str] = mapped_column(String(180), primary_key=True)
    owner_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[str] = mapped_column(
        ForeignKey("courses.id"), nullable=False
    )
    assessment_content_id: Mapped[str | None] = mapped_column(
        ForeignKey("assessment_contents.id")
    )
    topic: Mapped[str] = mapped_column(String(240), nullable=False)
    mode: Mapped[str] = mapped_column(String(16), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    answers: Mapped[dict[str, int]] = mapped_column(JSON, nullable=False, default=dict)
    marked: Mapped[list[int]] = mapped_column(JSON, nullable=False, default=list)
    current_index: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    remaining_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (
        ForeignKeyConstraint(
            ["program_id", "course_id"],
            ["program_courses.program_id", "program_courses.course_id"],
            name="fk_enrollments_program_course",
        ),
        ForeignKeyConstraint(
            ["user_id", "program_id"],
            ["program_memberships.user_id", "program_memberships.program_id"],
            name="fk_enrollments_program_membership",
        ),
        UniqueConstraint(
            "user_id",
            "program_id",
            "course_id",
            name="uq_enrollments_user_program_course",
        ),
        UniqueConstraint(
            "id",
            "user_id",
            "program_id",
            "course_id",
            name="uq_enrollments_lineage",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    program_id: Mapped[str] = mapped_column(
        ForeignKey("programs.id"), nullable=False
    )
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    status: Mapped[str] = mapped_column(
        String(24), nullable=False, default="active"
    )
    enrolled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    user: Mapped[User] = relationship(back_populates="enrollments")
    program: Mapped[Program] = relationship(back_populates="enrollments")
    course: Mapped[Course] = relationship(back_populates="enrollments")


class Classroom(Base):
    __tablename__ = "classes"
    __table_args__ = (
        ForeignKeyConstraint(
            ["course_version_id", "course_id"],
            ["course_versions.id", "course_versions.course_id"],
            name="fk_classes_course_version",
        ),
        ForeignKeyConstraint(
            ["program_id", "course_id"],
            ["program_courses.program_id", "program_courses.course_id"],
            name="fk_classes_program_course",
        ),
        ForeignKeyConstraint(
            ["teacher_id", "program_id"],
            ["program_memberships.user_id", "program_memberships.program_id"],
            name="fk_classes_teacher_membership",
        ),
        CheckConstraint("end_date >= start_date", name="ck_classes_date_range"),
        UniqueConstraint(
            "id", "program_id", name="uq_classes_program_lineage"
        ),
        UniqueConstraint(
            "id",
            "program_id",
            "course_id",
            name="uq_classes_course_lineage",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    course_version_id: Mapped[str | None] = mapped_column(String(36))
    program_id: Mapped[str] = mapped_column(
        ForeignKey("programs.id"), nullable=False
    )
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    teacher_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="planned")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class CohortMembership(Base):
    __tablename__ = "cohort_memberships"
    __table_args__ = (
        UniqueConstraint("class_id", "user_id", "role", name="uq_cohort_membership_natural"),
        UniqueConstraint("id", "class_id", "user_id", "role", name="uq_cohort_membership_lineage"),
        CheckConstraint("role IN ('student', 'teacher', 'monitor')", name="ck_cohort_membership_role"),
        CheckConstraint("status IN ('active', 'inactive')", name="ck_cohort_membership_status"),
        Index("ix_cohort_membership_user_status", "user_id", "status"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(24), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class ClassEnrollment(Base):
    __tablename__ = "class_enrollments"
    __table_args__ = (
        UniqueConstraint("context_id", name="uq_class_enrollment_context_id"),
        UniqueConstraint("membership_id", "course_version_id", name="uq_class_enrollment_membership_version"),
        ForeignKeyConstraint(["membership_id", "class_id", "user_id", "membership_role"],
            ["cohort_memberships.id", "cohort_memberships.class_id", "cohort_memberships.user_id", "cohort_memberships.role"],
            name="fk_class_enrollment_membership"),
        ForeignKeyConstraint(["course_version_id", "course_id"], ["course_versions.id", "course_versions.course_id"],
            name="fk_class_enrollment_version"),
        CheckConstraint("membership_role = 'student'", name="ck_class_enrollment_student"),
        CheckConstraint("(context_id IS NULL AND membership_id IS NULL AND course_version_id IS NULL) OR "
                        "(context_id IS NOT NULL AND membership_id IS NOT NULL AND course_version_id IS NOT NULL)",
                        name="ck_class_enrollment_context_complete"),
        ForeignKeyConstraint(
            ["class_id", "program_id", "course_id"],
            ["classes.id", "classes.program_id", "classes.course_id"],
            name="fk_class_enrollments_class_lineage",
        ),
        ForeignKeyConstraint(
            ["enrollment_id", "user_id", "program_id", "course_id"],
            [
                "enrollments.id",
                "enrollments.user_id",
                "enrollments.program_id",
                "enrollments.course_id",
            ],
            name="fk_class_enrollments_enrollment_lineage",
        ),
    )

    class_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    context_id: Mapped[str | None] = mapped_column(String(36))
    membership_id: Mapped[str | None] = mapped_column(String(36))
    membership_role: Mapped[str] = mapped_column(String(24), nullable=False, server_default="student")
    course_version_id: Mapped[str | None] = mapped_column(String(36))
    enrollment_id: Mapped[str] = mapped_column(String(36), nullable=False)
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="active")
    enrolled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class ClassMonitor(Base):
    __tablename__ = "class_monitors"
    __table_args__ = (
        ForeignKeyConstraint(
            ["class_id", "program_id"],
            ["classes.id", "classes.program_id"],
            name="fk_class_monitors_class_program",
        ),
        ForeignKeyConstraint(
            ["user_id", "program_id"],
            ["program_memberships.user_id", "program_memberships.program_id"],
            name="fk_class_monitors_program_membership",
        ),
    )

    class_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class CertificateReference(Base):
    __tablename__ = "certificates"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    program_id: Mapped[str | None] = mapped_column(ForeignKey("programs.id"))
    class_id: Mapped[str | None] = mapped_column(ForeignKey("classes.id"))
    holder_name: Mapped[str | None] = mapped_column(String(240))
    course_title: Mapped[str | None] = mapped_column(String(240))
    institution_name: Mapped[str | None] = mapped_column(String(240))
    planned_seconds: Mapped[int | None] = mapped_column(Integer)
    verification_url: Mapped[str] = mapped_column(String(500), nullable=False)
    content_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class CertificateRequest(Base):
    __tablename__ = "certificate_requests"
    __table_args__ = (
        UniqueConstraint("enrollment_id", "course_version_id", name="uq_certificate_request_edition"),
        ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_certificate_request_enrollment", ondelete="CASCADE"),
        ForeignKeyConstraint(["course_version_id", "course_id"], ["course_versions.id", "course_versions.course_id"], name="fk_certificate_request_version"),
        ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_certificate_request_class"),
        CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="ck_certificate_request_status"),
        CheckConstraint("revision >= 1 AND required_seconds >= 0", name="ck_certificate_request_numbers"),
        CheckConstraint("(status = 'pending' AND reviewed_at IS NULL AND review_reason IS NULL) OR (status != 'pending' AND reviewed_at IS NOT NULL AND review_reason IS NOT NULL)", name="ck_certificate_request_review"),
        Index("ix_certificate_requests_program_status", "program_id", "status"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    enrollment_id: Mapped[str] = mapped_column(String(36), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    course_version_id: Mapped[str] = mapped_column(String(36), nullable=False)
    class_id: Mapped[str | None] = mapped_column(String(36))
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    institution_id: Mapped[str] = mapped_column(ForeignKey("institutions.id"), nullable=False)
    holder_name: Mapped[str] = mapped_column(String(240), nullable=False)
    course_title: Mapped[str] = mapped_column(String(240), nullable=False)
    program_name: Mapped[str] = mapped_column(String(240), nullable=False)
    institution_name: Mapped[str] = mapped_column(String(240), nullable=False)
    required_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending")
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_reason: Mapped[str | None] = mapped_column(String(500))


class CertificateRequestTransition(Base):
    __tablename__ = "certificate_request_transitions"
    __table_args__ = (
        UniqueConstraint("request_id", "revision", name="uq_certificate_request_transition_revision"),
        CheckConstraint("revision >= 1", name="ck_certificate_request_transition_revision"),
        CheckConstraint("to_status IN ('pending', 'approved', 'rejected') AND (from_status IS NULL OR from_status IN ('pending', 'rejected'))", name="ck_certificate_request_transition_status"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    request_id: Mapped[str] = mapped_column(ForeignKey("certificate_requests.id", ondelete="CASCADE"), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    from_status: Mapped[str | None] = mapped_column(String(24))
    to_status: Mapped[str] = mapped_column(String(24), nullable=False)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    reason: Mapped[str | None] = mapped_column(String(500))
    eligibility: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())


class LearningEventRecord(Base):
    __tablename__ = "learning_events"

    event_id: Mapped[str] = mapped_column(String(180), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    enrollment_id: Mapped[str | None] = mapped_column(ForeignKey("enrollments.id"))
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    session_id: Mapped[str] = mapped_column(String(160), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    active_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    validated_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    sync_status: Mapped[str] = mapped_column(
        String(24), nullable=False, default="pending"
    )
    sync_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    sync_next_attempt_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True)
    )
    sync_claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SyncLog(Base):
    __tablename__ = "sync_log"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(
        ForeignKey("learning_events.event_id"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    detail: Mapped[str | None] = mapped_column(Text)
    attempted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class SyncDeletionRequest(Base):
    __tablename__ = "sync_deletion_requests"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending")
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_error: Mapped[str | None] = mapped_column(Text)


class MediaAsset(Base):
    __tablename__ = "media_assets"
    __table_args__ = (
        UniqueConstraint("provider", "provider_asset_id", name="uq_media_provider_asset"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    institution_id: Mapped[str] = mapped_column(ForeignKey("institutions.id"), nullable=False)
    program_id: Mapped[str] = mapped_column(ForeignKey("programs.id"), nullable=False)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    module_id: Mapped[str] = mapped_column(String(120), nullable=False)
    creator_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    competency_id: Mapped[str] = mapped_column(String(120), nullable=False)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    provider_asset_id: Mapped[str] = mapped_column(String(500), nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500))
    captions: Mapped[list[dict[str, str]]] = mapped_column(JSON, nullable=False, default=list)
    visibility: Mapped[str] = mapped_column(String(24), nullable=False, default="enrolled")
    offline_policy: Mapped[str] = mapped_column(String(24), nullable=False, default="forbidden")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="draft")
    master_drive_file_id: Mapped[str | None] = mapped_column(String(240))
    rights_confirmed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    followup_activity_id: Mapped[str] = mapped_column(String(120), nullable=False)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    published_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class MediaStatusTransition(Base):
    __tablename__ = "media_status_transitions"
    __table_args__ = (
        CheckConstraint(
            "from_status IS NULL OR from_status IN "
            "('draft', 'processing', 'published', 'blocked', 'archived')",
            name="ck_media_transition_from_status",
        ),
        CheckConstraint(
            "to_status IN ('draft', 'processing', 'published', 'blocked', 'archived')",
            name="ck_media_transition_to_status",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id"), nullable=False)
    from_status: Mapped[str | None] = mapped_column(String(24))
    to_status: Mapped[str] = mapped_column(String(24), nullable=False)
    actor_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    reason: Mapped[str | None] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class MediaRating(Base):
    __tablename__ = "media_ratings"
    __table_args__ = (
        CheckConstraint("rating BETWEEN 1 AND 5", name="ck_media_rating_range"),
    )

    media_id: Mapped[str] = mapped_column(
        ForeignKey("media_assets.id"), primary_key=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    enrollment_id: Mapped[str] = mapped_column(
        ForeignKey("enrollments.id"), nullable=False
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class MediaPlaybackGrant(Base):
    __tablename__ = "media_playback_grants"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    token_digest: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    media_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class MediaEventRecord(Base):
    __tablename__ = "media_events"

    event_id: Mapped[str] = mapped_column(String(180), primary_key=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    enrollment_id: Mapped[str] = mapped_column(ForeignKey("enrollments.id"), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    module_id: Mapped[str] = mapped_column(String(120), nullable=False)
    session_id: Mapped[str] = mapped_column(String(160), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    checkpoint_percent: Mapped[int | None] = mapped_column(Integer)
    position_seconds: Mapped[int | None] = mapped_column(Integer)
    qualified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class CreatorScore(Base):
    __tablename__ = "creator_scores"
    __table_args__ = (
        UniqueConstraint(
            "creator_user_id", "media_id", "rule_version", "window_start", "window_end",
            name="uq_creator_score_window",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    institution_id: Mapped[str] = mapped_column(ForeignKey("institutions.id"), nullable=False)
    program_id: Mapped[str] = mapped_column(ForeignKey("programs.id"), nullable=False)
    creator_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    media_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id"), nullable=False)
    rule_version: Mapped[str] = mapped_column(String(64), nullable=False)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    window_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    score_basis_points: Mapped[int] = mapped_column(Integer, nullable=False)
    calculation_snapshot: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class RevenueLedgerEntry(Base):
    __tablename__ = "revenue_ledger"
    __table_args__ = (
        UniqueConstraint("source_event_id", "rule_version", "entry_type", name="uq_ledger_semantic_origin"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    creator_score_id: Mapped[str] = mapped_column(
        ForeignKey("creator_scores.id"), nullable=False
    )
    institution_id: Mapped[str] = mapped_column(ForeignKey("institutions.id"), nullable=False)
    program_id: Mapped[str] = mapped_column(ForeignKey("programs.id"), nullable=False)
    creator_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    media_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id"), nullable=False)
    source_event_id: Mapped[str] = mapped_column(
        ForeignKey("media_events.event_id"), nullable=False
    )
    rule_version: Mapped[str] = mapped_column(String(64), nullable=False)
    entry_type: Mapped[str] = mapped_column(String(24), nullable=False)
    amount_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="simulated")
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    calculation_snapshot: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    approved_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    external_reference: Mapped[str | None] = mapped_column(String(240))


class ClassSession(Base):
    __tablename__ = "class_sessions"
    __table_args__ = (Index("uq_class_sessions_class_lineage", "id", "class_id", unique=True),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.id"), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="open")
    opened_by: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    closed_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    checkin_token_digest: Mapped[str] = mapped_column(String(64), nullable=False)
    token_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    token_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class EvidenceImport(Base):
    __tablename__ = "evidence_imports"
    __table_args__ = (UniqueConstraint("class_id", "source_digest", name="uq_evidence_import_digest"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.id"), nullable=False)
    source_type: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending_review")
    imported_by: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    retention_until: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source_digest: Mapped[str] = mapped_column(String(128), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class EvidenceItem(Base):
    __tablename__ = "evidence_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    import_id: Mapped[str | None] = mapped_column(ForeignKey("evidence_imports.id"))
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.id"), nullable=False)
    session_id: Mapped[str | None] = mapped_column(ForeignKey("class_sessions.id"))
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    evidence_type: Mapped[str] = mapped_column(String(48), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    confidence_basis_points: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    review_status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending")
    object_reference: Mapped[str | None] = mapped_column(String(500))
    item_digest: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)


class ClassCheckin(Base):
    __tablename__ = "class_checkins"
    __table_args__ = (UniqueConstraint("session_id", "user_id", "kind", name="uq_checkin_session_user_kind"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("class_sessions.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    method: Mapped[str] = mapped_column(String(16), nullable=False)
    evidence_id: Mapped[str] = mapped_column(ForeignKey("evidence_items.id"), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)


class ReviewDecision(Base):
    __tablename__ = "review_decisions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    evidence_id: Mapped[str] = mapped_column(ForeignKey("evidence_items.id"), nullable=False)
    decision: Mapped[str] = mapped_column(String(16), nullable=False)
    reason_code: Mapped[str] = mapped_column(String(48), nullable=False)
    decided_by: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class SessionReport(Base):
    __tablename__ = "session_reports"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(ForeignKey("classes.id"), nullable=False)
    session_id: Mapped[str] = mapped_column(ForeignKey("class_sessions.id"), unique=True, nullable=False)
    generated_by: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    report_digest: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    summary: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)


class SessionPresence(Base):
    __tablename__ = "session_presence"
    __table_args__ = (
        UniqueConstraint("session_id", "user_id", name="uq_session_presence_person"),
        ForeignKeyConstraint(["session_id", "class_id"], ["class_sessions.id", "class_sessions.class_id"], name="fk_presence_session"),
        ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_presence_class"),
        ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_presence_enrollment", ondelete="CASCADE"),
        CheckConstraint("status IN ('confirmed_present', 'justified_absence', 'absent')", name="ck_presence_status"),
        CheckConstraint("revision >= 1", name="ck_presence_revision"),
        CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_presence_reason"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    session_id: Mapped[str] = mapped_column(String(36), nullable=False)
    class_id: Mapped[str] = mapped_column(String(36), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    enrollment_id: Mapped[str] = mapped_column(String(36), nullable=False)
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    user_name: Mapped[str] = mapped_column(String(240), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class SessionPresenceDecision(Base):
    __tablename__ = "session_presence_decisions"
    __table_args__ = (
        UniqueConstraint("presence_id", "revision", name="uq_presence_decision_revision"),
        CheckConstraint("revision >= 1", name="ck_presence_decision_revision"),
        CheckConstraint("status IN ('confirmed_present', 'justified_absence', 'absent')", name="ck_presence_decision_status"),
        CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_presence_decision_reason"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    presence_id: Mapped[str] = mapped_column(ForeignKey("session_presence.id", ondelete="CASCADE"), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    decided_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    evidence_counts: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)


class BaselineSourceRecord(Base):
    """A human-reserved form reference, never the form's answers or identity guess."""
    __tablename__ = "baseline_source_records"
    __table_args__ = (
        UniqueConstraint("source", "record_id", name="uq_baseline_source_reference"),
        UniqueConstraint("id", "user_id", name="uq_baseline_source_owner"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source: Mapped[str] = mapped_column(String(120), nullable=False)
    record_id: Mapped[str] = mapped_column(String(240), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)


class StudentBaseline(Base):
    __tablename__ = "student_baselines"
    __table_args__ = (
        UniqueConstraint("class_id", "user_id", name="uq_student_baseline_class_person"),
        ForeignKeyConstraint(["source_record_id", "user_id"], ["baseline_source_records.id", "baseline_source_records.user_id"], name="fk_student_baseline_source_owner"),
        ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_student_baseline_class"),
        ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_student_baseline_enrollment", ondelete="CASCADE"),
        CheckConstraint("revision >= 1", name="ck_student_baseline_revision"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(String(36), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    enrollment_id: Mapped[str] = mapped_column(String(36), nullable=False)
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    source_record_id: Mapped[str] = mapped_column(String(36), nullable=False)
    baseline_date: Mapped[date] = mapped_column(Date, nullable=False)
    territory_id: Mapped[str | None] = mapped_column(String(120))
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class BaselineRevision(Base):
    __tablename__ = "baseline_revisions"
    __table_args__ = (
        UniqueConstraint("baseline_id", "revision", name="uq_baseline_revision"),
        CheckConstraint("revision >= 1", name="ck_baseline_revision"),
        CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_baseline_revision_reason"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    baseline_id: Mapped[str] = mapped_column(ForeignKey("student_baselines.id", ondelete="CASCADE"), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    snapshot: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)


class MentorshipCase(Base):
    __tablename__ = "mentorship_cases"
    __table_args__ = (
        ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_mentorship_class"),
        ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_mentorship_enrollment", ondelete="CASCADE"),
        CheckConstraint("revision >= 1", name="ck_mentorship_revision"),
        CheckConstraint("status IN ('open', 'in_progress', 'closed')", name="ck_mentorship_status"),
        CheckConstraint("(status = 'closed' AND closed_at IS NOT NULL) OR (status != 'closed' AND closed_at IS NULL)", name="ck_mentorship_closed_at"),
        CheckConstraint("length(trim(objective)) BETWEEN 3 AND 1000 AND length(trim(next_action)) BETWEEN 3 AND 1000", name="ck_mentorship_text"),
        Index("ix_mentorship_class_user", "class_id", "user_id"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    class_id: Mapped[str] = mapped_column(String(36), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    enrollment_id: Mapped[str] = mapped_column(String(36), nullable=False)
    program_id: Mapped[str] = mapped_column(String(36), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    mentor_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    objective: Mapped[str] = mapped_column(String(1000), nullable=False)
    next_action: Mapped[str] = mapped_column(String(1000), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MentorshipRevision(Base):
    __tablename__ = "mentorship_revisions"
    __table_args__ = (
        UniqueConstraint("case_id", "revision", name="uq_mentorship_revision"),
        CheckConstraint("revision >= 1", name="ck_mentorship_history_revision"),
        CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_mentorship_revision_reason"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    case_id: Mapped[str] = mapped_column(ForeignKey("mentorship_cases.id", ondelete="CASCADE"), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    mentor_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    actor_role: Mapped[str] = mapped_column(String(32), nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(180), unique=True, nullable=False)
    # Only explicitly supplied PATCH fields; actor/mentor IDs remain separate FKs.
    changed_fields: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    snapshot: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
