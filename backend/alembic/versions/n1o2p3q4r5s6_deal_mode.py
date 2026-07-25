"""Deal Mode — chat_deals table."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "n1o2p3q4r5s6"
down_revision = "m0n1o2p3q4r5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_deals",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("created_by", sa.BigInteger(), nullable=False),
        sa.Column("updated_by", sa.BigInteger(), nullable=True),
        sa.Column("product", sa.String(length=240), nullable=False, server_default=""),
        sa.Column("price", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("currency", sa.String(length=8), nullable=False, server_default="USD"),
        sa.Column("quantity", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("unit", sa.String(length=32), nullable=False, server_default=""),
        sa.Column("delivery", sa.String(length=240), nullable=False, server_default=""),
        sa.Column("payment", sa.String(length=240), nullable=False, server_default=""),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="open"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "documents",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column(
            "accepted_by",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
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
    )
    op.create_index("ix_chat_deals_chat_id", "chat_deals", ["chat_id"])
    op.create_index("ix_chat_deals_status", "chat_deals", ["status"])
    # Bir chatda bir vaqtda bitta open/agreed deal
    op.create_index(
        "uq_chat_deals_active_chat",
        "chat_deals",
        ["chat_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('open', 'agreed')"),
    )


def downgrade() -> None:
    op.drop_index("uq_chat_deals_active_chat", table_name="chat_deals")
    op.drop_index("ix_chat_deals_status", table_name="chat_deals")
    op.drop_index("ix_chat_deals_chat_id", table_name="chat_deals")
    op.drop_table("chat_deals")
