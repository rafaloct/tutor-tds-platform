"""Durable mapping from validated external identity to Tutor User."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0025"
down_revision = "20261003_0024"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "external_identities",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("provider_subject", sa.String(255), nullable=False),
        sa.Column("verified_email", sa.String(320)),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "provider",
            "provider_subject",
            name="uq_external_identity_provider_subject",
        ),
    )
    op.create_index(
        "ix_external_identity_user",
        "external_identities",
        ["user_id"],
        unique=False,
    )


def downgrade():
    count = op.get_bind().execute(
        sa.text("SELECT count(*) FROM external_identities")
    ).scalar()
    if count:
        raise RuntimeError(
            "Preserve external identity links: forward recover."
        )
    op.drop_index(
        "ix_external_identity_user",
        table_name="external_identities",
    )
    op.drop_table("external_identities")
