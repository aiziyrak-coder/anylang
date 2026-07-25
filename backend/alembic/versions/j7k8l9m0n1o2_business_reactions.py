"""Widen message_reactions.emoji for business reaction tokens."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "j7k8l9m0n1o2"
down_revision = "i6j7k8l9m0n1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "message_reactions",
        "emoji",
        existing_type=sa.String(length=8),
        type_=sa.String(length=32),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "message_reactions",
        "emoji",
        existing_type=sa.String(length=32),
        type_=sa.String(length=8),
        existing_nullable=False,
    )
