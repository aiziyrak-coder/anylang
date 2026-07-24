"""Chat Telegram features: reactions, pins, edited_at, group invite/super."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f6a7b8c9d0e1"
down_revision = "e5f6a7b8c9d0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("chats", sa.Column("invite_token", sa.String(length=64), nullable=True))
    op.add_column(
        "chats",
        sa.Column("invite_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.add_column(
        "chats",
        sa.Column("is_super", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("chats", sa.Column("member_limit", sa.Integer(), nullable=True))
    op.add_column("chats", sa.Column("super_payment_id", sa.BigInteger(), nullable=True))
    op.create_index("ix_chats_invite_token", "chats", ["invite_token"], unique=True)
    op.execute("UPDATE chats SET member_limit = 100 WHERE type = 'group' AND member_limit IS NULL")

    op.add_column("messages", sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "message_reactions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("message_id", sa.BigInteger(), nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("emoji", sa.String(length=8), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("message_id", "user_id", name="uq_msg_reaction_user"),
    )
    op.create_index("ix_message_reactions_message_id", "message_reactions", ["message_id"])
    op.create_index("ix_message_reactions_user_id", "message_reactions", ["user_id"])

    op.create_table(
        "message_pins",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("message_id", sa.BigInteger(), nullable=False),
        sa.Column("pinned_by", sa.BigInteger(), nullable=False),
        sa.Column("pinned_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["chat_id"], ["chats.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["message_id"], ["messages.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("chat_id", "message_id", name="uq_chat_msg_pin"),
    )
    op.create_index("ix_message_pins_chat_id", "message_pins", ["chat_id"])
    op.create_index("ix_message_pins_message_id", "message_pins", ["message_id"])


def downgrade() -> None:
    op.drop_index("ix_message_pins_message_id", table_name="message_pins")
    op.drop_index("ix_message_pins_chat_id", table_name="message_pins")
    op.drop_table("message_pins")
    op.drop_index("ix_message_reactions_user_id", table_name="message_reactions")
    op.drop_index("ix_message_reactions_message_id", table_name="message_reactions")
    op.drop_table("message_reactions")
    op.drop_column("messages", "edited_at")
    op.drop_index("ix_chats_invite_token", table_name="chats")
    op.drop_column("chats", "super_payment_id")
    op.drop_column("chats", "member_limit")
    op.drop_column("chats", "is_super")
    op.drop_column("chats", "invite_enabled")
    op.drop_column("chats", "invite_token")
