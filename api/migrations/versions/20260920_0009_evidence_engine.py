"""add classroom evidence engine

Revision ID: 20260920_0009
Revises: 20260920_0008
"""
from alembic import op
import sqlalchemy as sa

revision = "20260920_0009"
down_revision = "20260920_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table("class_sessions",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False), sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="open"), sa.Column("opened_by", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("closed_by", sa.String(36), sa.ForeignKey("users.id")), sa.Column("checkin_token_digest", sa.String(64), nullable=False),
        sa.Column("token_expires_at", sa.DateTime(timezone=True), nullable=False), sa.Column("token_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False))
    op.create_table("evidence_imports",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("source_type", sa.String(32), nullable=False), sa.Column("status", sa.String(24), nullable=False, server_default="pending_review"),
        sa.Column("imported_by", sa.String(36), sa.ForeignKey("users.id"), nullable=False), sa.Column("retention_until", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source_digest", sa.String(128), nullable=False), sa.Column("idempotency_key", sa.String(180), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False), sa.UniqueConstraint("class_id", "source_digest", name="uq_evidence_import_digest"))
    op.create_table("evidence_items",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("import_id", sa.String(36), sa.ForeignKey("evidence_imports.id")),
        sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id"), nullable=False), sa.Column("session_id", sa.String(36), sa.ForeignKey("class_sessions.id")),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id")), sa.Column("evidence_type", sa.String(48), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False), sa.Column("confidence_basis_points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("review_status", sa.String(24), nullable=False, server_default="pending"), sa.Column("object_reference", sa.String(500)),
        sa.Column("item_digest", sa.String(128), nullable=False, unique=True), sa.Column("metadata_json", sa.JSON(), nullable=False))
    op.create_table("class_checkins",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("session_id", sa.String(36), sa.ForeignKey("class_sessions.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False), sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False), sa.Column("method", sa.String(16), nullable=False),
        sa.Column("evidence_id", sa.String(36), sa.ForeignKey("evidence_items.id"), nullable=False), sa.Column("idempotency_key", sa.String(180), nullable=False, unique=True),
        sa.UniqueConstraint("session_id", "user_id", "kind", name="uq_checkin_session_user_kind"))
    op.create_table("review_decisions",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("evidence_id", sa.String(36), sa.ForeignKey("evidence_items.id"), nullable=False),
        sa.Column("decision", sa.String(16), nullable=False), sa.Column("reason_code", sa.String(48), nullable=False),
        sa.Column("decided_by", sa.String(36), sa.ForeignKey("users.id"), nullable=False), sa.Column("decided_at", sa.DateTime(timezone=True), nullable=False))
    op.create_table("session_reports",
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("class_id", sa.String(36), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("session_id", sa.String(36), sa.ForeignKey("class_sessions.id"), nullable=False, unique=True), sa.Column("generated_by", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False), sa.Column("report_digest", sa.String(64), nullable=False, unique=True), sa.Column("summary", sa.JSON(), nullable=False))


def downgrade() -> None:
    op.drop_table("session_reports")
    op.drop_table("review_decisions")
    op.drop_table("class_checkins")
    op.drop_table("evidence_items")
    op.drop_table("evidence_imports")
    op.drop_table("class_sessions")
