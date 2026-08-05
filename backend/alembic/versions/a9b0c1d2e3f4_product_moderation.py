"""Product moderation: pending/rejected + rejection note.

Revision ID: a9b0c1d2e3f4
Revises: x2y3z4a5b6c7, y2z3a4b5c6d7_chat_muted_until
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "a9b0c1d2e3f4"
down_revision = ("x2y3z4a5b6c7", "y2z3a4b5c6d7_chat_muted_until")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column("moderation_note", sa.String(length=500), nullable=False, server_default=""),
    )
    op.add_column(
        "products",
        sa.Column("moderated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("moderated_by", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("products", "moderated_by")
    op.drop_column("products", "moderated_at")
    op.drop_column("products", "moderation_note")
