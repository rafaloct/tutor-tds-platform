"""Version existing courses in place and pin classroom snapshots.

Revision ID: 20260921_0015
Revises: 20260920_0014
"""
from copy import deepcopy
import hashlib
import json
from uuid import NAMESPACE_URL, uuid5

from alembic import op
import sqlalchemy as sa

revision = "20260921_0015"
down_revision = "20260920_0014"
branch_labels = None
depends_on = None


def _component(course_id, payload):
    value = {key: val for key, val in payload.items() if key != "version_id"}
    digest = hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()
    return str(uuid5(NAMESPACE_URL, f"tds:{course_id}:component:{digest}"))


def _snapshot(course):
    # Local migration implementation must not depend on future app revisions.
    content = deepcopy(course["content"] or {})
    content.update(id=course["id"], title=course["title"], author=course["author"])
    for section in content.setdefault("sections", []):
        for index, message in enumerate(section.get("messages", [])):
            message.setdefault("id", str(uuid5(NAMESPACE_URL, f"tds:{course['id']}:{section['id']}:message:{index}")))
            message["version_id"] = _component(course["id"], message)
        section["version_id"] = _component(course["id"], section)
    return content


def upgrade() -> None:
    op.create_table(
        "course_versions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("program_id", sa.String(36), sa.ForeignKey("programs.id")),
        sa.Column("creator_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("source_version_id", sa.String(36), sa.ForeignKey("course_versions.id")),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("course_id", "version_number", name="uq_course_version_number"),
        sa.UniqueConstraint("id", "course_id", name="uq_course_version_lineage"),
        sa.CheckConstraint("revision >= 1 AND version_number >= 1", name="ck_course_version_revision"),
        sa.CheckConstraint("status IN ('draft', 'in_review', 'published', 'archived')", name="ck_course_version_status"),
    )
    op.create_index("ix_course_versions_program_status", "course_versions", ["program_id", "status"])
    op.create_table(
        "course_version_transitions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("version_id", sa.String(36), sa.ForeignKey("course_versions.id"), nullable=False),
        sa.Column("from_status", sa.String(24)),
        sa.Column("to_status", sa.String(24), nullable=False),
        sa.Column("actor_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("actor_role", sa.String(32), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    connection = op.get_bind()
    courses = sa.table("courses", sa.column("id", sa.String), sa.column("title", sa.String), sa.column("author", sa.String), sa.column("content", sa.JSON), sa.column("active", sa.Boolean))
    versions = sa.table("course_versions", sa.column("id", sa.String), sa.column("course_id", sa.String), sa.column("version_number", sa.Integer), sa.column("revision", sa.Integer), sa.column("status", sa.String), sa.column("content", sa.JSON))
    audits = sa.table("course_version_transitions", sa.column("id", sa.String), sa.column("version_id", sa.String), sa.column("to_status", sa.String), sa.column("actor_role", sa.String))
    for course in connection.execute(sa.select(courses)).mappings().all():
        version_id = str(uuid5(NAMESPACE_URL, f"tds:course:{course['id']}:legacy:v1"))
        status = "published" if course["active"] else "archived"
        connection.execute(versions.insert().values(id=version_id, course_id=course["id"], version_number=1, revision=1, status=status, content=_snapshot(course)))
        connection.execute(audits.insert().values(id=str(uuid5(NAMESPACE_URL, f"tds:course:{course['id']}:migration")), version_id=version_id, to_status=status, actor_role="migration"))
    with op.batch_alter_table("classes") as batch:
        batch.add_column(sa.Column("course_version_id", sa.String(36)))
        batch.create_foreign_key("fk_classes_course_version", "course_versions", ["course_version_id", "course_id"], ["id", "course_id"])
    op.execute("UPDATE classes SET course_version_id = (SELECT id FROM course_versions WHERE course_versions.course_id = classes.course_id AND version_number = 1)")
    _guards()


def _guards() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "sqlite":
        op.execute("""CREATE TRIGGER course_versions_immutable BEFORE UPDATE ON course_versions
            WHEN NEW.course_id IS NOT OLD.course_id OR NEW.id IS NOT OLD.id
              OR NEW.program_id IS NOT OLD.program_id OR (NEW.creator_user_id IS NOT OLD.creator_user_id AND NEW.creator_user_id IS NOT NULL)
              OR NEW.source_version_id IS NOT OLD.source_version_id OR NEW.version_number IS NOT OLD.version_number
              OR NEW.created_at IS NOT OLD.created_at
              OR (OLD.status != 'draft' AND NEW.content IS NOT OLD.content)
              OR (NEW.status != OLD.status AND NOT ((OLD.status = 'draft' AND NEW.status = 'in_review')
                OR (OLD.status = 'in_review' AND NEW.status = 'published')
                OR (OLD.status = 'published' AND NEW.status = 'archived')))
            BEGIN SELECT RAISE(ABORT, 'immutable course version or invalid transition'); END""")
        for table in ("course_versions", "course_version_transitions"):
            op.execute(f"CREATE TRIGGER {table}_no_delete BEFORE DELETE ON {table} BEGIN SELECT RAISE(ABORT, 'course history is append only'); END")
        op.execute("""CREATE TRIGGER course_version_transitions_no_update BEFORE UPDATE ON course_version_transitions
            WHEN NEW.id IS NOT OLD.id OR NEW.version_id IS NOT OLD.version_id
              OR NEW.from_status IS NOT OLD.from_status OR NEW.to_status IS NOT OLD.to_status
              OR NEW.actor_role IS NOT OLD.actor_role OR NEW.occurred_at IS NOT OLD.occurred_at
              OR NEW.actor_user_id IS NOT NULL
            BEGIN SELECT RAISE(ABORT, 'course history is append only'); END""")
    elif dialect == "postgresql":
        op.execute("""CREATE FUNCTION guard_course_version() RETURNS trigger AS $$
            BEGIN
              IF NEW.course_id IS DISTINCT FROM OLD.course_id OR NEW.id IS DISTINCT FROM OLD.id
                OR NEW.program_id IS DISTINCT FROM OLD.program_id OR (NEW.creator_user_id IS DISTINCT FROM OLD.creator_user_id AND NEW.creator_user_id IS NOT NULL)
                OR NEW.source_version_id IS DISTINCT FROM OLD.source_version_id OR NEW.version_number IS DISTINCT FROM OLD.version_number
                OR NEW.created_at IS DISTINCT FROM OLD.created_at
                OR (OLD.status != 'draft' AND NEW.content::jsonb IS DISTINCT FROM OLD.content::jsonb)
                OR (NEW.status != OLD.status AND NOT ((OLD.status = 'draft' AND NEW.status = 'in_review')
                  OR (OLD.status = 'in_review' AND NEW.status = 'published')
                  OR (OLD.status = 'published' AND NEW.status = 'archived'))) THEN
                RAISE EXCEPTION 'immutable course version or invalid transition';
              END IF;
              RETURN NEW;
            END; $$ LANGUAGE plpgsql""")
        op.execute("CREATE TRIGGER course_versions_immutable BEFORE UPDATE ON course_versions FOR EACH ROW EXECUTE FUNCTION guard_course_version()")
        op.execute("""CREATE FUNCTION reject_course_history_mutation() RETURNS trigger AS $$
            BEGIN RAISE EXCEPTION 'course history is append only'; END; $$ LANGUAGE plpgsql""")
        for table in ("course_versions", "course_version_transitions"):
            op.execute(f"CREATE TRIGGER {table}_no_delete BEFORE DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION reject_course_history_mutation()")
        op.execute("""CREATE FUNCTION guard_course_audit() RETURNS trigger AS $$
            BEGIN
              IF NEW.id IS DISTINCT FROM OLD.id OR NEW.version_id IS DISTINCT FROM OLD.version_id
                OR NEW.from_status IS DISTINCT FROM OLD.from_status OR NEW.to_status IS DISTINCT FROM OLD.to_status
                OR NEW.actor_role IS DISTINCT FROM OLD.actor_role OR NEW.occurred_at IS DISTINCT FROM OLD.occurred_at
                OR NEW.actor_user_id IS NOT NULL THEN
                RAISE EXCEPTION 'course history is append only';
              END IF;
              RETURN NEW;
            END; $$ LANGUAGE plpgsql""")
        op.execute("CREATE TRIGGER course_version_transitions_no_update BEFORE UPDATE ON course_version_transitions FOR EACH ROW EXECUTE FUNCTION guard_course_audit()")


def downgrade() -> None:
    dialect = op.get_bind().dialect.name
    for table, trigger in (("course_versions", "course_versions_immutable"), ("course_versions", "course_versions_no_delete"), ("course_version_transitions", "course_version_transitions_no_delete"), ("course_version_transitions", "course_version_transitions_no_update")):
        op.execute(f"DROP TRIGGER IF EXISTS {trigger}" + (f" ON {table}" if dialect == "postgresql" else ""))
    if dialect == "postgresql":
        op.execute("DROP FUNCTION IF EXISTS guard_course_version()")
        op.execute("DROP FUNCTION IF EXISTS reject_course_history_mutation()")
        op.execute("DROP FUNCTION IF EXISTS guard_course_audit()")
    with op.batch_alter_table("classes") as batch:
        batch.drop_constraint("fk_classes_course_version", type_="foreignkey")
        batch.drop_column("course_version_id")
    op.drop_table("course_version_transitions")
    op.drop_index("ix_course_versions_program_status", table_name="course_versions")
    op.drop_table("course_versions")
