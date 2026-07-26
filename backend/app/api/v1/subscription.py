from fastapi import APIRouter, Query

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.payments.schemas import SubscriptionCheckoutIn, SubscriptionCheckoutOut
from app.payments.service import create_subscription_checkout
from app.schemas.subscription import PlansOut, SubscribeIn
from app.schemas.user import UserOut
from app.services import subscription as subscription_service

router = APIRouter()


@router.get("/plans", response_model=PlansOut)
async def list_plans(
    language: str | None = Query(default=None),
    billing_cycle: str | None = Query(default=None),
) -> PlansOut:
    data = subscription_service.get_plans(language=language, billing_cycle=billing_cycle)
    return PlansOut.model_validate(data)


@router.post("/checkout", response_model=SubscriptionCheckoutOut)
async def subscription_checkout(
    body: SubscriptionCheckoutIn,
    current_user: CurrentUser,
    db: DbSession,
) -> SubscriptionCheckoutOut:
    """Paid plan entry: create pending Payment + provider checkout_url (Click/Paddle)."""
    data = await create_subscription_checkout(
        db,
        current_user,
        plan=body.plan,
        billing_cycle=body.billing_cycle or "monthly",
        provider=body.provider,
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
