"""add immutable assessment content for cross-device hydration

Revision ID: 20260920_0014
Revises: 20260920_0013
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0014"
down_revision = "20260920_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "assessment_contents",
        sa.Column("id", sa.String(180), primary_key=True),
        sa.Column(
            "owner_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("topic", sa.String(240), nullable=False),
        sa.Column("mode", sa.String(16), nullable=False),
        sa.Column("title", sa.String(240), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("questions", sa.JSON(), nullable=False),
        sa.Column("answer_key", sa.JSON(), nullable=False),
        sa.Column("content_digest", sa.String(64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("mode IN ('quiz', 'exam')", name="ck_assessment_content_mode"),
        sa.CheckConstraint(
            "duration_seconds BETWEEN 0 AND 86400",
            name="ck_assessment_content_duration",
        ),
    )
    op.create_index(
        "ix_assessment_contents_owner_created",
        "assessment_contents",
        ["owner_id", "created_at"],
    )
    with op.batch_alter_table("assessment_attempts") as batch_op:
        batch_op.add_column(sa.Column("assessment_content_id", sa.String(180)))
        batch_op.create_foreign_key(
            "fk_assessment_attempt_content",
            "assessment_contents",
            ["assessment_content_id"],
            ["id"],
        )
        batch_op.create_index(
            "ix_assessment_attempts_content",
            ["assessment_content_id"],
        )
    _create_immutable_guard()


def downgrade() -> None:
    _drop_immutable_guard()
    with op.batch_alter_table("assessment_attempts") as batch_op:
        batch_op.drop_index("ix_assessment_attempts_content")
        batch_op.drop_constraint(
            "fk_assessment_attempt_content", type_="foreignkey"
        )
        batch_op.drop_column("assessment_content_id")
    op.drop_index(
        "ix_assessment_contents_owner_created",
        table_name="assessment_contents",
    )
    op.drop_table("assessment_contents")


def _create_immutable_guard() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            """
            CREATE FUNCTION reject_assessment_content_update()
            RETURNS trigger AS $$
            BEGIN
                RAISE EXCEPTION 'assessment content is immutable';
            END;
            $$ LANGUAGE plpgsql
            """
        )
        op.execute(
            """
            CREATE TRIGGER assessment_contents_immutable
            BEFORE UPDATE ON assessment_contents
            FOR EACH ROW EXECUTE FUNCTION reject_assessment_content_update()
            """
        )
    elif dialect == "sqlite":
        op.execute(
            """
            CREATE TRIGGER assessment_contents_immutable
            BEFORE UPDATE ON assessment_contents
            BEGIN
                SELECT RAISE(ABORT, 'assessment content is immutable');
            END
            """
        )


def _drop_immutable_guard() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            "DROP TRIGGER IF EXISTS assessment_contents_immutable "
            "ON assessment_contents"
        )
        op.execute("DROP FUNCTION IF EXISTS reject_assessment_content_update()")
    elif dialect == "sqlite":
        op.execute("DROP TRIGGER IF EXISTS assessment_contents_immutable")
