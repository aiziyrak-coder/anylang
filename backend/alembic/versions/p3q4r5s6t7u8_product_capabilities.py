"""Product capabilities — buyer-facing benefit chips."""

from __future__ import annotations

revision = "p3q4r5s6t7u8"
down_revision = "o2p3q4r5s6t7"
branch_labels = None
depends_on = None

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column(
            "capabilities",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("products", "capabilities")
