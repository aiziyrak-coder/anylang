from fastapi import APIRouter, Request

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.payment import CheckoutIn, CheckoutOut, ConfirmPaymentOut, PaymentOut
from app.services import payments as payments_service

router = APIRouter()


@router.post("/webhook/stripe")
async def stripe_webhook(request: Request, db: DbSession) -> dict[str, str]:
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")
    result = await payments_service.handle_stripe_webhook(db, payload, sig_header)
    await db.commit()
    return result


@router.post("/checkout", response_model=CheckoutOut)
async def create_checkout(
    body: CheckoutIn,
    current_user: CurrentUser,
    db: DbSession,
) -> CheckoutOut:
    data = await payments_service.create_checkout(
        db,
        current_user,
        kind=body.kind,
        plan=body.plan,
        billing_cycle=body.billing_cycle,
        number=body.number,
    )
    await db.commit()
    return CheckoutOut.model_validate(data)


@router.post("/{payment_id}/confirm", response_model=ConfirmPaymentOut)
async def confirm_payment(
    payment_id: int,
    current_user: CurrentUser,
    db: DbSession,
) -> ConfirmPaymentOut:
    data = await payments_service.confirm_mock(db, current_user, payment_id)
    await db.commit()
    return ConfirmPaymentOut.model_validate(data)


@router.get("/{payment_id}", response_model=PaymentOut)
async def get_payment(
    payment_id: int,
    current_user: CurrentUser,
    db: DbSession,
) -> PaymentOut:
    data = await payments_service.get_payment(db, current_user, payment_id)
    return PaymentOut.model_validate(data)
