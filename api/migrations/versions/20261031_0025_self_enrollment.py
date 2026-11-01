"""Open-class self-enrollment policy and external sync outbox.

Additive only: classes gain enrollment_policy ('managed' default preserves the
current staff-only behavior), a partial unique index keeps at most one open
non-closed class per course, and external_sync_requests queues outbound
projections (e.g. LearnPress enrollment) with claim/retry semantics.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261031_0025"
down_revision = "20261003_0024"
branch_labels = None
depends_on = None

_OPEN_FILTER = "enrollment_policy = 'open' AND status != 'closed'"


def upgrade():
    op.create_table(
        "external_sync_requests",
        sa.Column("id", sa.String(180), primary_key=True),
        sa.Column("kind", sa.String(64), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="pending"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True)),
        sa.Column("claimed_at", sa.DateTime(timezone=True)),
        sa.Column("last_error", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("kind", "user_id", "course_id", name="uq_external_sync_subject"),
        sa.CheckConstraint("status IN ('pending','processing','done','failed')", name="ck_external_sync_status"),
        sa.CheckConstraint("attempts >= 0", name="ck_external_sync_attempts"),
    )
    op.create_index(
        "ix_external_sync_claim",
        "external_sync_requests",
        ["status", "next_attempt_at"],
    )
    with op.batch_alter_table("classes") as batch:
        batch.add_column(
            sa.Column(
                "enrollment_policy",
                sa.String(24),
                nullable=False,
                server_default="managed",
            )
        )
        batch.create_check_constraint(
            "ck_classes_enrollment_policy",
            "enrollment_policy IN ('managed','open')",
        )
    op.create_index(
        "uq_classes_open_course",
        "classes",
        ["course_id"],
        unique=True,
        sqlite_where=sa.text(_OPEN_FILTER),
        postgresql_where=sa.text(_OPEN_FILTER),
    )


def downgrade():
    if op.get_bind().execute(
        sa.text("SELECT count(*) FROM classes WHERE enrollment_policy = 'open'")
    ).scalar():
        raise RuntimeError("Preserve open classes: disable feature and forward recover.")
    if op.get_bind().execute(
        sa.text("SELECT count(*) FROM external_sync_requests")
    ).scalar():
        raise RuntimeError("Preserve sync history: disable feature and forward recover.")
    op.drop_index("uq_classes_open_course", table_name="classes")
    with op.batch_alter_table("classes") as batch:
        batch.drop_constraint("ck_classes_enrollment_policy", type_="check")
        batch.drop_column("enrollment_policy")
    op.drop_index("ix_external_sync_claim", table_name="external_sync_requests")
    op.drop_table("external_sync_requests")
