#!/usr/bin/env python3
"""Reset / create AdminUser inside API container DB. Ops only."""
from __future__ import annotations

import asyncio
import os
import sys


async def main() -> int:
    email = (os.environ.get("RESET_ADMIN_EMAIL") or "").strip().lower()
    password = os.environ.get("RESET_ADMIN_PASSWORD") or ""
    if not email or len(password) < 12:
        print("Need RESET_ADMIN_EMAIL and RESET_ADMIN_PASSWORD (>=12)", file=sys.stderr)
        return 2

    from app.db.session import get_session_factory
    from app.services import admin_auth

    factory = get_session_factory()
    async with factory() as db:
        admin = await admin_auth.upsert_admin(
            db,
            email=email,
            password=password,
            full_name="AnyLang Operator",
            role="superadmin",
        )
        await db.commit()
        print(f"OK admin_id={admin.id} email={admin.email} role={admin.role}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
