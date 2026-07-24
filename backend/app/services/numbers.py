from __future__ import annotations

import random
import re
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.pagination import PageParams, paginate_items
from app.models.user import NumberAssignment, NumberGroup, User
from app.services.subscription import apply_bonus_subscription
from app.services.users import load_user_for_response, serialize_user

STANDARD_GROUP_NAME = "Standart"
STANDARD_PATTERN = "*******"
MAX_PICK_ATTEMPTS = 50
RESERVE_MINUTES = 15
RANDOM_COOLDOWN_DAYS = 90

SPECIAL_PATTERNS = frozenset({"sequential_asc", "sequential_desc", "palindrome", "mirror"})

# Old max was $499 (Platina). Scaled so Platina = $2000; others keep relative ratios.
SEED_GROUPS: list[dict] = [
    {
        "name": "Platina",
        "patterns": ["AAAAAAA"],
        "price": Decimal("2000.00"),
        "bonus_plan": "business",
        "bonus_duration_months": 24,
        "priority": 100,
    },
    {
        "name": "Brilliant",
        "patterns": ["AAAAABB", "AABBBBB"],
        "price": Decimal("1198.00"),
        "bonus_plan": "business",
        "bonus_duration_months": 12,
        "priority": 90,
    },
    {
        "name": "Oltin",
        "patterns": ["AAABBCC", "AAABBAA"],
        "price": Decimal("597.00"),
        "bonus_plan": "premium",
        "bonus_duration_months": 12,
        "priority": 80,
    },
    {
        "name": "Oltin — ketma-ket",
        "patterns": ["sequential_asc", "sequential_desc"],
        "price": Decimal("517.00"),
        "bonus_plan": "premium",
        "bonus_duration_months": 12,
        "priority": 78,
    },
    {
        "name": "Kumush",
        "patterns": ["AAAABBB", "palindrome"],
        "price": Decimal("317.00"),
        "bonus_plan": "premium",
        "bonus_duration_months": 6,
        "priority": 70,
    },
    {
        "name": "Kumush — juft",
        "patterns": ["ABABABA", "AABBAAB"],
        "price": Decimal("196.00"),
        "bonus_plan": "premium",
        "bonus_duration_months": 3,
        "priority": 60,
    },
    {
        "name": "Bronza",
        "patterns": ["AAA****", "****AAA"],
        "price": Decimal("76.00"),
        "bonus_plan": None,
        "bonus_duration_months": None,
        "priority": 40,
    },
    {
        "name": "Bronza — oson",
        "patterns": ["**AA*AA", "*AA*AA*"],
        "price": Decimal("36.00"),
        "bonus_plan": None,
        "bonus_duration_months": None,
        "priority": 30,
    },
    {
        "name": STANDARD_GROUP_NAME,
        "patterns": [STANDARD_PATTERN],
        "price": Decimal("0.00"),
        "bonus_plan": None,
        "bonus_duration_months": None,
        "priority": 0,
    },
]


def _is_sequential_asc(number: str) -> bool:
    if len(number) != 7 or not number.isdigit():
        return False
    digits = [int(c) for c in number]
    return all(digits[i + 1] - digits[i] == 1 for i in range(6))


def _is_sequential_desc(number: str) -> bool:
    if len(number) != 7 or not number.isdigit():
        return False
    digits = [int(c) for c in number]
    return all(digits[i] - digits[i + 1] == 1 for i in range(6))


def _is_palindrome(number: str) -> bool:
    return len(number) == 7 and number.isdigit() and number == number[::-1]


def _is_mirror(number: str) -> bool:
    return (
        len(number) == 7
        and number.isdigit()
        and number[0] == number[6]
        and number[1] == number[5]
        and number[2] == number[4]
    )


def matches_special_pattern(number: str, pattern: str) -> bool:
    if pattern == "sequential_asc":
        return _is_sequential_asc(number)
    if pattern == "sequential_desc":
        return _is_sequential_desc(number)
    if pattern == "palindrome":
        return _is_palindrome(number)
    if pattern == "mirror":
        return _is_mirror(number)
    return False


def matches_mask_pattern(number: str, pattern: str) -> bool:
    if len(number) != 7 or len(pattern) != 7:
        return False
    if pattern in SPECIAL_PATTERNS:
        return matches_special_pattern(number, pattern)

    letter_values: dict[str, str] = {}
    used_by_letter: dict[str, str] = {}

    for digit, mask_char in zip(number, pattern, strict=True):
        if mask_char == "*":
            continue
        if not mask_char.isalpha():
            return False
        upper = mask_char.upper()
        if upper in letter_values:
            if letter_values[upper] != digit:
                return False
        else:
            if digit in used_by_letter.values():
                return False
            letter_values[upper] = digit
            used_by_letter[upper] = digit

    letters = [c.upper() for c in pattern if c.isalpha()]
    if len(set(letters)) != len({letter_values[c] for c in set(letters) if c in letter_values}):
        return False
    return True


def matches_pattern(number: str, pattern: str) -> bool:
    if pattern in SPECIAL_PATTERNS:
        return matches_special_pattern(number, pattern)
    return matches_mask_pattern(number, pattern)


def classify_number(number: str, groups: list[NumberGroup]) -> NumberGroup | None:
    active = [g for g in groups if g.is_active]
    matches = []
    for group in active:
        for pattern in group.patterns or []:
            if matches_pattern(number, str(pattern)):
                matches.append(group)
                break
    if not matches:
        return None
    return max(matches, key=lambda g: g.priority)


def _generate_from_mask(pattern: str) -> Iterator[str]:
    if pattern in SPECIAL_PATTERNS:
        yield from _generate_special(pattern)
        return
    yield from _generate_mask_iterative(pattern)


def _generate_special(pattern: str) -> Iterator[str]:
    if pattern == "sequential_asc":
        # 0123456 … 3456789 — oxirgi raqam 9 dan oshmasligi kerak
        for start in range(4):
            yield "".join(str(start + i) for i in range(7))
    elif pattern == "sequential_desc":
        # 9876543 … 6543210 — manfiy raqam chiqmasligi kerak
        for start in range(9, 5, -1):
            yield "".join(str(start - i) for i in range(7))
    elif pattern == "palindrome":
        for a in range(10):
            for b in range(10):
                for c in range(10):
                    for d in range(10):
                        yield f"{a}{b}{c}{d}{c}{b}{a}"
    elif pattern == "mirror":
        for a in range(10):
            for b in range(10):
                for c in range(10):
                    for d in range(10):
                        num = f"{a}{b}{c}{d}{c}{b}{a}"
                        if _is_mirror(num):
                            yield num


def _generate_mask_iterative(pattern: str) -> Iterator[str]:
    """Generate numbers matching a 7-char mask with A-Z and *."""
    if len(pattern) != 7:
        return
    if any(ch != "*" and not ch.isalpha() for ch in pattern):
        return

    letter_digits: dict[str, str] = {}

    def resolve_slot(slot_idx: int, current: list[str]) -> Iterator[str]:
        if slot_idx == 7:
            yield "".join(current)
            return

        ch = pattern[slot_idx]
        if ch == "*":
            for d in "0123456789":
                yield from resolve_slot(slot_idx + 1, current + [d])
        else:
            upper = ch.upper()
            if upper not in letter_digits:
                used = set(letter_digits.values())
                for d in "0123456789":
                    if d in used:
                        continue
                    letter_digits[upper] = d
                    yield from resolve_slot(slot_idx + 1, current + [d])
                    del letter_digits[upper]
            else:
                yield from resolve_slot(slot_idx + 1, current + [letter_digits[upper]])

    yield from resolve_slot(0, [])


def _generate_prefix_range(prefix: str) -> Iterator[str]:
    padded = prefix.ljust(7, "0")
    end = prefix.ljust(7, "9")
    start_n = int(padded)
    end_n = int(end)
    for n in range(start_n, end_n + 1):
        yield f"{n:07d}"


async def ensure_seed_groups(db: AsyncSession) -> None:
    result = await db.execute(select(NumberGroup))
    existing = {g.name: g for g in result.scalars().all()}
    for seed in SEED_GROUPS:
        if seed["name"] in existing:
            continue
        group = NumberGroup(
            name=seed["name"],
            patterns=list(seed["patterns"]),
            price=seed["price"],
            currency="USD",
            bonus_plan=seed["bonus_plan"],
            bonus_duration_months=seed["bonus_duration_months"],
            priority=seed["priority"],
            is_active=True,
        )
        db.add(group)
    await db.flush()


async def _ensure_standard_group(db: AsyncSession) -> NumberGroup:
    await ensure_seed_groups(db)
    result = await db.execute(select(NumberGroup).where(NumberGroup.name == STANDARD_GROUP_NAME))
    group = result.scalar_one_or_none()
    if group is not None:
        return group

    group = NumberGroup(
        name=STANDARD_GROUP_NAME,
        patterns=[STANDARD_PATTERN],
        price=Decimal("0"),
        currency="USD",
        priority=0,
        is_active=True,
    )
    db.add(group)
    await db.flush()
    return group


async def _load_groups(db: AsyncSession) -> list[NumberGroup]:
    await ensure_seed_groups(db)
    result = await db.execute(select(NumberGroup).where(NumberGroup.is_active.is_(True)))
    return list(result.scalars().all())


async def _assignment_map(db: AsyncSession) -> dict[str, NumberAssignment]:
    now = datetime.now(UTC)
    result = await db.execute(select(NumberAssignment))
    assignments: dict[str, NumberAssignment] = {}
    for row in result.scalars().all():
        if row.reserved_until and row.reserved_until <= now and row.user_id is None:
            row.reserved_until = None
            row.reserved_by_user_id = None
        assignments[row.number] = row
    return assignments


def _is_available(number: str, assignments: dict[str, NumberAssignment], *, for_user_id: int | None = None) -> bool:
    assignment = assignments.get(number)
    if assignment is None:
        return True
    if assignment.user_id is not None:
        return assignment.user_id == for_user_id
    now = datetime.now(UTC)
    if assignment.reserved_until and assignment.reserved_until > now:
        return assignment.reserved_by_user_id == for_user_id
    return True


def _serialize_group_brief(group: NumberGroup) -> dict:
    return {
        "id": group.id,
        "name": group.name,
        "price": f"{group.price:.2f}",
        "currency": group.currency,
        "bonus_plan": group.bonus_plan,
        "bonus_duration_months": group.bonus_duration_months,
    }


async def _occupied_numbers(db: AsyncSession) -> set[str]:
    result = await db.execute(select(NumberAssignment.number))
    return {row[0] for row in result.all()}


async def assign_random_standard_number(db: AsyncSession, user_id: int | None = None) -> str:
    """Pick a random free 7-digit number; retry on unique races via savepoint."""
    from sqlalchemy.exc import IntegrityError

    group = await _ensure_standard_group(db)
    occupied = await _occupied_numbers(db)

    for _ in range(MAX_PICK_ATTEMPTS):
        candidate = f"{random.randint(0, 9_999_999):07d}"
        if candidate in occupied:
            continue
        try:
            async with db.begin_nested():
                assignment = NumberAssignment(
                    number=candidate,
                    user_id=user_id,
                    group_id=group.id,
                    purchased_at=None,
                )
                db.add(assignment)
                await db.flush()
            occupied.add(candidate)
            return candidate
        except IntegrityError:
            occupied.add(candidate)
            continue

    raise RuntimeError("Unable to assign a free AnyLang number")


def _validate_number(number: str) -> str:
    cleaned = re.sub(r"[\s\-]", "", number)
    if not cleaned.isdigit() or len(cleaned) != 7:
        raise AppError(
            message="Raqam 7 ta raqamdan iborat bo'lishi kerak",
            error_code="NUMBER_INVALID",
            status_code=400,
        )
    return cleaned


async def _release_user_number(db: AsyncSession, user: User) -> None:
    result = await db.execute(
        select(NumberAssignment).where(NumberAssignment.number == user.number)
    )
    old = result.scalar_one_or_none()
    if old is not None:
        await db.delete(old)
        await db.flush()


async def assign_random_number_for_user(db: AsyncSession, user: User) -> dict:
    now = datetime.now(UTC)
    if user.last_number_change_at is not None:
        cooldown_end = user.last_number_change_at + timedelta(days=RANDOM_COOLDOWN_DAYS)
        if now < cooldown_end:
            retry_after = int((cooldown_end - now).total_seconds())
            raise AppError(
                message="Bepul raqam almashtirish 90 kunda bir marta",
                error_code="NUMBER_CHANGE_COOLDOWN",
                status_code=429,
                extra={"retry_after_seconds": retry_after},
            )

    group = await _ensure_standard_group(db)
    await _release_user_number(db, user)
    new_number = await assign_random_standard_number(db, user_id=user.id)
    user.number = new_number
    user.last_number_change_at = now
    await db.flush()

    return {
        "number": new_number,
        "group": {"name": group.name, "price": f"{group.price:.2f}"},
    }


async def get_my_number(db: AsyncSession, user: User) -> dict:
    groups = await _load_groups(db)
    group = classify_number(user.number, groups) if user.number else None
    now = datetime.now(UTC)
    cooldown_seconds = 0
    can_change = True
    if user.last_number_change_at is not None:
        cooldown_end = user.last_number_change_at + timedelta(days=RANDOM_COOLDOWN_DAYS)
        if now < cooldown_end:
            can_change = False
            cooldown_seconds = int((cooldown_end - now).total_seconds())
    return {
        "number": user.number,
        "group": _serialize_group_brief(group) if group else None,
        "last_number_change_at": user.last_number_change_at,
        "can_change_free": can_change,
        "cooldown_seconds": cooldown_seconds,
        "cooldown_days": RANDOM_COOLDOWN_DAYS,
    }


async def get_groups(db: AsyncSession) -> list[dict]:
    groups = await _load_groups(db)
    assignments = await _assignment_map(db)
    items: list[dict] = []
    for group in sorted(groups, key=lambda g: -g.priority):
        if group.name == STANDARD_GROUP_NAME:
            continue
        count = 0
        for pattern in group.patterns or []:
            for num in _generate_from_mask(str(pattern)):
                if _is_available(num, assignments):
                    count += 1
                if count >= 1000:
                    break
            if count >= 1000:
                break
        items.append({**_serialize_group_brief(group), "available_count": count})
    return items


async def get_catalog(
    db: AsyncSession,
    *,
    search: str | None = None,
    group_id: int | None = None,
    min_price: Decimal | None = None,
    max_price: Decimal | None = None,
    has_bonus: bool | None = None,
    sort: str = "price_asc",
    params: PageParams,
) -> dict:
    groups = await _load_groups(db)
    assignments = await _assignment_map(db)
    group_by_id = {g.id: g for g in groups}

    if group_id is not None and group_id not in group_by_id:
        raise AppError(message="Guruh topilmadi", error_code="NOT_FOUND", status_code=404)

    candidates: list[tuple[str, NumberGroup]] = []
    seen: set[str] = set()

    def consider(num: str, group: NumberGroup) -> None:
        if len(num) != 7 or not num.isdigit():
            return
        if num in seen:
            return
        if not _is_available(num, assignments):
            return
        if min_price is not None and group.price < min_price:
            return
        if max_price is not None and group.price > max_price:
            return
        if has_bonus is True and not group.bonus_plan:
            return
        if has_bonus is False and group.bonus_plan:
            return
        if search:
            if not (num.startswith(search) or search in num):
                return
        seen.add(num)
        candidates.append((num, group))

    target_groups = groups
    if group_id is not None:
        target_groups = [group_by_id[group_id]]

    if search:
        search_digits = re.sub(r"[\s\-]", "", search)
        if search_digits.isdigit():
            standard_group = next((g for g in groups if g.name == STANDARD_GROUP_NAME), None)
            for num in _generate_prefix_range(search_digits):
                matched = classify_number(num, groups) or standard_group
                if matched and (group_id is None or matched.id == group_id):
                    consider(num, matched)
                if len(seen) >= 5000:
                    break

    for group in target_groups:
        if group.name == STANDARD_GROUP_NAME and not search:
            continue
        for pattern in group.patterns or []:
            for num in _generate_from_mask(str(pattern)):
                matched = classify_number(num, groups) or group
                if matched.id == group.id:
                    consider(num, matched)
                if len(seen) >= 5000:
                    break
            if len(seen) >= 5000:
                break

    if sort == "price_desc":
        candidates.sort(key=lambda x: (-x[1].price, x[0]))
    elif sort == "number_asc":
        candidates.sort(key=lambda x: x[0])
    else:
        candidates.sort(key=lambda x: (x[1].price, x[0]))

    items = [
        {"number": num, "group": _serialize_group_brief(grp), "is_available": True}
        for num, grp in candidates
    ]
    page_items, total = paginate_items(items, params)
    return {
        "items": page_items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(page_items) < total,
    }


async def reserve_number(
    db: AsyncSession,
    user: User,
    number: str,
    *,
    minutes: int | None = None,
) -> dict:
    number = _validate_number(number)
    groups = await _load_groups(db)
    group = classify_number(number, groups)
    if group is None or not group.is_active:
        raise AppError(message="Raqam noto'g'ri", error_code="NUMBER_INVALID", status_code=400)

    # Row lock to prevent two checkouts racing on the same number
    result = await db.execute(
        select(NumberAssignment).where(NumberAssignment.number == number).with_for_update()
    )
    assignment = result.scalar_one_or_none()
    now = datetime.now(UTC)

    if assignment is not None:
        if assignment.user_id is not None:
            raise AppError(message="Raqam band", error_code="NUMBER_TAKEN", status_code=409)
        if (
            assignment.reserved_until
            and assignment.reserved_until > now
            and assignment.reserved_by_user_id not in (None, user.id)
        ):
            raise AppError(message="Raqam band qilingan", error_code="NUMBER_RESERVED", status_code=409)

    ttl = minutes if minutes is not None else RESERVE_MINUTES
    reserved_until = now + timedelta(minutes=ttl)
    if assignment is None:
        assignment = NumberAssignment(number=number, group_id=group.id)
        db.add(assignment)
    assignment.reserved_until = reserved_until
    assignment.reserved_by_user_id = user.id
    await db.flush()

    return {"number": number, "reserved_until": reserved_until}


async def assign_purchased_number(db: AsyncSession, user: User, number: str) -> None:
    """Assign a paid number to the user after payment succeeds."""
    number = _validate_number(number)
    groups = await _load_groups(db)
    group = classify_number(number, groups)
    if group is None:
        raise AppError(message="Raqam noto'g'ri", error_code="NUMBER_INVALID", status_code=400)
    if not group.is_active:
        raise AppError(message="Guruh faol emas", error_code="GROUP_INACTIVE", status_code=409)

    now = datetime.now(UTC)
    result = await db.execute(select(NumberAssignment).where(NumberAssignment.number == number))
    assignment = result.scalar_one_or_none()

    if assignment is not None:
        if assignment.user_id is not None and assignment.user_id != user.id:
            raise AppError(message="Raqam band", error_code="NUMBER_TAKEN", status_code=409)
        if (
            assignment.reserved_until
            and assignment.reserved_until > now
            and assignment.reserved_by_user_id not in (None, user.id)
        ):
            raise AppError(message="Raqam band qilingan", error_code="NUMBER_RESERVED", status_code=409)

    await _release_user_number(db, user)

    if assignment is None:
        assignment = NumberAssignment(number=number, group_id=group.id)
        db.add(assignment)

    assignment.user_id = user.id
    assignment.group_id = group.id
    assignment.purchased_at = now
    assignment.reserved_until = None
    assignment.reserved_by_user_id = None

    user.number = number
    await db.flush()

    if group.bonus_plan and group.bonus_duration_months:
        await apply_bonus_subscription(
            db,
            user,
            bonus_plan=group.bonus_plan,
            bonus_duration_months=group.bonus_duration_months,
        )


async def resolve_number_for_purchase(
    db: AsyncSession,
    user: User,
    number: str,
) -> tuple[str, NumberGroup, Decimal]:
    """Validate a number is available for paid checkout and exclusively reserve it."""
    number = _validate_number(number)
    groups = await _load_groups(db)
    group = classify_number(number, groups)
    if group is None or not group.is_active:
        raise AppError(message="Raqam noto'g'ri", error_code="NUMBER_INVALID", status_code=400)
    if group.price <= 0:
        raise AppError(
            message="Bepul raqam uchun to'lov talab qilinmaydi",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    # Hold through typical Stripe checkout window
    await reserve_number(db, user, number, minutes=max(RESERVE_MINUTES, 45))
    return number, group, group.price


async def purchase_number(db: AsyncSession, user: User, number: str) -> dict:
    number = _validate_number(number)
    groups = await _load_groups(db)
    group = classify_number(number, groups)
    if group is None:
        raise AppError(message="Raqam noto'g'ri", error_code="NUMBER_INVALID", status_code=400)
    if not group.is_active:
        raise AppError(message="Guruh faol emas", error_code="GROUP_INACTIVE", status_code=409)

    if group.price > 0:
        raise AppError(
            message="Pullik raqam uchun to'lov talab qilinadi",
            error_code="PAYMENT_REQUIRED",
            status_code=402,
            extra={"hint": "POST /api/v1/payments/checkout"},
        )

    await assign_purchased_number(db, user, number)

    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return await serialize_user(loaded, db)
