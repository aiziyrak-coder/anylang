"""Add short profile bio for business accounts (max 300 chars)."""

from alembic import op
import sqlalchemy as sa

revision = "v9w0x1y2z3a4_business_bio"
down_revision = "u8v9w0x1y2z3_business_verification"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "business_profiles",
        sa.Column("bio", sa.String(length=300), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("business_profiles", "bio")
