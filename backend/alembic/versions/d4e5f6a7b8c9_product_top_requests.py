"""Product top promotion requests.

Revision ID: d4e5f6a7b8c9
Revises: c3d4e5f6a7b8
Create Date: 2026-07-23
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "d4e5f6a7b8c9"
down_revision = "c3d4e5f6a7b8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "product_top_requests",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("product_id", sa.BigInteger(), nullable=False),
        sa.Column("seller_id", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("note", sa.String(length=300), nullable=False, server_default=""),
        sa.Column("admin_note", sa.String(length=300), nullable=False, server_default=""),
        sa.Column("reviewed_by", sa.Integer(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.ForeignKeyConstraint(["product_id"], ["products.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["seller_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_product_top_requests_product_id", "product_top_requests", ["product_id"])
    op.create_index("ix_product_top_requests_seller_id", "product_top_requests", ["seller_id"])
    op.create_index("ix_product_top_requests_status", "product_top_requests", ["status"])
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_product_top_request_pending
        ON product_top_requests (product_id)
        WHERE status = 'pending'
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_product_top_request_pending")
    op.drop_index("ix_product_top_requests_status", table_name="product_top_requests")
    op.drop_index("ix_product_top_requests_seller_id", table_name="product_top_requests")
    op.drop_index("ix_product_top_requests_product_id", table_name="product_top_requests")
    op.drop_table("product_top_requests")
