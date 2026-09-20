"""add authentication credentials

Revision ID: 20260920_0002
Revises: 20260920_0001
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0002"
down_revision = "20260920_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column("password_digest", sa.String(255), nullable=True)
        )
    op.execute(
        "UPDATE users SET password_digest = 'migration-required' "
        "WHERE password_digest IS NULL"
    )
    with op.batch_alter_table("users") as batch_op:
        batch_op.alter_column("password_digest", nullable=False)


def downgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("password_digest")
