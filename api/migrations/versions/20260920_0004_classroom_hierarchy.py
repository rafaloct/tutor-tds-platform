"""add classroom hierarchy

Revision ID: 20260920_0004
Revises: 20260920_0003
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0004"
down_revision = "20260920_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("enrollments") as batch_op:
        batch_op.create_unique_constraint(
            "uq_enrollments_lineage",
            ["id", "user_id", "program_id", "course_id"],
        )
    op.create_table(
        "classes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("teacher_id", sa.String(36), nullable=False),
        sa.Column("name", sa.String(240), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="planned"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["program_id"], ["programs.id"]),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"]),
        sa.ForeignKeyConstraint(["teacher_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["program_id", "course_id"],
            ["program_courses.program_id", "program_courses.course_id"],
            name="fk_classes_program_course",
        ),
        sa.ForeignKeyConstraint(
            ["teacher_id", "program_id"],
            ["program_memberships.user_id", "program_memberships.program_id"],
            name="fk_classes_teacher_membership",
        ),
        sa.CheckConstraint(
            "end_date >= start_date",
            name="ck_classes_date_range",
        ),
        sa.UniqueConstraint(
            "id", "program_id", name="uq_classes_program_lineage"
        ),
        sa.UniqueConstraint(
            "id",
            "program_id",
            "course_id",
            name="uq_classes_course_lineage",
        ),
    )
    op.create_table(
        "class_enrollments",
        sa.Column("class_id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), primary_key=True),
        sa.Column("enrollment_id", sa.String(36), nullable=False),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="active"),
        sa.Column(
            "enrolled_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["class_id", "program_id", "course_id"],
            ["classes.id", "classes.program_id", "classes.course_id"],
            name="fk_class_enrollments_class_lineage",
        ),
        sa.ForeignKeyConstraint(
            ["enrollment_id", "user_id", "program_id", "course_id"],
            [
                "enrollments.id",
                "enrollments.user_id",
                "enrollments.program_id",
                "enrollments.course_id",
            ],
            name="fk_class_enrollments_enrollment_lineage",
        ),
    )
    op.create_table(
        "class_monitors",
        sa.Column("class_id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), primary_key=True),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column(
            "assigned_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["class_id", "program_id"],
            ["classes.id", "classes.program_id"],
            name="fk_class_monitors_class_program",
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "program_id"],
            ["program_memberships.user_id", "program_memberships.program_id"],
            name="fk_class_monitors_program_membership",
        ),
    )


def downgrade() -> None:
    op.drop_table("class_monitors")
    op.drop_table("class_enrollments")
    op.drop_table("classes")
    with op.batch_alter_table("enrollments") as batch_op:
        batch_op.drop_constraint("uq_enrollments_lineage", type_="unique")
