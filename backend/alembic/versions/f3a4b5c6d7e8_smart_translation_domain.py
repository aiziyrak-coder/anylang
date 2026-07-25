"""Smart translation domains on users."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f3a4b5c6d7e8"
down_revision = "e2f3a4b5c6d7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "translation_domain",
            sa.String(length=32),
            nullable=False,
            server_default="general",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "translation_domain")
