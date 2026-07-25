"""Trust score counters on business profiles."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e2f3a4b5c6d7"
down_revision = "d1e2f3a4b5c6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column(
            "successful_deals",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "complaints_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "business_profiles",
        sa.Column(
            "documents_verified",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "documents_verified")
    op.drop_column("business_profiles", "complaints_count")
    op.drop_column("business_profiles", "successful_deals")
