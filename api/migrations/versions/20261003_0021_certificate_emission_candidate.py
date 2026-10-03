"""Add transport reservation and optional reference lineage; preserve legacy data.

SQLite ALTER ADD REFERENCES is used without table recreation, preserving triggers.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0021"
down_revision = "20261001_0020"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("certificates", sa.Column("is_candidate", sa.Boolean(), nullable=False, server_default=sa.false()))
    if op.get_bind().dialect.name == "sqlite":
        op.execute("ALTER TABLE certificates ADD COLUMN request_id VARCHAR(36) REFERENCES certificate_requests(id) ON DELETE SET NULL")
    else:
        op.add_column("certificates", sa.Column("request_id", sa.String(36)))
        op.create_foreign_key("fk_certificate_reference_request", "certificates", "certificate_requests", ["request_id"], ["id"], ondelete="SET NULL")
    op.create_index("uq_certificate_reference_request", "certificates", ["request_id"], unique=True)
    op.create_table(
        "certificate_emission_attempts",
        sa.Column("request_id", sa.String(36), sa.ForeignKey("certificate_requests.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("certificate_id", sa.String(120), unique=True, nullable=False),
        sa.Column("command", sa.JSON(), nullable=False),
        sa.Column("state", sa.String(24), nullable=False),
        sa.Column("receipt", sa.JSON()),
        sa.CheckConstraint("state IN ('reserved', 'indeterminate', 'confirmed')", name="ck_certificate_emission_state"),
    )


def downgrade():
    # Do not silently discard emission/reconciliation history.
    if op.get_bind().execute(sa.text("SELECT COUNT(*) FROM certificate_emission_attempts")).scalar():
        raise RuntimeError("Reconcile and preserve candidate emission history before downgrade.")
    op.drop_table("certificate_emission_attempts")
    op.drop_index("uq_certificate_reference_request", table_name="certificates")
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint("fk_certificate_reference_request", "certificates", type_="foreignkey")
    op.drop_column("certificates", "request_id")
    op.drop_column("certificates", "is_candidate")
