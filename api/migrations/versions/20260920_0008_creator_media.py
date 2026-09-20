"""add creator media, score and simulated ledger

Revision ID: 20260920_0008
Revises: 20260920_0007
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0008"
down_revision = "20260920_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "media_assets",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("institution_id", sa.String(36), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("program_id", sa.String(36), sa.ForeignKey("programs.id"), nullable=False),
        sa.Column("course_id", sa.String(120), sa.ForeignKey("courses.id"), nullable=False),
        sa.Column("module_id", sa.String(120), nullable=False),
        sa.Column("creator_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(240), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("competency_id", sa.String(120), nullable=False),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("provider_asset_id", sa.String(500), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("thumbnail_url", sa.String(500)),
        sa.Column("captions", sa.JSON(), nullable=False),
        sa.Column("visibility", sa.String(24), nullable=False, server_default="enrolled"),
        sa.Column("offline_policy", sa.String(24), nullable=False, server_default="forbidden"),
        sa.Column("status", sa.String(24), nullable=False, server_default="draft"),
        sa.Column("master_drive_file_id", sa.String(240)),
        sa.Column("rights_confirmed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("followup_activity_id", sa.String(120), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("published_by", sa.String(36), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("provider", "provider_asset_id", name="uq_media_provider_asset"),
    )
    op.create_table(
        "media_events",
        sa.Column("event_id", sa.String(180), primary_key=True),
        sa.Column("media_id", sa.String(36), sa.ForeignKey("media_assets.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), sa.ForeignKey("enrollments.id"), nullable=False),
        sa.Column("course_id", sa.String(120), nullable=False),
        sa.Column("module_id", sa.String(120), nullable=False),
        sa.Column("session_id", sa.String(160), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("checkpoint_percent", sa.Integer()),
        sa.Column("position_seconds", sa.Integer()),
        sa.Column("qualified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_media_events_media_occurred", "media_events", ["media_id", "occurred_at"])
    op.create_table(
        "creator_scores",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("institution_id", sa.String(36), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("program_id", sa.String(36), sa.ForeignKey("programs.id"), nullable=False),
        sa.Column("creator_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("media_id", sa.String(36), sa.ForeignKey("media_assets.id"), nullable=False),
        sa.Column("rule_version", sa.String(64), nullable=False),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("window_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("score_basis_points", sa.Integer(), nullable=False),
        sa.Column("calculation_snapshot", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("creator_user_id", "media_id", "rule_version", "window_start", "window_end", name="uq_creator_score_window"),
    )
    op.create_table(
        "revenue_ledger",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("creator_score_id", sa.String(36), sa.ForeignKey("creator_scores.id"), nullable=False),
        sa.Column("institution_id", sa.String(36), sa.ForeignKey("institutions.id"), nullable=False),
        sa.Column("program_id", sa.String(36), sa.ForeignKey("programs.id"), nullable=False),
        sa.Column("creator_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("media_id", sa.String(36), sa.ForeignKey("media_assets.id"), nullable=False),
        sa.Column("source_event_id", sa.String(180), sa.ForeignKey("media_events.event_id"), nullable=False),
        sa.Column("rule_version", sa.String(64), nullable=False),
        sa.Column("entry_type", sa.String(24), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("status", sa.String(24), nullable=False, server_default="simulated"),
        sa.Column("idempotency_key", sa.String(180), nullable=False, unique=True),
        sa.Column("calculation_snapshot", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("approved_by", sa.String(36), sa.ForeignKey("users.id")),
        sa.Column("approved_at", sa.DateTime(timezone=True)),
        sa.Column("external_reference", sa.String(240)),
        sa.UniqueConstraint("source_event_id", "rule_version", "entry_type", name="uq_ledger_semantic_origin"),
    )


def downgrade() -> None:
    op.drop_table("revenue_ledger")
    op.drop_table("creator_scores")
    op.drop_index("ix_media_events_media_occurred", table_name="media_events")
    op.drop_table("media_events")
    op.drop_table("media_assets")
