"""Product moderation: AI pre-score, SLA, seller listing strikes."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "f0a1b2c3d4e5"
down_revision = "e9f0a1b2c3d4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column(
            "ai_pre_score",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "products",
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_products_submitted_at", "products", ["submitted_at"])

    op.add_column(
        "users",
        sa.Column(
            "product_reject_strikes",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column("listing_restricted_until", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_users_listing_restricted_until",
        "users",
        ["listing_restricted_until"],
    )


def downgrade() -> None:
    op.drop_index("ix_users_listing_restricted_until", table_name="users")
    op.drop_column("users", "listing_restricted_until")
    op.drop_column("users", "product_reject_strikes")
    op.drop_index("ix_products_submitted_at", table_name="products")
    op.drop_column("products", "submitted_at")
    op.drop_column("products", "ai_pre_score")
