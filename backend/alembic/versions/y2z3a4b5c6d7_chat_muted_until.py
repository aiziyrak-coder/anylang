"""chat_participants.muted_until — timed mute (1h / 3h / 1d / forever)."""

from alembic import op
import sqlalchemy as sa

revision = "y2z3a4b5c6d7_chat_muted_until"
down_revision = "x1y2z3a4b5c6_extra_account_slots"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chat_participants",
        sa.Column("muted_until", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_participants", "muted_until")
