"""add reliable sync worker state

Revision ID: 20260920_0006
Revises: 20260920_0005
"""

from alembic import op
import sqlalchemy as sa


revision = "20260920_0006"
down_revision = "20260920_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("learning_events") as batch_op:
        batch_op.add_column(
            sa.Column(
                "sync_attempts", sa.Integer(), nullable=False, server_default="0"
            )
        )
        batch_op.add_column(
            sa.Column("sync_next_attempt_at", sa.DateTime(timezone=True))
        )
        batch_op.add_column(sa.Column("sync_claimed_at", sa.DateTime(timezone=True)))
        batch_op.create_index(
            "ix_learning_events_sync_queue",
            ["sync_status", "sync_next_attempt_at", "occurred_at"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("learning_events") as batch_op:
        batch_op.drop_index("ix_learning_events_sync_queue")
        batch_op.drop_column("sync_claimed_at")
        batch_op.drop_column("sync_next_attempt_at")
        batch_op.drop_column("sync_attempts")
