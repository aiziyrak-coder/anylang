"""Chat message_count denorm + admin list indexes.

Revision ID: c5d6e7f8a9b0
Revises: b4c5d6e7f8a9
Create Date: 2026-07-30
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "c5d6e7f8a9b0"
down_revision: Union[str, Sequence[str], None] = "b4c5d6e7f8a9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "chats",
        sa.Column("message_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.execute(
        """
        UPDATE chats c
        SET message_count = COALESCE(s.cnt, 0)
        FROM (
            SELECT chat_id, COUNT(*)::int AS cnt
            FROM messages
            GROUP BY chat_id
        ) s
        WHERE c.id = s.chat_id
        """
    )
    op.create_index("ix_chats_message_count", "chats", ["message_count"])
    op.create_index(
        "ix_payments_status_created_at",
        "payments",
        ["status", "created_at"],
    )
    op.create_index(
        "ix_products_status_id",
        "products",
        ["status", "id"],
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_messages_chat_id_id_desc ON messages (chat_id, id DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_messages_chat_id_id_desc")
    op.drop_index("ix_products_status_id", table_name="products")
    op.drop_index("ix_payments_status_created_at", table_name="payments")
    op.drop_index("ix_chats_message_count", table_name="chats")
    op.drop_column("chats", "message_count")
