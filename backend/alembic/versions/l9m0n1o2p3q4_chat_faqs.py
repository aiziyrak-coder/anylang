"""Add chat_faqs table for AI FAQ auto-replies."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "l9m0n1o2p3q4"
down_revision = "k8l9m0n1o2p3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_faqs",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("fingerprint", sa.String(length=64), nullable=False),
        sa.Column("question_sample", sa.String(length=400), nullable=False),
        sa.Column("answer", sa.Text(), nullable=True),
        sa.Column("ask_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_question_message_id", sa.BigInteger(), nullable=True),
        sa.Column("last_answer_message_id", sa.BigInteger(), nullable=True),
        sa.Column(
            "last_asked_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
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
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("chat_id", "fingerprint", name="uq_chat_faq_fp"),
    )
    op.create_index("ix_chat_faqs_chat_id", "chat_faqs", ["chat_id"])
    op.create_index("ix_chat_faqs_fingerprint", "chat_faqs", ["fingerprint"])


def downgrade() -> None:
    op.drop_index("ix_chat_faqs_fingerprint", table_name="chat_faqs")
    op.drop_index("ix_chat_faqs_chat_id", table_name="chat_faqs")
    op.drop_table("chat_faqs")
