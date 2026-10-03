"""Add opt-in offering policy and candidate lifecycle without legacy backfill."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0022"
down_revision = "20261003_0021"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("classes", sa.Column("certificate_policy", sa.JSON()))
    op.add_column("certificates", sa.Column("lifecycle_state", sa.String(48)))


def downgrade():
    bind = op.get_bind()
    if bind.execute(sa.text("SELECT COUNT(*) FROM classes WHERE certificate_policy IS NOT NULL")).scalar() or bind.execute(sa.text("SELECT COUNT(*) FROM certificates WHERE lifecycle_state IS NOT NULL")).scalar():
        raise RuntimeError("Preserve configured policy and lifecycle evidence before downgrade.")
    op.drop_column("certificates", "lifecycle_state")
    op.drop_column("classes", "certificate_policy")
