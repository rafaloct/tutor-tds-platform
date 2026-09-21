"""Human session presence, immutable association and append-only decisions.

Revision ID: 20260921_0017
Revises: 20260921_0016
"""
from alembic import op
import sqlalchemy as sa

revision = "20260921_0017"
down_revision = "20260921_0016"
branch_labels = None
depends_on = None

SNAPSHOT = ("id", "session_id", "class_id", "user_id", "enrollment_id", "program_id", "course_id", "user_name")
HISTORY = ("id", "presence_id", "revision", "status", "reason", "decided_at", "actor_role", "idempotency_key", "evidence_counts")


def upgrade():
    op.create_index("uq_class_sessions_class_lineage", "class_sessions", ["id", "class_id"], unique=True)
    op.create_table(
        "session_presence",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("session_id", sa.String(36), nullable=False),
        sa.Column("class_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), nullable=False),
        sa.Column("program_id", sa.String(36), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("user_name", sa.String(240), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("session_id", "user_id", name="uq_session_presence_person"),
        sa.ForeignKeyConstraint(["session_id", "class_id"], ["class_sessions.id", "class_sessions.class_id"], name="fk_presence_session"),
        sa.ForeignKeyConstraint(["class_id", "program_id", "course_id"], ["classes.id", "classes.program_id", "classes.course_id"], name="fk_presence_class"),
        sa.ForeignKeyConstraint(["enrollment_id", "user_id", "program_id", "course_id"], ["enrollments.id", "enrollments.user_id", "enrollments.program_id", "enrollments.course_id"], name="fk_presence_enrollment", ondelete="CASCADE"),
        sa.CheckConstraint("status IN ('confirmed_present', 'justified_absence', 'absent')", name="ck_presence_status"),
        sa.CheckConstraint("revision >= 1", name="ck_presence_revision"),
        sa.CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_presence_reason"),
    )
    op.create_table(
        "session_presence_decisions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("presence_id", sa.String(36), sa.ForeignKey("session_presence.id", ondelete="CASCADE"), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("actor_role", sa.String(32), nullable=False),
        sa.Column("idempotency_key", sa.String(180), nullable=False, unique=True),
        sa.Column("evidence_counts", sa.JSON(), nullable=False),
        sa.UniqueConstraint("presence_id", "revision", name="uq_presence_decision_revision"),
        sa.CheckConstraint("revision >= 1", name="ck_presence_decision_revision"),
        sa.CheckConstraint("status IN ('confirmed_present', 'justified_absence', 'absent')", name="ck_presence_decision_status"),
        sa.CheckConstraint("length(trim(reason)) BETWEEN 3 AND 500", name="ck_presence_decision_reason"),
    )
    dialect = op.get_bind().dialect.name
    comparison = "IS DISTINCT FROM" if dialect == "postgresql" else "IS NOT"
    changed = " OR ".join(f"NEW.{field} {comparison} OLD.{field}" for field in SNAPSHOT)
    closed = "NOT EXISTS (SELECT 1 FROM class_sessions WHERE id = NEW.session_id AND class_id = NEW.class_id AND status = 'open')"
    guard = " OR ".join(f"NEW.{field}::jsonb {comparison} OLD.{field}::jsonb" if field == "evidence_counts" and dialect == "postgresql" else f"NEW.{field} {comparison} OLD.{field}" for field in HISTORY) + " OR NEW.actor_user_id IS NOT NULL"
    if dialect == "sqlite":
        op.execute(f"CREATE TRIGGER session_presence_insert BEFORE INSERT ON session_presence WHEN NEW.revision != 1 OR {closed} BEGIN SELECT RAISE(ABORT, 'presence requires open session and initial revision'); END")
        op.execute(f"CREATE TRIGGER session_presence_snapshot BEFORE UPDATE ON session_presence WHEN {changed} OR NEW.revision != OLD.revision + 1 OR {closed} BEGIN SELECT RAISE(ABORT, 'immutable presence association or invalid revision'); END")
        op.execute(f"CREATE TRIGGER session_presence_history_immutable BEFORE UPDATE ON session_presence_decisions WHEN {guard} BEGIN SELECT RAISE(ABORT, 'immutable presence history'); END")
        op.execute("CREATE TRIGGER session_presence_history_no_delete BEFORE DELETE ON session_presence_decisions WHEN EXISTS (SELECT 1 FROM session_presence WHERE id = OLD.presence_id) BEGIN SELECT RAISE(ABORT, 'presence history requires owner erasure'); END")
    elif dialect == "postgresql":
        op.execute(f"CREATE FUNCTION guard_session_presence() RETURNS trigger AS $$ BEGIN IF {closed} THEN RAISE EXCEPTION 'presence requires open session'; END IF; IF TG_OP = 'INSERT' THEN IF NEW.revision != 1 THEN RAISE EXCEPTION 'invalid initial revision'; END IF; ELSIF {changed} OR NEW.revision != OLD.revision + 1 THEN RAISE EXCEPTION 'immutable presence association or invalid revision'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        op.execute("CREATE TRIGGER session_presence_snapshot BEFORE INSERT OR UPDATE ON session_presence FOR EACH ROW EXECUTE FUNCTION guard_session_presence()")
        op.execute(f"CREATE FUNCTION guard_session_presence_history() RETURNS trigger AS $$ BEGIN IF TG_OP = 'DELETE' THEN IF EXISTS (SELECT 1 FROM session_presence WHERE id = OLD.presence_id) THEN RAISE EXCEPTION 'presence history requires owner erasure'; END IF; RETURN OLD; END IF; IF {guard} THEN RAISE EXCEPTION 'immutable presence history'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        op.execute("CREATE TRIGGER session_presence_history_immutable BEFORE UPDATE OR DELETE ON session_presence_decisions FOR EACH ROW EXECUTE FUNCTION guard_session_presence_history()")


def downgrade():
    if op.get_bind().dialect.name == "postgresql":
        op.execute("DROP TRIGGER IF EXISTS session_presence_snapshot ON session_presence")
        op.execute("DROP TRIGGER IF EXISTS session_presence_history_immutable ON session_presence_decisions")
        op.execute("DROP FUNCTION IF EXISTS guard_session_presence()")
        op.execute("DROP FUNCTION IF EXISTS guard_session_presence_history()")
    else:
        for name in ("session_presence_insert", "session_presence_snapshot", "session_presence_history_immutable", "session_presence_history_no_delete"):
            op.execute(f"DROP TRIGGER IF EXISTS {name}")
    op.drop_table("session_presence_decisions")
    op.drop_table("session_presence")
    op.drop_index("uq_class_sessions_class_lineage", table_name="class_sessions")
