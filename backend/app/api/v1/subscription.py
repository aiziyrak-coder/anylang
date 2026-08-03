from fastapi import APIRouter, Query

from app.api.deps_auth import CurrentUser, OptionalCurrentUser
from app.core.deps import DbSession
from app.payments.schemas import SubscriptionCheckoutIn, SubscriptionCheckoutOut
from app.payments.service import create_subscription_checkout
from app.schemas.subscription import PlansOut, SubscribeIn
from app.schemas.user import UserOut
from app.services import subscription as subscription_service

router = APIRouter()


@router.get("/plans", response_model=PlansOut)
async def list_plans(
    current_user: OptionalCurrentUser,
    language: str | None = Query(default=None),
    billing_cycle: str | None = Query(default=None),
    currency: str | None = Query(
        default=None,
        description="Ignored — catalog is always UZS (Click).",
    ),
) -> PlansOut:
    country = None
    if current_user is not None:
        country = (current_user.country or "").strip().upper() or None
    data = subscription_service.get_plans(
        language=language,
        billing_cycle=billing_cycle,
        country=country,
        currency=currency,
    )
    return PlansOut.model_validate(data)


@router.post("/checkout", response_model=SubscriptionCheckoutOut)
async def subscription_checkout(
    body: SubscriptionCheckoutIn,
    current_user: CurrentUser,
    db: DbSession,
) -> SubscriptionCheckoutOut:
    """Paid plan entry: pending Payment + Click checkout_url (UZS)."""
    data = await create_subscription_checkout(
        db,
        current_user,
        plan=body.plan,
        billing_cycle=body.billing_cycle or "monthly",
        provider="click",
    )
    await db.commit()
    return SubscriptionCheckoutOut.model_validate(data)


@router.post("/subscribe", response_model=UserOut)
async def subscribe(
    body: SubscribeIn,
    current_user: CurrentUser,
    db: DbSession,
) -> UserOut:
    data = await subscription_service.subscribe(
        db,
        current_user,
        plan=body.plan,
        billing_cycle=body.billing_cycle,
    )
    await db.commit()
    return UserOut.model_validate(data)


@router.post("/cancel", response_model=UserOut)
async def cancel_subscription(current_user: CurrentUser, db: DbSession) -> UserOut:
    data = await subscription_service.cancel_subscription(db, current_user)
    await db.commit()
    return UserOut.model_validate(data)
