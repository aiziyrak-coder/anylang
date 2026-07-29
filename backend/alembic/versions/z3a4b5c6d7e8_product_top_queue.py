"""product top queue: paid $30/week, clear pins, queue columns

Revision ID: z3a4b5c6d7e8
Revises: y2z3a4b5c6d7
Create Date: 2026-07-29
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "z3a4b5c6d7e8"
down_revision: Union[str, Sequence[str], None] = "y2z3a4b5c6d7_chat_muted_until"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Barcha joriy Top pinlarni tozalash.
    op.execute(
        "UPDATE products SET is_top_pinned = false, top_pinned_until = NULL "
        "WHERE is_top_pinned = true"
    )
    # Eski bepul/admin so'rovlarni yopish.
    op.execute(
        "UPDATE product_top_requests SET status = 'cancelled' "
        "WHERE status IN ('pending', 'approved')"
    )

    op.add_column(
        "product_top_requests",
        sa.Column("payment_id", sa.BigInteger(), nullable=True),
    )
    op.add_column(
        "product_top_requests",
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "product_top_requests",
        sa.Column("activated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "product_top_requests",
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.execute("DROP INDEX IF EXISTS uq_product_top_request_pending")
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_product_top_request_open
        ON product_top_requests (product_id)
        WHERE status IN ('queued', 'active', 'pending')
        """
    )
    op.create_index(
        "ix_product_top_requests_payment_id",
        "product_top_requests",
        ["payment_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_product_top_requests_payment_id", table_name="product_top_requests")
    op.execute("DROP INDEX IF EXISTS uq_product_top_request_open")
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_product_top_request_pending
        ON product_top_requests (product_id)
        WHERE status = 'pending'
        """
    )
    op.drop_column("product_top_requests", "expires_at")
    op.drop_column("product_top_requests", "activated_at")
    op.drop_column("product_top_requests", "paid_at")
    op.drop_column("product_top_requests", "payment_id")
