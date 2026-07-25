"""Add marketplace group fields on chats."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "k8l9m0n1o2p3"
down_revision = "j7k8l9m0n1o2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chats",
        sa.Column("marketplace_slug", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "chats",
        sa.Column("marketplace_emoji", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "chats",
        sa.Column("marketplace_blurb", sa.String(length=240), nullable=True),
    )
    op.create_index(
        "ix_chats_marketplace_slug",
        "chats",
        ["marketplace_slug"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_chats_marketplace_slug", table_name="chats")
    op.drop_column("chats", "marketplace_blurb")
    op.drop_column("chats", "marketplace_emoji")
    op.drop_column("chats", "marketplace_slug")
