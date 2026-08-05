"""Ensure Google Play reviewer demo account exists (idempotent)."""

from __future__ import annotations

import asyncio
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import get_session_factory
from app.models.user import User
from app.services.numbers import assign_random_standard_number

EMAIL = "play.reviewer@anylang.uz"
PASSWORD = "PlayReview2026!"
FULL_NAME = "Play Store Reviewer"


async def main() -> None:
    factory = get_session_factory()
    async with factory() as db:
        existing = (
            await db.execute(select(User).where(User.email == EMAIL))
        ).scalar_one_or_none()
        if existing is not None:
            existing.password_hash = hash_password(PASSWORD)
            existing.is_verified = True
            existing.is_active = True
            existing.deleted_at = None
            existing.deletion_reason = None
            existing.scheduled_purge_at = None
            existing.full_name = FULL_NAME
            if existing.gender not in ("male", "female"):
                existing.gender = "male"
            await db.commit()
            print(f"updated existing demo user id={existing.id} email={EMAIL}")
            return

        number = await assign_random_standard_number(db)
        user = User(
            email=EMAIL,
            password_hash=hash_password(PASSWORD),
            full_name=FULL_NAME,
            number=number,
            birth_date=date(1990, 1, 15),
            gender="male",
            country="UZ",
            app_language="us_US",
            native_language="en",
            is_verified=True,
            is_active=True,
            verified_badge=False,
        )
        db.add(user)
        await db.commit()
        print(f"created demo user id={user.id} email={EMAIL} number={number}")


if __name__ == "__main__":
    asyncio.run(main())
