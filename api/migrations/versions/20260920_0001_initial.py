"""initial Tutor TDS foundation

Revision ID: 20260920_0001
Revises:
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "courses",
        sa.Column("id", sa.String(120), primary_key=True),
        sa.Column("title", sa.String(240), nullable=False),
        sa.Column("author", sa.String(240), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "institutions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(240), nullable=False),
    )
    op.create_table(
        "programs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("institution_id", sa.String(36), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("name", sa.String(240), nullable=False),
    )
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("cpf_digest", sa.String(64), nullable=False, unique=True),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("name", sa.String(240), nullable=False),
        sa.Column("role", sa.String(32), nullable=False, server_default="student"),
    )
    op.create_table(
        "sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("refresh_token_digest", sa.String(64), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_table(
        "enrollments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="active"),
        sa.Column(
            "enrolled_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_table(
        "certificates",
        sa.Column("id", sa.String(120), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("verification_url", sa.String(500), nullable=False),
        sa.Column("content_hash", sa.String(128), nullable=False),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "learning_events",
        sa.Column("event_id", sa.String(180), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("session_id", sa.String(160), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("sync_status", sa.String(24), nullable=False, server_default="pending"),
    )
    op.create_table(
        "sync_log",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(180), sa.ForeignKey("learning_events.event_id"), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("detail", sa.Text()),
        sa.Column("attempted_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("sync_log")
    op.drop_table("learning_events")
    op.drop_table("certificates")
    op.drop_table("enrollments")
    op.drop_table("sessions")
    op.drop_table("users")
    op.drop_table("programs")
    op.drop_table("institutions")
    op.drop_table("courses")
