"""Profile views — who viewed your profile (Premium)."""

from __future__ import annotations

revision = "o2p3q4r5s6t7"
down_revision = "n1o2p3q4r5s6"
branch_labels = None
depends_on = None

import sqlalchemy as sa
from alembic import op


def upgrade() -> None:
    op.create_table(
        "profile_views",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("profile_user_id", sa.BigInteger(), nullable=False),
        sa.Column("viewer_user_id", sa.BigInteger(), nullable=False),
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("last_viewed_at", sa.DateTime(timezone=True), nullable=False),
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
        sa.ForeignKeyConstraint(["profile_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["viewer_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "profile_user_id", "viewer_user_id", name="uq_profile_viewer"
        ),
    )
    op.create_index(
        "ix_profile_views_profile_user_id", "profile_views", ["profile_user_id"]
    )
    op.create_index(
        "ix_profile_views_viewer_user_id", "profile_views", ["viewer_user_id"]
    )
    op.create_index(
        "ix_profile_views_last_viewed_at", "profile_views", ["last_viewed_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_profile_views_last_viewed_at", table_name="profile_views")
    op.drop_index("ix_profile_views_viewer_user_id", table_name="profile_views")
    op.drop_index("ix_profile_views_profile_user_id", table_name="profile_views")
    op.drop_table("profile_views")
