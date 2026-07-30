"""business_profiles.ai_knowledge for AnyTrade AI

Revision ID: b4c5d6e7f8a9
Revises: z3a4b5c6d7e8
Create Date: 2026-07-30
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "b4c5d6e7f8a9"
down_revision: Union[str, Sequence[str], None] = "z3a4b5c6d7e8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column("ai_knowledge", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "ai_knowledge")
