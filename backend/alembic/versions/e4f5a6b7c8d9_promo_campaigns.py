"""Promo campaign fields: A/B, segment, geo/lang, referral, pause."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "e4f5a6b7c8d9"
down_revision = "d3e4f5a6b7c8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "promo_codes",
        sa.Column("campaign_key", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "promo_codes",
        sa.Column("variant", sa.String(length=8), nullable=True),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "code_type",
            sa.String(length=32),
            server_default="standard",
            nullable=False,
        ),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "segment",
            sa.String(length=32),
            server_default="all",
            nullable=False,
        ),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "new_user_max_age_days",
            sa.Integer(),
            server_default="7",
            nullable=False,
        ),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "allowed_countries",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "allowed_languages",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.add_column(
        "promo_codes",
        sa.Column("influencer_label", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "promo_codes",
        sa.Column(
            "is_paused",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.create_index("ix_promo_codes_campaign_key", "promo_codes", ["campaign_key"])
    op.create_index("ix_promo_codes_code_type", "promo_codes", ["code_type"])


def downgrade() -> None:
    op.drop_index("ix_promo_codes_code_type", table_name="promo_codes")
    op.drop_index("ix_promo_codes_campaign_key", table_name="promo_codes")
    op.drop_column("promo_codes", "is_paused")
    op.drop_column("promo_codes", "influencer_label")
    op.drop_column("promo_codes", "allowed_languages")
    op.drop_column("promo_codes", "allowed_countries")
    op.drop_column("promo_codes", "new_user_max_age_days")
    op.drop_column("promo_codes", "segment")
    op.drop_column("promo_codes", "code_type")
    op.drop_column("promo_codes", "variant")
    op.drop_column("promo_codes", "campaign_key")
