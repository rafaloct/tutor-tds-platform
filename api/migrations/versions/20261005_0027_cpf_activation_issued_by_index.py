"""Index CPF activation token issuer references."""
from alembic import op

revision = "20261005_0027"
down_revision = "20261003_0026"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index(
        "ix_cpf_activation_tokens_issued_by",
        "cpf_activation_tokens",
        ["issued_by"],
    )


def downgrade():
    op.drop_index(
        "ix_cpf_activation_tokens_issued_by",
        table_name="cpf_activation_tokens",
    )
