"""Add Click/Paddle payment fields on payments.

Revision ID: r5s6t7u8v9w0
Revises: q4r5s6t7u8v9
"""

from __future__ import annotations

revision = "r5s6t7u8v9w0"
down_revision = "q4r5s6t7u8v9"
branch_labels = None
depends_on = None

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


def upgrade() -> None:
    op.add_column(
        "payments",
        sa.Column("provider_transaction_id", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column(
            "raw_payload",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.create_index(
        "ix_payments_provider_transaction_id",
        "payments",
        ["provider_transaction_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_payments_provider_transaction_id", table_name="payments")
    op.drop_column("payments", "raw_payload")
    op.drop_column("payments", "provider_transaction_id")
