"""Languages table + seed from catalog."""

from __future__ import annotations

import json

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

from app.services.language_catalog import catalog_dicts

revision = "c8d9e0f1a2b3"
down_revision = "a7b8c9d0e1f2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "languages",
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("native_name", sa.String(length=64), nullable=False),
        sa.Column("flag_country", sa.String(length=2), nullable=False),
        sa.Column("flag_emoji", sa.String(length=16), nullable=False, server_default=""),
        sa.Column("flag_url", sa.Text(), nullable=False),
        sa.Column("stt", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("tts", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column(
            "tts_voices",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
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
        sa.PrimaryKeyConstraint("code"),
    )

    conn = op.get_bind()
    for row in catalog_dicts():
        conn.execute(
            sa.text(
                """
                INSERT INTO languages
                    (code, native_name, flag_country, flag_emoji, flag_url, stt, tts, tts_voices, is_active)
                VALUES
                    (:code, :native_name, :flag_country, :flag_emoji, :flag_url, :stt, :tts, CAST(:tts_voices AS jsonb), true)
                ON CONFLICT (code) DO UPDATE SET
                    native_name = EXCLUDED.native_name,
                    flag_country = EXCLUDED.flag_country,
                    flag_emoji = EXCLUDED.flag_emoji,
                    flag_url = EXCLUDED.flag_url,
                    stt = EXCLUDED.stt,
                    tts = EXCLUDED.tts,
                    tts_voices = EXCLUDED.tts_voices,
                    is_active = true,
                    updated_at = now()
                """
            ),
            {
                "code": row["code"],
                "native_name": row["native_name"],
                "flag_country": row["flag_country"],
                "flag_emoji": row["flag_emoji"],
                "flag_url": row["flag_url"],
                "stt": row["stt"],
                "tts": row["tts"],
                "tts_voices": json.dumps(row["tts_voices"]),
            },
        )


def downgrade() -> None:
    op.drop_table("languages")
