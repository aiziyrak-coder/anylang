from decimal import Decimal

from fastapi import APIRouter, Query

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.core.pagination import normalize_page
from app.schemas.numbers import (
    CatalogOut,
    NumberGroupOut,
    PurchaseIn,
    RandomNumberOut,
    ReserveIn,
    ReserveOut,
)
from app.schemas.user import UserOut
from app.services import numbers as numbers_service

router = APIRouter()


@router.get("/catalog", response_model=CatalogOut)
async def numbers_catalog(
    db: DbSession,
    search: str | None = Query(default=None),
    group_id: int | None = Query(default=None),
    min_price: Decimal | None = Query(default=None),
    max_price: Decimal | None = Query(default=None),
    has_bonus: bool | None = Query(default=None),
    sort: str = Query(default="price_asc", pattern="^(price_asc|price_desc|number_asc)$"),
    page: int | None = Query(default=1, ge=1),
    limit: int | None = Query(default=30, ge=1, le=100),
) -> CatalogOut:
    params = normalize_page(page, limit, default_size=30)
    data = await numbers_service.get_catalog(
        db,
        search=search,
        group_id=group_id,
        min_price=min_price,
        max_price=max_price,
        has_bonus=has_bonus,
        sort=sort,
        params=params,
    )
    return CatalogOut.model_validate(data)


@router.get("/groups", response_model=list[NumberGroupOut])
async def numbers_groups(db: DbSession) -> list[NumberGroupOut]:
    items = await numbers_service.get_groups(db)
    return [NumberGroupOut.model_validate(item) for item in items]


@router.post("/random", response_model=RandomNumberOut)
async def random_number(current_user: CurrentUser, db: DbSession) -> RandomNumberOut:
    data = await numbers_service.assign_random_number_for_user(db, current_user)
    await db.commit()
    return RandomNumberOut.model_validate(data)


@router.post("/reserve", response_model=ReserveOut)
async def reserve_number(
    body: ReserveIn,
    current_user: CurrentUser,
    db: DbSession,
) -> ReserveOut:
    data = await numbers_service.reserve_number(db, current_user, body.number)
    await db.commit()
    return ReserveOut.model_validate(data)


@router.post("/purchase", response_model=UserOut)
async def purchase_number(
    body: PurchaseIn,
    current_user: CurrentUser,
    db: DbSession,
) -> UserOut:
    data = await numbers_service.purchase_number(db, current_user, body.number)
    await db.commit()
    return UserOut.model_validate(data)
