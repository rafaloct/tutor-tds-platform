"""Add the short numeric check-in code digest to class sessions."""

from alembic import op
import sqlalchemy as sa

revision = "20261006_0029"
down_revision = "20261005_0028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("class_sessions") as batch:
        batch.add_column(
            sa.Column("checkin_code_digest", sa.String(64), nullable=True)
        )
        batch.create_index(
            "ix_class_sessions_checkin_code", ["checkin_code_digest"]
        )


def downgrade() -> None:
    with op.batch_alter_table("class_sessions") as batch:
        batch.drop_index("ix_class_sessions_checkin_code")
        batch.drop_column("checkin_code_digest")
