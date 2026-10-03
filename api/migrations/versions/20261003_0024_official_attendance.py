"""Append-only official attendance corrections and explicit makeup decisions."""
from alembic import op
import sqlalchemy as sa

revision = "20261003_0024"
down_revision = "20261003_0023"
branch_labels = None
depends_on = None

FIELDS = ('id', 'original_session_id', 'makeup_session_id', 'class_id', 'user_id',
          'enrollment_id', 'program_id', 'course_id', 'revision', 'status', 'reason',
          'decided_at', 'idempotency_key')


def upgrade():
    op.create_table('official_attendance_decisions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('original_session_id', sa.String(36), nullable=False),
        sa.Column('makeup_session_id', sa.String(36)),
        sa.Column('class_id', sa.String(36), nullable=False),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('enrollment_id', sa.String(36), nullable=False),
        sa.Column('program_id', sa.String(36), nullable=False),
        sa.Column('course_id', sa.String(120), nullable=False),
        sa.Column('revision', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(24), nullable=False),
        sa.Column('reason', sa.String(500), nullable=False),
        sa.Column('actor_user_id', sa.String(36), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('decided_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('idempotency_key', sa.String(180), nullable=False, unique=True),
        sa.UniqueConstraint('original_session_id', 'user_id', 'revision', name='uq_official_attendance_revision'),
        sa.ForeignKeyConstraint(['original_session_id', 'class_id'], ['class_sessions.id', 'class_sessions.class_id']),
        sa.ForeignKeyConstraint(['makeup_session_id', 'class_id'], ['class_sessions.id', 'class_sessions.class_id']),
        sa.ForeignKeyConstraint(['class_id', 'program_id', 'course_id'], ['classes.id', 'classes.program_id', 'classes.course_id']),
        sa.ForeignKeyConstraint(['enrollment_id', 'user_id', 'program_id', 'course_id'], ['enrollments.id', 'enrollments.user_id', 'enrollments.program_id', 'enrollments.course_id'], ondelete='CASCADE'),
        sa.CheckConstraint("status IN ('VALID', 'ABSENT', 'JUSTIFIED_ABSENCE', 'PENDING_MAKEUP')"),
        sa.CheckConstraint('revision >= 1'),
        sa.CheckConstraint('length(trim(reason)) BETWEEN 3 AND 500'),
        sa.CheckConstraint('makeup_session_id IS NULL OR makeup_session_id != original_session_id'),
        sa.CheckConstraint("status != 'PENDING_MAKEUP' OR makeup_session_id IS NOT NULL"))
    dialect = op.get_bind().dialect.name
    compare = 'IS DISTINCT FROM' if dialect == 'postgresql' else 'IS NOT'
    immutable = ' OR '.join(f'NEW.{field} {compare} OLD.{field}' for field in FIELDS)
    immutable += ' OR NEW.actor_user_id IS NOT NULL'
    owned = 'EXISTS (SELECT 1 FROM users WHERE id = OLD.user_id) AND EXISTS (SELECT 1 FROM enrollments WHERE id = OLD.enrollment_id)'
    if dialect == 'postgresql':
        op.execute(f"CREATE FUNCTION guard_official_attendance() RETURNS trigger AS $$ BEGIN IF TG_OP = 'DELETE' THEN IF {owned} THEN RAISE EXCEPTION 'official attendance requires owner erasure'; END IF; RETURN OLD; END IF; IF {immutable} THEN RAISE EXCEPTION 'immutable official attendance'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql")
        op.execute('CREATE TRIGGER official_attendance_immutable BEFORE UPDATE OR DELETE ON official_attendance_decisions FOR EACH ROW EXECUTE FUNCTION guard_official_attendance()')
    elif dialect == 'sqlite':
        op.execute(f"CREATE TRIGGER official_attendance_immutable BEFORE UPDATE ON official_attendance_decisions WHEN {immutable} BEGIN SELECT RAISE(ABORT, 'immutable official attendance'); END")
        op.execute(f"CREATE TRIGGER official_attendance_no_delete BEFORE DELETE ON official_attendance_decisions WHEN {owned} BEGIN SELECT RAISE(ABORT, 'official attendance requires owner erasure'); END")


def downgrade():
    if op.get_bind().execute(sa.text('SELECT count(*) FROM official_attendance_decisions')).scalar():
        raise RuntimeError('Preserve official attendance history: forward recover.')
    op.drop_table('official_attendance_decisions')
    if op.get_bind().dialect.name == 'postgresql':
        op.execute('DROP FUNCTION IF EXISTS guard_official_attendance()')
