"""Add one-time verified CPF activation tokens."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0025"
down_revision = "20261003_0024"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("activated_at", sa.DateTime(timezone=True), nullable=True))
    # Accounts that existed before verified activation became mandatory are the
    # approved legacy baseline. New registrations are only marked activated by
    # consuming a one-time invitation in AuthService.register.
    op.execute("UPDATE users SET activated_at = CURRENT_TIMESTAMP WHERE activated_at IS NULL")
    op.create_table(
        "cpf_activation_tokens",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("cpf_digest", sa.String(64), nullable=False),
        sa.Column("token_digest", sa.String(64), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("issued_by", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_cpf_activation_tokens_cpf_digest", "cpf_activation_tokens", ["cpf_digest"])


def downgrade():
    op.drop_index("ix_cpf_activation_tokens_cpf_digest", table_name="cpf_activation_tokens")
    op.drop_table("cpf_activation_tokens")
    op.drop_column("users", "activated_at")
