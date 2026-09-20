"""add planned and validated learning time

Revision ID: 20260920_0005
Revises: 20260920_0004
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0005"
down_revision = "20260920_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("program_courses") as batch_op:
        batch_op.add_column(
            sa.Column(
                "planned_seconds",
                sa.Integer(),
                nullable=False,
                server_default=str(40 * 60 * 60),
            )
        )
    with op.batch_alter_table("learning_events") as batch_op:
        batch_op.add_column(sa.Column("enrollment_id", sa.String(36), nullable=True))
        batch_op.add_column(
            sa.Column("active_seconds", sa.Integer(), nullable=False, server_default="0")
        )
        batch_op.add_column(
            sa.Column(
                "validated_seconds", sa.Integer(), nullable=False, server_default="0"
            )
        )
        batch_op.create_foreign_key(
            "fk_learning_events_enrollment",
            "enrollments",
            ["enrollment_id"],
            ["id"],
        )


def downgrade() -> None:
    with op.batch_alter_table("learning_events") as batch_op:
        batch_op.drop_constraint(
            "fk_learning_events_enrollment", type_="foreignkey"
        )
        batch_op.drop_column("validated_seconds")
        batch_op.drop_column("active_seconds")
        batch_op.drop_column("enrollment_id")
    with op.batch_alter_table("program_courses") as batch_op:
        batch_op.drop_column("planned_seconds")
