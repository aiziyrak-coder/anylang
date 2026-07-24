"""Chat groups, participants, pin support.

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-07-23
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e5f6a7b8c9d0"
down_revision = "d4e5f6a7b8c9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chats",
        sa.Column("type", sa.String(length=16), server_default="direct", nullable=False),
    )
    op.add_column("chats", sa.Column("title", sa.String(length=120), nullable=True))
    op.add_column("chats", sa.Column("avatar_url", sa.String(length=512), nullable=True))
    op.add_column("chats", sa.Column("created_by", sa.BigInteger(), nullable=True))
    op.create_index("ix_chats_type", "chats", ["type"])

    # Drop pair uniqueness — groups have no pair; direct keeps partial unique.
    op.drop_constraint("uq_chat_pair", "chats", type_="unique")
    op.alter_column("chats", "user_low_id", existing_type=sa.BigInteger(), nullable=True)
    op.alter_column("chats", "user_high_id", existing_type=sa.BigInteger(), nullable=True)
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_direct_pair
        ON chats (user_low_id, user_high_id)
        WHERE type = 'direct' AND user_low_id IS NOT NULL AND user_high_id IS NOT NULL
        """
    )

    op.create_table(
        "chat_participants",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("role", sa.String(length=16), server_default="member", nullable=False),
        sa.Column("pinned_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("muted", sa.Boolean(), server_default=sa.text("false"), nullable=False),
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
        sa.ForeignKeyConstraint(["chat_id"], ["chats.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("chat_id", "user_id", name="uq_chat_participant"),
    )
    op.create_index("ix_chat_participants_chat_id", "chat_participants", ["chat_id"])
    op.create_index("ix_chat_participants_user_id", "chat_participants", ["user_id"])
    op.create_index("ix_chat_participants_pinned_at", "chat_participants", ["pinned_at"])

    # Backfill DM participants.
    op.execute(
        """
        INSERT INTO chat_participants (chat_id, user_id, role, muted, created_at, updated_at)
        SELECT id, user_low_id, 'member', false, now(), now()
        FROM chats
        WHERE type = 'direct' AND user_low_id IS NOT NULL
        ON CONFLICT DO NOTHING
        """
    )
    op.execute(
        """
        INSERT INTO chat_participants (chat_id, user_id, role, muted, created_at, updated_at)
        SELECT id, user_high_id, 'member', false, now(), now()
        FROM chats
        WHERE type = 'direct' AND user_high_id IS NOT NULL
        ON CONFLICT DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_index("ix_chat_participants_pinned_at", table_name="chat_participants")
    op.drop_index("ix_chat_participants_user_id", table_name="chat_participants")
    op.drop_index("ix_chat_participants_chat_id", table_name="chat_participants")
    op.drop_table("chat_participants")
    op.execute("DROP INDEX IF EXISTS uq_chat_direct_pair")
    op.alter_column("chats", "user_high_id", existing_type=sa.BigInteger(), nullable=False)
    op.alter_column("chats", "user_low_id", existing_type=sa.BigInteger(), nullable=False)
    op.create_unique_constraint("uq_chat_pair", "chats", ["user_low_id", "user_high_id"])
    op.drop_index("ix_chats_type", table_name="chats")
    op.drop_column("chats", "created_by")
    op.drop_column("chats", "avatar_url")
    op.drop_column("chats", "title")
    op.drop_column("chats", "type")
