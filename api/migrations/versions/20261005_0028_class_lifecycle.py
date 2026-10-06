"""Add territorial classroom lifecycle state and audit receipts."""

from alembic import op
import sqlalchemy as sa

revision = "20261005_0028"
down_revision = "20261005_0027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    connection = op.get_bind()
    invalid = connection.execute(
        sa.text(
            "SELECT count(*) FROM classes "
            "WHERE status NOT IN ('planned', 'active', 'closed')"
        )
    ).scalar()
    if invalid:
        raise RuntimeError(
            "Normalize classroom status before enabling territorial lifecycle."
        )

    with op.batch_alter_table("classes") as batch:
        batch.add_column(sa.Column("offer_municipality", sa.String(240)))
        batch.add_column(sa.Column("offer_location", sa.String(500)))
        batch.add_column(
            sa.Column(
                "lifecycle_revision",
                sa.Integer(),
                nullable=False,
                server_default="0",
            )
        )
        batch.create_check_constraint(
            "ck_classes_status",
            "status IN ('planned', 'active', 'closed')",
        )
        batch.create_check_constraint(
            "ck_classes_lifecycle_revision",
            "lifecycle_revision >= 0",
        )

    op.create_table(
        "classroom_command_receipts",
        sa.Column("id", sa.String(180), primary_key=True),
        sa.Column(
            "actor_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "program_id",
            sa.String(36),
            sa.ForeignKey("programs.id"),
            nullable=False,
        ),
        sa.Column(
            "class_id",
            sa.String(36),
            sa.ForeignKey("classes.id"),
            nullable=False,
        ),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "class_id",
            "revision",
            name="uq_classroom_command_revision",
        ),
        sa.CheckConstraint(
            "revision >= 1",
            name="ck_classroom_command_revision",
        ),
    )
    op.create_index(
        "ix_classroom_command_receipts_class_time",
        "classroom_command_receipts",
        ["class_id", "occurred_at"],
    )


def downgrade() -> None:
    connection = op.get_bind()
    receipts = connection.execute(
        sa.text("SELECT count(*) FROM classroom_command_receipts")
    ).scalar()
    lifecycle_data = connection.execute(
        sa.text(
            "SELECT count(*) FROM classes "
            "WHERE offer_municipality IS NOT NULL "
            "OR offer_location IS NOT NULL "
            "OR lifecycle_revision != 0"
        )
    ).scalar()
    if receipts or lifecycle_data:
        raise RuntimeError(
            "Preserve classroom lifecycle history: disable the feature and forward recover."
        )

    op.drop_index(
        "ix_classroom_command_receipts_class_time",
        table_name="classroom_command_receipts",
    )
    op.drop_table("classroom_command_receipts")
    with op.batch_alter_table("classes") as batch:
        batch.drop_constraint(
            "ck_classes_lifecycle_revision",
            type_="check",
        )
        batch.drop_constraint("ck_classes_status", type_="check")
        batch.drop_column("lifecycle_revision")
        batch.drop_column("offer_location")
        batch.drop_column("offer_municipality")
