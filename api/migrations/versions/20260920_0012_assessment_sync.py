"""add versioned assessment attempt sync

Revision ID: 20260920_0012
Revises: 20260920_0011
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0012"
down_revision = "20260920_0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "assessment_attempts",
        sa.Column("attempt_id", sa.String(180), primary_key=True),
        sa.Column(
            "owner_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("topic", sa.String(240), nullable=False),
        sa.Column("mode", sa.String(16), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("answers", sa.JSON(), nullable=False),
        sa.Column("marked", sa.JSON(), nullable=False),
        sa.Column("current_index", sa.Integer(), nullable=False),
        sa.Column("remaining_seconds", sa.Integer(), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("revision >= 1", name="ck_assessment_attempt_revision"),
        sa.CheckConstraint("current_index >= 0", name="ck_assessment_attempt_current_index"),
        sa.CheckConstraint("remaining_seconds >= 0", name="ck_assessment_attempt_remaining"),
        sa.CheckConstraint("score >= 0", name="ck_assessment_attempt_score"),
        sa.CheckConstraint("mode IN ('quiz', 'exam')", name="ck_assessment_attempt_mode"),
        sa.CheckConstraint(
            "completed OR score = 0",
            name="ck_assessment_attempt_incomplete_score",
        ),
        sa.CheckConstraint(
            "NOT completed OR remaining_seconds = 0",
            name="ck_assessment_attempt_completed_remaining",
        ),
    )
    op.create_index(
        "ix_assessment_attempts_owner_updated",
        "assessment_attempts",
        ["owner_id", "updated_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_assessment_attempts_owner_updated", table_name="assessment_attempts")
    op.drop_table("assessment_attempts")
