"""Add the short numeric check-in code digest to class sessions."""

from alembic import op
import sqlalchemy as sa

revision = "20261006_0029"
down_revision = "20261005_0028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Plain ADD COLUMN: rebuilding class_sessions would orphan the SQLite
    # triggers session_presence_insert/session_presence_snapshot that
    # reference it.
    op.add_column(
        "class_sessions",
        sa.Column("checkin_code_digest", sa.String(64), nullable=True),
    )
    op.create_index(
        "ix_class_sessions_checkin_code",
        "class_sessions",
        ["checkin_code_digest"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_class_sessions_checkin_code", table_name="class_sessions"
    )
    op.drop_column("class_sessions", "checkin_code_digest")
