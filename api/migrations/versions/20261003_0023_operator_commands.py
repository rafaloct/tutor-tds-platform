"""Add isolated operator command receipts after certificate policy."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0023"
down_revision = "20261003_0022"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "operator_command_receipts",
        sa.Column("id", sa.String(180), primary_key=True),
        sa.Column("actor_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("subject_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("program_id", sa.String(36), sa.ForeignKey("programs.id"), nullable=False),
        sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(24), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("program_id", "subject_id", "revision", name="uq_operator_subject_revision"),
    )


def downgrade():
    if op.get_bind().execute(sa.text("SELECT count(*) FROM operator_command_receipts")).scalar():
        raise RuntimeError("Preserve operator history: disable feature and forward recover.")
    op.drop_table("operator_command_receipts")
