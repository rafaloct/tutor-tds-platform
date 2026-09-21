"""Human baseline references and scoped mentorship; no source answers imported.

Revision ID: 20260921_0018
Revises: 20260921_0017
"""
from alembic import op
import sqlalchemy as sa

revision = "20260921_0018"
down_revision = "20260921_0017"
branch_labels = None
depends_on = None


def _association(prefix):
    return [
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("class_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), nullable=False),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.CheckConstraint("revision >= 1", name=f"ck_{prefix}_revision"),
        sa.ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name=f"fk_{prefix}_class"),
        sa.ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name=f"fk_{prefix}_enrollment", ondelete="CASCADE"),
    ]


def _audit(parent, parent_column, prefix):
    return [
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(parent_column, sa.String(36), sa.ForeignKey(f"{parent}.id", ondelete="CASCADE"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("actor_role", sa.String(32), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("idempotency_key", sa.String(180), unique=True, nullable=False),
        sa.Column("snapshot", sa.JSON(), nullable=False),
        sa.UniqueConstraint(parent_column, "revision", name=f"uq_{prefix}_revision"),
        sa.CheckConstraint("revision >= 1", name=f"ck_{prefix}_history_revision" if prefix == "mentorship" else "ck_baseline_revision"),
        sa.CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name=f"ck_{prefix}_revision_reason"),
    ]


def upgrade():
    op.create_table("baseline_source_records",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("source", sa.String(120), nullable=False),
        sa.Column("record_id", sa.String(240), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.UniqueConstraint("source", "record_id", name="uq_baseline_source_reference"),
        sa.UniqueConstraint("id", "user_id", name="uq_baseline_source_owner"),
    )
    op.create_table("student_baselines", *_association("student_baseline"),
        sa.Column("source_record_id", sa.String(36), nullable=False),
        sa.Column("baseline_date", sa.Date(), nullable=False),
        sa.Column("territory_id", sa.String(120)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("class_id", "user_id", name="uq_student_baseline_class_person"),
        sa.ForeignKeyConstraint(["source_record_id", "user_id"], ["baseline_source_records.id", "baseline_source_records.user_id"], name="fk_student_baseline_source_owner"),
    )
    op.create_table("baseline_revisions", *_audit("student_baselines", "baseline_id", "baseline"))
    op.create_table("mentorship_cases", *_association("mentorship"),
        sa.Column("mentor_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("objective", sa.String(1000), nullable=False),
        sa.Column("next_action", sa.String(1000), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("status IN ('open', 'in_progress', 'closed')", name="ck_mentorship_status"),
        sa.CheckConstraint("(status = 'closed' AND closed_at IS NOT NULL) OR (status != 'closed' AND closed_at IS NULL)", name="ck_mentorship_closed_at"),
        sa.CheckConstraint("length(trim(objective)) BETWEEN 3 AND 1000 AND length(trim(next_action)) BETWEEN 3 AND 1000", name="ck_mentorship_text"),
    )
    op.create_index("ix_mentorship_class_user", "mentorship_cases", ["class_id", "user_id"])
    op.create_table("mentorship_revisions", *_audit("mentorship_cases", "case_id", "mentorship"),
        sa.Column("mentor_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("changed_fields", sa.JSON(), nullable=False),
    )
    pg = op.get_bind().dialect.name == "postgresql"
    comparison = "IS DISTINCT FROM" if pg else "IS NOT"

    def changed(fields):
        return " OR ".join(f"NEW.{field}::jsonb {comparison} OLD.{field}::jsonb" if pg and field in {"snapshot", "changed_fields"} else f"NEW.{field} {comparison} OLD.{field}" for field in fields)

    association = ("id", "class_id", "user_id", "enrollment_id", "program_id", "course_id")
    guards = {
        "baseline_source_records": changed(("id", "source", "record_id", "user_id")),
        "student_baselines": f"{changed(association)} OR NEW.revision != OLD.revision + 1",
    }
    case_other = association + ("objective", "next_action", "status", "revision", "opened_at", "updated_at", "closed_at")
    anonymize = f"NEW.mentor_id IS NULL AND NOT ({changed(case_other)})"
    guards["mentorship_cases"] = f"({changed(association + ('opened_at',))} OR NEW.revision != OLD.revision + 1) AND NOT ({anonymize})"
    for table, guard in guards.items():
        if pg:
            op.execute(f"CREATE FUNCTION guard_{table}() RETURNS trigger AS $$ BEGIN IF {guard} THEN RAISE EXCEPTION 'immutable association or invalid revision'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
            op.execute(f"CREATE TRIGGER {table}_guard BEFORE UPDATE ON {table} FOR EACH ROW EXECUTE FUNCTION guard_{table}()")
        else:
            op.execute(f"CREATE TRIGGER {table}_guard BEFORE UPDATE ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT, 'immutable association or invalid revision'); END")
    for table, parent, parent_column in (("baseline_revisions", "student_baselines", "baseline_id"), ("mentorship_revisions", "mentorship_cases", "case_id")):
        fields = ("id", parent_column, "revision", "actor_role", "reason", "occurred_at", "idempotency_key", "snapshot")
        nullable = ("actor_user_id",)
        if table == "mentorship_revisions":
            fields += ("changed_fields",)
            nullable += ("mentor_id",)
        guard = changed(fields) + " OR " + " OR ".join(f"(NEW.{field} {comparison} OLD.{field} AND NEW.{field} IS NOT NULL)" for field in nullable)
        parent_exists = f"EXISTS (SELECT 1 FROM {parent} WHERE id = OLD.{parent_column})"
        if pg:
            op.execute(f"CREATE FUNCTION guard_{table}() RETURNS trigger AS $$ BEGIN IF TG_OP = 'DELETE' THEN IF {parent_exists} THEN RAISE EXCEPTION 'history requires owner erasure'; END IF; RETURN OLD; END IF; IF {guard} THEN RAISE EXCEPTION 'immutable followup history'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
            op.execute(f"CREATE TRIGGER {table}_guard BEFORE UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION guard_{table}()")
        else:
            op.execute(f"CREATE TRIGGER {table}_guard BEFORE UPDATE ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT, 'immutable followup history'); END")
            op.execute(f"CREATE TRIGGER {table}_no_delete BEFORE DELETE ON {table} WHEN {parent_exists} BEGIN SELECT RAISE(ABORT, 'history requires owner erasure'); END")


def downgrade():
    pg = op.get_bind().dialect.name == "postgresql"
    for table in ("mentorship_revisions", "mentorship_cases", "baseline_revisions", "student_baselines", "baseline_source_records"):
        if pg:
            op.execute(f"DROP TRIGGER IF EXISTS {table}_guard ON {table}")
            op.execute(f"DROP FUNCTION IF EXISTS guard_{table}()")
        else:
            op.execute(f"DROP TRIGGER IF EXISTS {table}_guard")
            op.execute(f"DROP TRIGGER IF EXISTS {table}_no_delete")
        op.drop_table(table)
