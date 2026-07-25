"""Add verified_only flag for Verified Groups."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "m0n1o2p3q4r5"
down_revision = "l9m0n1o2p3q4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chats",
        sa.Column(
            "verified_only",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("chats", "verified_only")
