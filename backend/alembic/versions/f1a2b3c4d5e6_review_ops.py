"""Business reviews: sentiment/toxic, fake IP, hide, company reply.

Revision ID: f1a2b3c4d5e6
Revises: f0a1b2c3d4e5
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "f1a2b3c4d5e6"
down_revision = "f0a1b2c3d4e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_reviews",
        sa.Column("client_ip", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "business_reviews",
        sa.Column(
            "ai_flags",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "business_reviews",
        sa.Column(
            "fake_flag",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.add_column(
        "business_reviews",
        sa.Column(
            "fake_signals",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "business_reviews",
        sa.Column("hidden_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "business_reviews",
        sa.Column("hidden_by", sa.Integer(), nullable=True),
    )
    op.add_column(
        "business_reviews",
        sa.Column(
            "hidden_reason",
            sa.String(length=500),
            server_default="",
            nullable=False,
        ),
    )
    op.add_column(
        "business_reviews",
        sa.Column(
            "company_reply",
            sa.String(length=1000),
            server_default="",
            nullable=False,
        ),
    )
    op.add_column(
        "business_reviews",
        sa.Column("company_replied_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_business_reviews_client_ip", "business_reviews", ["client_ip"])
    op.create_index("ix_business_reviews_fake_flag", "business_reviews", ["fake_flag"])
    op.create_index("ix_business_reviews_hidden_at", "business_reviews", ["hidden_at"])


def downgrade() -> None:
    op.drop_index("ix_business_reviews_hidden_at", table_name="business_reviews")
    op.drop_index("ix_business_reviews_fake_flag", table_name="business_reviews")
    op.drop_index("ix_business_reviews_client_ip", table_name="business_reviews")
    op.drop_column("business_reviews", "company_replied_at")
    op.drop_column("business_reviews", "company_reply")
    op.drop_column("business_reviews", "hidden_reason")
    op.drop_column("business_reviews", "hidden_by")
    op.drop_column("business_reviews", "hidden_at")
    op.drop_column("business_reviews", "fake_signals")
    op.drop_column("business_reviews", "fake_flag")
    op.drop_column("business_reviews", "ai_flags")
    op.drop_column("business_reviews", "client_ip")
