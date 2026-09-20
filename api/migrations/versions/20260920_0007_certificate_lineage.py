"""add certificate academic lineage snapshots

Revision ID: 20260920_0007
Revises: 20260920_0006
"""

from alembic import op
import sqlalchemy as sa


revision = "20260920_0007"
down_revision = "20260920_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("certificates") as batch_op:
        batch_op.add_column(sa.Column("program_id", sa.String(36)))
        batch_op.add_column(sa.Column("class_id", sa.String(36)))
        batch_op.add_column(sa.Column("holder_name", sa.String(240)))
        batch_op.add_column(sa.Column("course_title", sa.String(240)))
        batch_op.add_column(sa.Column("institution_name", sa.String(240)))
        batch_op.add_column(sa.Column("planned_seconds", sa.Integer()))
        batch_op.create_foreign_key(
            "fk_certificates_program", "programs", ["program_id"], ["id"]
        )
        batch_op.create_foreign_key(
            "fk_certificates_class", "classes", ["class_id"], ["id"]
        )
    op.execute(
        "UPDATE certificates SET holder_name = "
        "(SELECT users.name FROM users WHERE users.id = certificates.user_id), "
        "course_title = (SELECT courses.title FROM courses WHERE courses.id = certificates.course_id), "
        "program_id = (SELECT enrollments.program_id FROM enrollments "
        "WHERE enrollments.user_id = certificates.user_id "
        "AND enrollments.course_id = certificates.course_id LIMIT 1)"
    )
    op.execute(
        "UPDATE certificates SET institution_name = (SELECT institutions.name "
        "FROM programs JOIN institutions ON institutions.id = programs.institution_id "
        "WHERE programs.id = certificates.program_id), "
        "planned_seconds = (SELECT program_courses.planned_seconds FROM program_courses "
        "WHERE program_courses.program_id = certificates.program_id "
        "AND program_courses.course_id = certificates.course_id)"
    )


def downgrade() -> None:
    with op.batch_alter_table("certificates") as batch_op:
        batch_op.drop_constraint("fk_certificates_class", type_="foreignkey")
        batch_op.drop_constraint("fk_certificates_program", type_="foreignkey")
        batch_op.drop_column("planned_seconds")
        batch_op.drop_column("institution_name")
        batch_op.drop_column("course_title")
        batch_op.drop_column("holder_name")
        batch_op.drop_column("class_id")
        batch_op.drop_column("program_id")
