from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
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


class CertificateReference(Base):
    __tablename__ = "certificates"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id"), nullable=False)
    verification_url: Mapped[str] = mapped_column(String(500), nullable=False)
    content_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class LearningEventRecord(Base):
    __tablename__ = "learning_events"

    event_id: Mapped[str] = mapped_column(String(180), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    course_id: Mapped[str] = mapped_column(String(120), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    session_id: Mapped[str] = mapped_column(String(160), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    sync_status: Mapped[str] = mapped_column(
        String(24), nullable=False, default="pending"
    )


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
