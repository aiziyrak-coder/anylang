"""Business trade fields: MOQ, capacity, lead time, incoterms, payments."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c0d1e2f3a4b5"
down_revision = "b9c0d1e2f3a4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column("moq", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "business_profiles",
        sa.Column("production_capacity", sa.String(length=160), nullable=True),
    )
    op.add_column(
        "business_profiles",
        sa.Column("lead_time", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "incoterms",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "payment_methods",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "payment_methods")
    op.drop_column("business_profiles", "incoterms")
    op.drop_column("business_profiles", "lead_time")
    op.drop_column("business_profiles", "production_capacity")
    op.drop_column("business_profiles", "moq")
