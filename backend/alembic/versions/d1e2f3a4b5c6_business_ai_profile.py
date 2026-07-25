"""Business AI profile fields: SEO, keywords, multi-language descriptions."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "d1e2f3a4b5c6"
down_revision = "c0d1e2f3a4b5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column("seo_text", sa.Text(), nullable=True),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "keywords",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "description_i18n",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "description_i18n")
    op.drop_column("business_profiles", "keywords")
    op.drop_column("business_profiles", "seo_text")
