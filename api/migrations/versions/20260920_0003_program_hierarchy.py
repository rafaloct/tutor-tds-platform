"""connect institutions, programs, courses, users and enrollments

Revision ID: 20260920_0003
Revises: 20260920_0002
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0003"
down_revision = "20260920_0002"
branch_labels = None
depends_on = None

LEGACY_INSTITUTION_ID = "legacy-institution"
LEGACY_PROGRAM_ID = "legacy-program"


def upgrade() -> None:
    op.create_table(
        "program_courses",
        sa.Column(
            "program_id",
            sa.String(36),
            sa.ForeignKey("programs.id"),
            primary_key=True,
        ),
        sa.Column(
            "course_id",
            sa.String(120),
            sa.ForeignKey("courses.id"),
            primary_key=True,
        ),
    )
    op.create_table(
        "program_memberships",
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id"),
            primary_key=True,
        ),
        sa.Column(
            "program_id",
            sa.String(36),
            sa.ForeignKey("programs.id"),
            primary_key=True,
        ),
        sa.Column("role", sa.String(32), nullable=False, server_default="student"),
        sa.Column("status", sa.String(24), nullable=False, server_default="active"),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    with op.batch_alter_table("enrollments") as batch_op:
        batch_op.add_column(sa.Column("program_id", sa.String(36), nullable=True))

    op.execute(
        "INSERT INTO institutions (id, name) "
        f"SELECT '{LEGACY_INSTITUTION_ID}', 'Importação legada' "
        "WHERE EXISTS (SELECT 1 FROM enrollments) "
        f"AND NOT EXISTS (SELECT 1 FROM institutions WHERE id = '{LEGACY_INSTITUTION_ID}')"
    )
    op.execute(
        "INSERT INTO programs (id, institution_id, name) "
        f"SELECT '{LEGACY_PROGRAM_ID}', '{LEGACY_INSTITUTION_ID}', "
        "'Matrículas anteriores à hierarquia' "
        "WHERE EXISTS (SELECT 1 FROM enrollments) "
        f"AND NOT EXISTS (SELECT 1 FROM programs WHERE id = '{LEGACY_PROGRAM_ID}')"
    )
    op.execute(
        "INSERT INTO program_courses (program_id, course_id) "
        f"SELECT DISTINCT '{LEGACY_PROGRAM_ID}', course_id FROM enrollments"
    )
    op.execute(
        "INSERT INTO program_memberships (user_id, program_id, role, status) "
        f"SELECT DISTINCT user_id, '{LEGACY_PROGRAM_ID}', 'student', 'active' "
        "FROM enrollments"
    )
    op.execute(
        f"UPDATE enrollments SET program_id = '{LEGACY_PROGRAM_ID}' "
        "WHERE program_id IS NULL"
    )

    with op.batch_alter_table("enrollments") as batch_op:
        batch_op.alter_column("program_id", existing_type=sa.String(36), nullable=False)
        batch_op.create_foreign_key(
            "fk_enrollments_program",
            "programs",
            ["program_id"],
            ["id"],
        )
        batch_op.create_foreign_key(
            "fk_enrollments_program_course",
            "program_courses",
            ["program_id", "course_id"],
            ["program_id", "course_id"],
        )
        batch_op.create_foreign_key(
            "fk_enrollments_program_membership",
            "program_memberships",
            ["user_id", "program_id"],
            ["user_id", "program_id"],
        )
        batch_op.create_unique_constraint(
            "uq_enrollments_user_program_course",
            ["user_id", "program_id", "course_id"],
        )


def downgrade() -> None:
    with op.batch_alter_table("enrollments") as batch_op:
        batch_op.drop_constraint(
            "uq_enrollments_user_program_course", type_="unique"
        )
        batch_op.drop_constraint(
            "fk_enrollments_program_membership", type_="foreignkey"
        )
        batch_op.drop_constraint(
            "fk_enrollments_program_course", type_="foreignkey"
        )
        batch_op.drop_constraint("fk_enrollments_program", type_="foreignkey")
        batch_op.drop_column("program_id")
    op.drop_table("program_memberships")
    op.drop_table("program_courses")
