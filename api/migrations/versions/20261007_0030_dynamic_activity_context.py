"""Add complete published-block lineage to existing assessment attempts.

Revision ID: 20261007_0030
Revises: 20261006_0029
"""

from alembic import op
import sqlalchemy as sa


revision = "20261007_0030"
down_revision = "20261006_0029"
branch_labels = None
depends_on = None


CONTEXT_COLUMNS = (
    "organization_id",
    "program_id",
    "class_id",
    "membership_id",
    "enrollment_id",
    "legacy_enrollment_id",
    "course_version_id",
    "section_id",
    "section_version_id",
    "block_id",
    "block_version_id",
)


def upgrade() -> None:
    reserved_collisions = op.get_bind().execute(
        sa.text(
            "SELECT COUNT(*) FROM assessment_contents "
            "WHERE substr(id, 1, 16) = 'published-block:'"
        )
    ).scalar_one()
    if reserved_collisions:
        raise RuntimeError(
            "Upgrade recusado: assessment_contents contém identificadores no "
            "namespace reservado published-block:. Renomeie/reconcilie esses "
            "registros de prática antes de ativar a Wave 2B."
        )
    content_guard_sql = _assessment_content_guard_sql()
    _drop_assessment_content_guard()
    with op.batch_alter_table("assessment_contents") as batch:
        batch.add_column(
            sa.Column(
                "origin",
                sa.String(24),
                nullable=False,
                server_default="practice",
            )
        )
        batch.create_check_constraint(
            "ck_assessment_content_origin",
            "origin IN ('practice', 'published_block')",
        )
    _create_assessment_content_guard(content_guard_sql)
    with op.batch_alter_table("assessment_attempts") as batch:
        batch.add_column(
            sa.Column(
                "origin",
                sa.String(24),
                nullable=False,
                server_default="practice",
            )
        )
        batch.add_column(sa.Column("organization_id", sa.String(36)))
        batch.add_column(sa.Column("program_id", sa.String(36)))
        batch.add_column(sa.Column("class_id", sa.String(36)))
        batch.add_column(sa.Column("membership_id", sa.String(36)))
        batch.add_column(sa.Column("enrollment_id", sa.String(36)))
        batch.add_column(sa.Column("legacy_enrollment_id", sa.String(36)))
        batch.add_column(sa.Column("course_version_id", sa.String(36)))
        batch.add_column(sa.Column("section_id", sa.String(120)))
        batch.add_column(sa.Column("section_version_id", sa.String(36)))
        batch.add_column(sa.Column("block_id", sa.String(180)))
        batch.add_column(sa.Column("block_version_id", sa.String(36)))
        batch.create_foreign_key(
            "fk_assessment_attempt_organization",
            "institutions",
            ["organization_id"],
            ["id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_program",
            "programs",
            ["program_id"],
            ["id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_class",
            "classes",
            ["class_id"],
            ["id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_membership",
            "cohort_memberships",
            ["membership_id"],
            ["id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_context_enrollment",
            "class_enrollments",
            ["enrollment_id"],
            ["context_id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_legacy_enrollment",
            "enrollments",
            ["legacy_enrollment_id"],
            ["id"],
        )
        batch.create_foreign_key(
            "fk_assessment_attempt_course_version",
            "course_versions",
            ["course_version_id", "course_id"],
            ["id", "course_id"],
        )
        batch.create_check_constraint(
            "ck_assessment_attempt_origin",
            "origin IN ('practice', 'published_block')",
        )
        batch.create_check_constraint(
            "ck_assessment_attempt_context_complete",
            "(origin = 'practice' AND organization_id IS NULL AND program_id IS NULL "
            "AND class_id IS NULL AND membership_id IS NULL AND enrollment_id IS NULL "
            "AND legacy_enrollment_id IS NULL AND course_version_id IS NULL "
            "AND section_id IS NULL AND section_version_id IS NULL AND block_id IS NULL "
            "AND block_version_id IS NULL) OR "
            "(origin = 'published_block' AND organization_id IS NOT NULL AND program_id IS NOT NULL "
            "AND class_id IS NOT NULL AND membership_id IS NOT NULL AND enrollment_id IS NOT NULL "
            "AND legacy_enrollment_id IS NOT NULL AND course_version_id IS NOT NULL "
            "AND section_id IS NOT NULL AND section_version_id IS NOT NULL AND block_id IS NOT NULL "
            "AND block_version_id IS NOT NULL)",
        )
        batch.create_index(
            "ix_assessment_attempts_context_owner",
            ["owner_id", "class_id", "course_version_id", "updated_at"],
        )
    op.create_index(
        "uq_assessment_attempts_published_block",
        "assessment_attempts",
        [
            "owner_id",
            "enrollment_id",
            "course_version_id",
            "section_id",
            "section_version_id",
            "block_id",
            "block_version_id",
        ],
        unique=True,
        sqlite_where=sa.text("origin = 'published_block'"),
        postgresql_where=sa.text("origin = 'published_block'"),
    )


def downgrade() -> None:
    contextual = op.get_bind().execute(
        sa.text(
            "SELECT COUNT(*) FROM assessment_attempts "
            "WHERE origin = 'published_block'"
        )
    ).scalar_one()
    published_content = op.get_bind().execute(
        sa.text(
            "SELECT COUNT(*) FROM assessment_contents "
            "WHERE origin = 'published_block'"
        )
    ).scalar_one()
    if contextual or published_content:
        raise RuntimeError(
            "Downgrade recusado: conteúdo/tentativas published_block preservam "
            "proveniência e linhagem 2B. "
            "Use forward recovery."
        )
    op.drop_index(
        "uq_assessment_attempts_published_block",
        table_name="assessment_attempts",
    )
    with op.batch_alter_table("assessment_attempts") as batch:
        batch.drop_index("ix_assessment_attempts_context_owner")
        batch.drop_constraint(
            "ck_assessment_attempt_context_complete", type_="check"
        )
        batch.drop_constraint("ck_assessment_attempt_origin", type_="check")
        batch.drop_constraint(
            "fk_assessment_attempt_course_version", type_="foreignkey"
        )
        batch.drop_constraint(
            "fk_assessment_attempt_legacy_enrollment", type_="foreignkey"
        )
        batch.drop_constraint(
            "fk_assessment_attempt_context_enrollment", type_="foreignkey"
        )
        batch.drop_constraint(
            "fk_assessment_attempt_membership", type_="foreignkey"
        )
        batch.drop_constraint("fk_assessment_attempt_class", type_="foreignkey")
        batch.drop_constraint("fk_assessment_attempt_program", type_="foreignkey")
        batch.drop_constraint(
            "fk_assessment_attempt_organization", type_="foreignkey"
        )
        for column in reversed(CONTEXT_COLUMNS):
            batch.drop_column(column)
        batch.drop_column("origin")
    content_guard_sql = _assessment_content_guard_sql()
    _drop_assessment_content_guard()
    with op.batch_alter_table("assessment_contents") as batch:
        batch.drop_constraint("ck_assessment_content_origin", type_="check")
        batch.drop_column("origin")
    _create_assessment_content_guard(content_guard_sql)


def _assessment_content_guard_sql() -> str | None:
    if op.get_bind().dialect.name != "sqlite":
        return None
    statement = op.get_bind().execute(
        sa.text(
            "SELECT sql FROM sqlite_master WHERE type = 'trigger' "
            "AND name = 'assessment_contents_immutable'"
        )
    ).scalar_one_or_none()
    if not isinstance(statement, str) or not statement:
        raise RuntimeError(
            "Upgrade recusado: trigger imutável de assessment_contents ausente."
        )
    return statement


def _drop_assessment_content_guard() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            "DROP TRIGGER IF EXISTS assessment_contents_immutable "
            "ON assessment_contents"
        )
    elif dialect == "sqlite":
        op.execute("DROP TRIGGER IF EXISTS assessment_contents_immutable")


def _create_assessment_content_guard(sqlite_statement: str | None) -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            "CREATE TRIGGER assessment_contents_immutable "
            "BEFORE UPDATE ON assessment_contents FOR EACH ROW "
            "EXECUTE FUNCTION reject_assessment_content_update()"
        )
    elif dialect == "sqlite":
        if sqlite_statement is None:
            raise RuntimeError(
                "Trigger imutável de assessment_contents não pôde ser restaurado."
            )
        op.execute(sqlite_statement)
