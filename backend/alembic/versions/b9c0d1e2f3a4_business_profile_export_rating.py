"""Business profile: export countries, rating, reviews."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "b9c0d1e2f3a4"
down_revision = "c8d9e0f1a2b3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column(
            "export_countries",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column("rating", sa.Numeric(3, 2), nullable=True),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "reviews_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "reviews_count")
    op.drop_column("business_profiles", "rating")
    op.drop_column("business_profiles", "export_countries")
