"""Persist contextual membership and reuse class_enrollments as versioned enrollment.

Revision ID: 20260923_0019
Revises: 20260921_0018
"""
import json
from uuid import NAMESPACE_URL, uuid5

from alembic import op
import sqlalchemy as sa

revision = "20260923_0019"
down_revision = "20260921_0018"
branch_labels = None
depends_on = None


def _id(kind, values):
    return str(uuid5(NAMESPACE_URL, "tds:" + kind + ":" + json.dumps(values, separators=(",", ":"))))


def upgrade():
    connection = op.get_bind()
    invalid = connection.execute(sa.text("""SELECT ce.class_id FROM class_enrollments ce
        LEFT JOIN classes c ON c.id=ce.class_id
        LEFT JOIN course_versions v ON v.id=c.course_version_id AND v.course_id=ce.course_id
        WHERE v.id IS NULL OR v.status NOT IN ('published','archived')
           OR ce.status NOT IN ('active','inactive') LIMIT 1""")).first()
    if invalid:
        raise RuntimeError("Context backfill blocked: missing pinned version or unsupported membership status; run preflight.")
    op.create_table("cohort_memberships",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", sa.String(24), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("class_id", "user_id", "role", name="uq_cohort_membership_natural"),
        sa.UniqueConstraint("id", "class_id", "user_id", "role", name="uq_cohort_membership_lineage"),
        sa.CheckConstraint("role IN ('student','teacher','monitor')", name="ck_cohort_membership_role"),
        sa.CheckConstraint("status IN ('active','inactive')", name="ck_cohort_membership_status"),
    )
    op.create_index("ix_cohort_membership_user_status", "cohort_memberships", ["user_id", "status"])
    with op.batch_alter_table("class_enrollments") as batch:
        batch.add_column(sa.Column("context_id", sa.String(36)))
        batch.add_column(sa.Column("membership_id", sa.String(36)))
        batch.add_column(sa.Column("membership_role", sa.String(24), nullable=False, server_default="student"))
        batch.add_column(sa.Column("course_version_id", sa.String(36)))
        batch.create_unique_constraint("uq_class_enrollment_context_id", ["context_id"])
        batch.create_unique_constraint("uq_class_enrollment_membership_version", ["membership_id", "course_version_id"])
        batch.create_foreign_key("fk_class_enrollment_membership", "cohort_memberships",
            ["membership_id", "class_id", "user_id", "membership_role"], ["id", "class_id", "user_id", "role"])
        batch.create_foreign_key("fk_class_enrollment_version", "course_versions", ["course_version_id", "course_id"], ["id", "course_id"])
        batch.create_check_constraint("ck_class_enrollment_student", "membership_role = 'student'")
        batch.create_check_constraint("ck_class_enrollment_context_complete",
            "(context_id IS NULL AND membership_id IS NULL AND course_version_id IS NULL) OR "
            "(context_id IS NOT NULL AND membership_id IS NOT NULL AND course_version_id IS NOT NULL)")
    insert = sa.text("INSERT INTO cohort_memberships (id,class_id,user_id,role,status) VALUES (:id,:class_id,:user_id,:role,:status)")
    for row in connection.execute(sa.text("SELECT id,teacher_id FROM classes")).mappings():
        connection.execute(insert, dict(id=_id("membership", [row['id'], row['teacher_id'], 'teacher']),
            class_id=row['id'], user_id=row['teacher_id'], role='teacher', status='active'))
    for row in connection.execute(sa.text("SELECT class_id,user_id FROM class_monitors")).mappings():
        connection.execute(insert, dict(id=_id("membership", [row['class_id'], row['user_id'], 'monitor']),
            class_id=row['class_id'], user_id=row['user_id'], role='monitor', status='active'))
    rows = connection.execute(sa.text("""SELECT ce.class_id,ce.user_id,ce.status,c.course_version_id
        FROM class_enrollments ce JOIN classes c ON c.id=ce.class_id""")).mappings().all()
    for row in rows:
        membership_id = _id('membership', [row['class_id'], row['user_id'], 'student'])
        connection.execute(insert, dict(id=membership_id, class_id=row['class_id'], user_id=row['user_id'], role='student', status=row['status']))
        connection.execute(sa.text("""UPDATE class_enrollments SET context_id=:context_id,
            membership_id=:membership_id,course_version_id=:version WHERE class_id=:cohort AND user_id=:user"""),
            dict(context_id=_id('enrollment', [membership_id, row['course_version_id']]), membership_id=membership_id,
                 version=row['course_version_id'], cohort=row['class_id'], user=row['user_id']))


def downgrade():
    with op.batch_alter_table("class_enrollments") as batch:
        batch.drop_constraint("ck_class_enrollment_context_complete", type_="check")
        batch.drop_constraint("ck_class_enrollment_student", type_="check")
        batch.drop_constraint("fk_class_enrollment_version", type_="foreignkey")
        batch.drop_constraint("fk_class_enrollment_membership", type_="foreignkey")
        batch.drop_constraint("uq_class_enrollment_membership_version", type_="unique")
        batch.drop_constraint("uq_class_enrollment_context_id", type_="unique")
        for column in ("course_version_id", "membership_role", "membership_id", "context_id"):
            batch.drop_column(column)
    op.drop_index("ix_cohort_membership_user_status", table_name="cohort_memberships")
    op.drop_table("cohort_memberships")
