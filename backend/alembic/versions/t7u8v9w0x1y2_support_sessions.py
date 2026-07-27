"""Add support_sessions and support_messages for Sofiya chat persistence."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "t7u8v9w0x1y2_support_sessions"
down_revision = "s6t7u8v9w0x1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "support_sessions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=16), server_default="active", nullable=False),
        sa.Column("locale", sa.String(length=16), server_default="uz", nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("preview", sa.String(length=240), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_support_sessions_user_id", "support_sessions", ["user_id"])
    op.create_index("ix_support_sessions_status", "support_sessions", ["status"])
    op.create_index(
        "ix_support_sessions_user_status",
        "support_sessions",
        ["user_id", "status"],
    )

    op.create_table(
        "support_messages",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("session_id", sa.BigInteger(), nullable=False),
        sa.Column("role", sa.String(length=16), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["session_id"], ["support_sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_support_messages_session_id", "support_messages", ["session_id"])


def downgrade() -> None:
    op.drop_index("ix_support_messages_session_id", table_name="support_messages")
    op.drop_table("support_messages")
    op.drop_index("ix_support_sessions_user_status", table_name="support_sessions")
    op.drop_index("ix_support_sessions_status", table_name="support_sessions")
    op.drop_index("ix_support_sessions_user_id", table_name="support_sessions")
    op.drop_table("support_sessions")
