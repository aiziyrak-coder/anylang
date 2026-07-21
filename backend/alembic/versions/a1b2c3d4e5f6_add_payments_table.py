"""add payments table

Revision ID: a1b2c3d4e5f6
Revises: 2fa29135edef
Create Date: 2026-07-21 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "2fa29135edef"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "payments",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("kind", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("currency", sa.String(length=8), nullable=False),
        sa.Column("plan", sa.String(length=32), nullable=True),
        sa.Column("billing_cycle", sa.String(length=32), nullable=True),
        sa.Column("number", sa.String(length=7), nullable=True),
        sa.Column("stripe_session_id", sa.String(length=255), nullable=True),
        sa.Column("stripe_payment_intent_id", sa.String(length=255), nullable=True),
        sa.Column("metadata", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("stripe_session_id"),
    )
    op.create_index(op.f("ix_payments_user_id"), "payments", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_payments_user_id"), table_name="payments")
    op.drop_table("payments")
