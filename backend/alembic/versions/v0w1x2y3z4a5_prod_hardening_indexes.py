"""Production hardening indexes and alembic_version widen.

Revision ID: v0w1x2y3z4a5
Revises: u9v0w1x2y3z4
Create Date: 2026-08-04
"""

from __future__ import annotations

from alembic import op

revision = "v0w1x2y3z4a5"
down_revision = "u9v0w1x2y3z4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE alembic_version
        ALTER COLUMN version_num TYPE VARCHAR(128)
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_products_published_category_created
        ON products (category, created_at DESC)
        WHERE status = 'published'
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_friendships_user_pair
        ON friendships (user_low_id, user_high_id)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_friendships_user_pair")
    op.execute("DROP INDEX IF EXISTS ix_products_published_category_created")
    op.execute(
        """
        ALTER TABLE alembic_version
        ALTER COLUMN version_num TYPE VARCHAR(32)
        """
    )
