"""add auditable Sheets purge requests

Revision ID: 20260920_0011
Revises: 20260920_0009
"""
from alembic import op
import sqlalchemy as sa

revision = "20260920_0011"
down_revision = "20260920_0009"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table("sync_deletion_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(180), nullable=False, unique=True),
        sa.Column("status", sa.String(24), nullable=False, server_default="pending"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("requested_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)), sa.Column("last_error", sa.Text()))

def downgrade() -> None:
    op.drop_table("sync_deletion_requests")
