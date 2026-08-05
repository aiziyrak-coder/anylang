"""Verification docs: per-document review status for partial approve."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c2d3e4f5a6b7"
down_revision = "b1c2d3e4f5a6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_verification_documents",
        sa.Column(
            "review_status",
            sa.String(length=16),
            server_default="pending",
            nullable=False,
        ),
    )
    op.add_column(
        "business_verification_documents",
        sa.Column("review_note", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("business_verification_documents", "review_note")
    op.drop_column("business_verification_documents", "review_status")
