"""Reserve an explicitly reviewed BI inscription using existing source records."""
from alembic import op
import sqlalchemy as sa

revision = "20261001_0020"
down_revision = "20260923_0019"
branch_labels = None
depends_on = None


def _suspend_sqlite_guards():
    connection = op.get_bind()
    if connection.dialect.name != "sqlite":
        return []
    # SQLite validates triggers on OTHER tables during a batch table rename.
    # Preserve the original immutable-history guards, including their SQL.
    guards = connection.execute(sa.text("SELECT name, sql FROM sqlite_master WHERE type='trigger' AND sql LIKE '%student_baselines%' ORDER BY name")).all()
    for name, _ in guards:
        connection.exec_driver_sql(f'DROP TRIGGER "{name}"')
    return guards


def _restore_guards(guards):
    for _, sql in guards:
        op.get_bind().exec_driver_sql(sql)


def upgrade():
    guards = _suspend_sqlite_guards()
    with op.batch_alter_table("student_baselines") as batch:
        batch.add_column(sa.Column("bi_source_record_id", sa.String(36), nullable=True))
        batch.create_unique_constraint("uq_student_baseline_bi_reference", ["bi_source_record_id"])
        batch.create_foreign_key("fk_student_baseline_bi_owner", "baseline_source_records",
                                 ["bi_source_record_id", "user_id"], ["id", "user_id"])
    _restore_guards(guards)


def downgrade():
    count = op.get_bind().scalar(sa.text("SELECT COUNT(*) FROM student_baselines WHERE bi_source_record_id IS NOT NULL"))
    if count:
        raise RuntimeError("Confirmed BI references exist; disable the flag and retain the additive schema.")
    guards = _suspend_sqlite_guards()
    with op.batch_alter_table("student_baselines") as batch:
        batch.drop_constraint("fk_student_baseline_bi_owner", type_="foreignkey")
        batch.drop_constraint("uq_student_baseline_bi_reference", type_="unique")
        batch.drop_column("bi_source_record_id")
    _restore_guards(guards)
