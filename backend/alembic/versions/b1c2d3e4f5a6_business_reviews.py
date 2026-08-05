"""Business company reviews with admin moderation.

Revision ID: b1c2d3e4f5a6
Revises: a9b0c1d2e3f4
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "b1c2d3e4f5a6"
down_revision = "a9b0c1d2e3f4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "business_reviews",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("business_user_id", sa.BigInteger(), nullable=False),
        sa.Column("author_id", sa.BigInteger(), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("text", sa.String(length=1000), server_default="", nullable=False),
        sa.Column("status", sa.String(length=16), server_default="pending", nullable=False),
        sa.Column("moderation_note", sa.String(length=500), server_default="", nullable=False),
        sa.Column("moderated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("moderated_by", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["author_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["business_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "business_user_id",
            "author_id",
            name="uq_business_review_author",
        ),
    )
    op.create_index("ix_business_reviews_business_user_id", "business_reviews", ["business_user_id"])
    op.create_index("ix_business_reviews_author_id", "business_reviews", ["author_id"])
    op.create_index("ix_business_reviews_status", "business_reviews", ["status"])


def downgrade() -> None:
    op.drop_index("ix_business_reviews_status", table_name="business_reviews")
    op.drop_index("ix_business_reviews_author_id", table_name="business_reviews")
    op.drop_index("ix_business_reviews_business_user_id", table_name="business_reviews")
    op.drop_table("business_reviews")
