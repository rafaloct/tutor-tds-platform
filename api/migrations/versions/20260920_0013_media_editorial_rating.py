"""add media editorial audit and explicit ratings

Revision ID: 20260920_0013
Revises: 20260920_0012
"""

from alembic import op
import sqlalchemy as sa

revision = "20260920_0013"
down_revision = "20260920_0012"
branch_labels = None
depends_on = None

MEDIA_STATUSES = "'draft', 'processing', 'published', 'blocked', 'archived'"


def upgrade() -> None:
    op.create_table(
        "media_status_transitions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "media_id",
            sa.String(36),
            sa.ForeignKey("media_assets.id"),
            nullable=False,
        ),
        sa.Column("from_status", sa.String(24)),
        sa.Column("to_status", sa.String(24), nullable=False),
        sa.Column(
            "actor_user_id",
            sa.String(36),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("actor_role", sa.String(32), nullable=False),
        sa.Column("reason", sa.Text()),
        sa.Column(
            "occurred_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            f"from_status IS NULL OR from_status IN ({MEDIA_STATUSES})",
            name="ck_media_transition_from_status",
        ),
        sa.CheckConstraint(
            f"to_status IN ({MEDIA_STATUSES})",
            name="ck_media_transition_to_status",
        ),
    )
    op.create_index(
        "ix_media_status_transitions_media_occurred",
        "media_status_transitions",
        ["media_id", "occurred_at"],
    )
    op.create_table(
        "media_ratings",
        sa.Column(
            "media_id",
            sa.String(36),
            sa.ForeignKey("media_assets.id"),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id"),
            primary_key=True,
        ),
        sa.Column(
            "enrollment_id",
            sa.String(36),
            sa.ForeignKey("enrollments.id"),
            nullable=False,
        ),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column(
            "submitted_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("rating BETWEEN 1 AND 5", name="ck_media_rating_range"),
    )
    op.create_index(
        "ix_media_ratings_media_updated",
        "media_ratings",
        ["media_id", "updated_at"],
    )
    op.create_table(
        "media_playback_grants",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("token_digest", sa.String(64), nullable=False, unique=True),
        sa.Column(
            "media_id",
            sa.String(36),
            sa.ForeignKey("media_assets.id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_media_playback_grants_expires",
        "media_playback_grants",
        ["expires_at"],
    )
    op.execute(
        """
        INSERT INTO media_status_transitions
            (id, media_id, from_status, to_status, actor_user_id, actor_role,
             reason, occurred_at)
        SELECT id, id, NULL, status, COALESCE(published_by, creator_user_id),
               'migration', 'Estado editorial existente importado na trilha.',
               COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)
        FROM media_assets
        """
    )
    _create_append_only_guards()


def downgrade() -> None:
    _drop_append_only_guards()
    op.drop_index(
        "ix_media_playback_grants_expires",
        table_name="media_playback_grants",
    )
    op.drop_table("media_playback_grants")
    op.drop_index("ix_media_ratings_media_updated", table_name="media_ratings")
    op.drop_table("media_ratings")
    op.drop_index(
        "ix_media_status_transitions_media_occurred",
        table_name="media_status_transitions",
    )
    op.drop_table("media_status_transitions")


def _create_append_only_guards() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            """
            CREATE FUNCTION reject_media_status_transition_mutation()
            RETURNS trigger AS $$
            BEGIN
                RAISE EXCEPTION 'media status transition history is append-only';
            END;
            $$ LANGUAGE plpgsql
            """
        )
        op.execute(
            """
            CREATE TRIGGER media_status_transitions_append_only
            BEFORE UPDATE OR DELETE ON media_status_transitions
            FOR EACH ROW EXECUTE FUNCTION reject_media_status_transition_mutation()
            """
        )
    elif dialect == "sqlite":
        op.execute(
            """
            CREATE TRIGGER media_status_transitions_no_update
            BEFORE UPDATE ON media_status_transitions
            BEGIN
                SELECT RAISE(ABORT, 'media status transition history is append-only');
            END
            """
        )
        op.execute(
            """
            CREATE TRIGGER media_status_transitions_no_delete
            BEFORE DELETE ON media_status_transitions
            BEGIN
                SELECT RAISE(ABORT, 'media status transition history is append-only');
            END
            """
        )


def _drop_append_only_guards() -> None:
    dialect = op.get_bind().dialect.name
    if dialect == "postgresql":
        op.execute(
            "DROP TRIGGER IF EXISTS media_status_transitions_append_only "
            "ON media_status_transitions"
        )
        op.execute("DROP FUNCTION IF EXISTS reject_media_status_transition_mutation()")
    elif dialect == "sqlite":
        op.execute("DROP TRIGGER IF EXISTS media_status_transitions_no_update")
        op.execute("DROP TRIGGER IF EXISTS media_status_transitions_no_delete")
