"""User location fields for Nearby (premium)."""

from __future__ import annotations

revision = "q4r5s6t7u8v9"
down_revision = "p3q4r5s6t7u8"
branch_labels = None
depends_on = None

import sqlalchemy as sa
from alembic import op


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("location_lat", sa.Numeric(10, 7), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("location_lng", sa.Numeric(10, 7), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("location_updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "location_sharing_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index("ix_users_location_sharing", "users", ["location_sharing_enabled"])
    op.create_index("ix_users_location_updated_at", "users", ["location_updated_at"])


def downgrade() -> None:
    op.drop_index("ix_users_location_updated_at", table_name="users")
    op.drop_index("ix_users_location_sharing", table_name="users")
    op.drop_column("users", "location_sharing_enabled")
    op.drop_column("users", "location_updated_at")
    op.drop_column("users", "location_lng")
    op.drop_column("users", "location_lat")
