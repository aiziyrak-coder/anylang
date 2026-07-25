"""Business feed posts table."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "i6j7k8l9m0n1"
down_revision = "h5i6j7k8l9m0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "business_feed_posts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("author_id", sa.BigInteger(), nullable=False),
        sa.Column("post_type", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("body", sa.String(length=800), nullable=False, server_default=""),
        sa.Column("image_url", sa.String(length=512), nullable=True),
        sa.Column(
            "meta",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
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
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_business_feed_posts_author_id",
        "business_feed_posts",
        ["author_id"],
    )
    op.create_index(
        "ix_business_feed_posts_post_type",
        "business_feed_posts",
        ["post_type"],
    )
    op.create_index(
        "ix_business_feed_posts_created_at",
        "business_feed_posts",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_business_feed_posts_created_at", table_name="business_feed_posts")
    op.drop_index("ix_business_feed_posts_post_type", table_name="business_feed_posts")
    op.drop_index("ix_business_feed_posts_author_id", table_name="business_feed_posts")
    op.drop_table("business_feed_posts")
