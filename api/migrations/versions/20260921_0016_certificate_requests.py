"""Private, version-specific certificate requests and human decision history.

Revision ID: 20260921_0016
Revises: 20260921_0015
"""
from alembic import op
import sqlalchemy as sa

revision = "20260921_0016"
down_revision = "20260921_0015"
branch_labels = None
depends_on = None

IMMUTABLE = ("id", "user_id", "enrollment_id", "course_id", "course_version_id", "class_id", "program_id", "institution_id", "holder_name", "course_title", "program_name", "institution_name", "required_seconds", "requested_at")
AUDIT_IMMUTABLE = ("id", "request_id", "revision", "from_status", "to_status", "actor_role", "reason", "eligibility", "occurred_at")


def upgrade():
    op.create_table(
        "certificate_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("course_version_id", sa.String(36), nullable=False),
        sa.Column("class_id", sa.String(36)),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column("institution_id", sa.String(36), sa.ForeignKey("institutions.id"), nullable=False),
        *[sa.Column(name, sa.String(240), nullable=False) for name in ("holder_name", "course_title", "program_name", "institution_name")],
        sa.Column("required_seconds", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("requested_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("review_reason", sa.String(500)),
        sa.UniqueConstraint("enrollment_id", "course_version_id", name="uq_certificate_request_edition"),
        sa.ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_certificate_request_enrollment", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["course_version_id", "course_id"], ["course_versions.id", "course_versions.course_id"], name="fk_certificate_request_version"),
        sa.ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_certificate_request_class"),
        sa.CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="ck_certificate_request_status"),
        sa.CheckConstraint("revision >= 1 AND required_seconds >= 0", name="ck_certificate_request_numbers"),
        sa.CheckConstraint("(status = 'pending' AND reviewed_at IS NULL AND review_reason IS NULL) OR (status != 'pending' AND reviewed_at IS NOT NULL AND review_reason IS NOT NULL)", name="ck_certificate_request_review"),
    )
    op.create_index("ix_certificate_requests_program_status", "certificate_requests", ["program_id", "status"])
    op.create_table(
        "certificate_request_transitions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("request_id", sa.String(36), sa.ForeignKey("certificate_requests.id", ondelete="CASCADE"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("from_status", sa.String(24)),
        sa.Column("to_status", sa.String(24), nullable=False),
        sa.Column("actor_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("actor_role", sa.String(32), nullable=False),
        sa.Column("reason", sa.String(500)),
        sa.Column("eligibility", sa.JSON(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("request_id", "revision", name="uq_certificate_request_transition_revision"),
        sa.CheckConstraint("revision >= 1", name="ck_certificate_request_transition_revision"),
        sa.CheckConstraint("to_status IN ('pending', 'approved', 'rejected') AND (from_status IS NULL OR from_status IN ('pending', 'rejected'))", name="ck_certificate_request_transition_status"),
    )
    dialect = op.get_bind().dialect.name
    comparison = "IS DISTINCT FROM" if dialect == "postgresql" else "IS NOT"
    immutable = " OR ".join(f"NEW.{field} {comparison} OLD.{field}" for field in IMMUTABLE)
    transition = "NEW.revision != OLD.revision + 1 OR NOT ((OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected')) OR (OLD.status = 'rejected' AND NEW.status = 'pending'))"
    audit_parts = [f"NEW.{field}::jsonb {comparison} OLD.{field}::jsonb" if field == "eligibility" and dialect == "postgresql" else f"NEW.{field} {comparison} OLD.{field}" for field in AUDIT_IMMUTABLE]
    audit_guard = " OR ".join(audit_parts) + " OR NEW.actor_user_id IS NOT NULL"
    if dialect == "sqlite":
        op.execute(f"CREATE TRIGGER certificate_request_snapshot BEFORE UPDATE ON certificate_requests WHEN {immutable} OR {transition} BEGIN SELECT RAISE(ABORT, 'immutable request snapshot or invalid transition'); END")
        op.execute(f"CREATE TRIGGER certificate_request_history_immutable BEFORE UPDATE ON certificate_request_transitions WHEN {audit_guard} BEGIN SELECT RAISE(ABORT, 'immutable request history'); END")
        # Owner erasure deletes the parent first. A cascade then sees no parent;
        # normal direct audit deletion while the request exists remains forbidden.
        op.execute("CREATE TRIGGER certificate_request_history_no_delete BEFORE DELETE ON certificate_request_transitions WHEN EXISTS (SELECT 1 FROM certificate_requests WHERE id = OLD.request_id) BEGIN SELECT RAISE(ABORT, 'request history requires owner erasure'); END")
    elif dialect == "postgresql":
        op.execute(f"CREATE FUNCTION guard_certificate_request() RETURNS trigger AS $$ BEGIN IF {immutable} OR {transition} THEN RAISE EXCEPTION 'immutable request snapshot or invalid transition'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        op.execute("CREATE TRIGGER certificate_request_snapshot BEFORE UPDATE ON certificate_requests FOR EACH ROW EXECUTE FUNCTION guard_certificate_request()")
        op.execute(f"CREATE FUNCTION guard_certificate_request_history() RETURNS trigger AS $$ BEGIN IF TG_OP = 'DELETE' THEN IF EXISTS (SELECT 1 FROM certificate_requests WHERE id = OLD.request_id) THEN RAISE EXCEPTION 'request history requires owner erasure'; END IF; RETURN OLD; END IF; IF {audit_guard} THEN RAISE EXCEPTION 'immutable request history'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        op.execute("CREATE TRIGGER certificate_request_history_immutable BEFORE UPDATE OR DELETE ON certificate_request_transitions FOR EACH ROW EXECUTE FUNCTION guard_certificate_request_history()")


def downgrade():
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP TRIGGER IF EXISTS certificate_request_snapshot ON certificate_requests")
        op.execute("DROP TRIGGER IF EXISTS certificate_request_history_immutable ON certificate_request_transitions")
        op.execute("DROP FUNCTION IF EXISTS guard_certificate_request()")
        op.execute("DROP FUNCTION IF EXISTS guard_certificate_request_history()")
    else:
        for name in ("certificate_request_snapshot", "certificate_request_history_immutable", "certificate_request_history_no_delete"):
            op.execute(f"DROP TRIGGER IF EXISTS {name}")
    op.drop_table("certificate_request_transitions")
    op.drop_index("ix_certificate_requests_program_status", table_name="certificate_requests")
    op.drop_table("certificate_requests")
