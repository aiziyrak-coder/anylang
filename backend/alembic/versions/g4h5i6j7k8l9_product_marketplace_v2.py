"""Marketplace 2.0 product media + trade fields."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "g4h5i6j7k8l9"
down_revision = "f3a4b5c6d7e8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column("video_url", sa.String(length=512), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("factory_video_url", sa.String(length=512), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("process_video_url", sa.String(length=512), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("moq", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("shipping_info", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column(
            "shipping_countries",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("products", "shipping_countries")
    op.drop_column("products", "shipping_info")
    op.drop_column("products", "moq")
    op.drop_column("products", "process_video_url")
    op.drop_column("products", "factory_video_url")
    op.drop_column("products", "video_url")
