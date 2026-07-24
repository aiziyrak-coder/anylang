from fastapi import APIRouter, Request

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.payment import CheckoutIn, CheckoutOut, ConfirmPaymentOut, PaymentOut
from app.schemas.promo import PromoValidateIn, PromoValidateOut
from app.services import payments as payments_service
from app.services import promo as promo_service
from app.services.subscription import compute_period_price, normalize_billing_months

router = APIRouter()


@router.post("/webhook/stripe")
async def stripe_webhook(request: Request, db: DbSession) -> dict[str, str]:
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")
    result = await payments_service.handle_stripe_webhook(db, payload, sig_header)
    await db.commit()
    return result


@router.post("/promo/validate", response_model=PromoValidateOut)
async def validate_promo(
    body: PromoValidateIn,
    current_user: CurrentUser,
    db: DbSession,
) -> PromoValidateOut:
    months = normalize_billing_months(body.billing_cycle)
    amount, _, _ = compute_period_price(body.plan, months)
    data = await promo_service.validate_promo_for_checkout(
        db,
        current_user,
        code=body.code,
        plan=body.plan,
        months=months,
        amount=amount,
    )
    return PromoValidateOut.model_validate(data)


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
        chat_id=body.chat_id,
        promo_code=body.promo_code,
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
