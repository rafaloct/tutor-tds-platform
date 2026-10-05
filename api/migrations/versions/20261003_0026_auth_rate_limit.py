"""Add shared authentication rate-limit buckets."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0026"
down_revision = "20261003_0025"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "auth_rate_limit_buckets",
        sa.Column("key", sa.String(64), primary_key=True),
        sa.Column("window_started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade():
    op.drop_table("auth_rate_limit_buckets")
