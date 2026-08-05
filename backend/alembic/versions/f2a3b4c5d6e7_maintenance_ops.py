"""Maintenance ops: feature flags, error events.

Revision ID: f2a3b4c5d6e7
Revises: f1a2b3c4d5e6
Create Date: 2026-08-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "f2a3b4c5d6e7"
down_revision = "f1a2b3c4d5e6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "system_feature_flags",
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column(
            "value",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column("updated_by", sa.Integer(), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("key"),
    )

    op.create_table(
        "system_error_events",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("fingerprint", sa.String(length=64), nullable=False),
        sa.Column("level", sa.String(length=16), server_default="error", nullable=False),
        sa.Column("error_code", sa.String(length=64), server_default="", nullable=False),
        sa.Column("message", sa.String(length=500), server_default="", nullable=False),
        sa.Column("path", sa.String(length=255), server_default="", nullable=False),
        sa.Column("method", sa.String(length=16), server_default="", nullable=False),
        sa.Column("status_code", sa.Integer(), nullable=True),
        sa.Column(
            "meta",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_system_error_events_created_at", "system_error_events", ["created_at"]
    )
    op.create_index(
        "ix_system_error_events_fingerprint",
        "system_error_events",
        ["fingerprint"],
    )
    op.create_index(
        "ix_system_error_events_error_code",
        "system_error_events",
        ["error_code"],
    )


def downgrade() -> None:
    op.drop_index("ix_system_error_events_error_code", table_name="system_error_events")
    op.drop_index("ix_system_error_events_fingerprint", table_name="system_error_events")
    op.drop_index("ix_system_error_events_created_at", table_name="system_error_events")
    op.drop_table("system_error_events")
    op.drop_table("system_feature_flags")
