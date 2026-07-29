"""Verify Multicard callback signature helpers."""

from app.payments.multicard import _norm_amount_for_sign, verify_callback_sign


def test_norm_amount():
    assert _norm_amount_for_sign("50000") == "50000"
    assert _norm_amount_for_sign("50000.0") == "50000"
    assert _norm_amount_for_sign("50000.00") == "50000"
    assert _norm_amount_for_sign(50000) == "50000"


def test_sign_sha1_and_md5():
    secret = "Pw18axeBFo8V7NamKHXX"
    uuid = "896b1b56-8898-4145-ad7b-6578fb026d17"
    invoice_id = "al-42"
    amount = "10000"
    store_id = "6"

    import hashlib

    sha1 = hashlib.sha1(f"{uuid}{invoice_id}{amount}{secret}".encode()).hexdigest()
    md5 = hashlib.md5(f"{store_id}{invoice_id}{amount}{secret}".encode()).hexdigest()

    assert verify_callback_sign(
        {"uuid": uuid, "invoice_id": invoice_id, "amount": amount, "sign": sha1},
        secret=secret,
    )
    assert verify_callback_sign(
        {
            "uuid": uuid,
            "invoice_id": invoice_id,
            "amount": "10000.00",
            "store_id": store_id,
            "sign": md5,
        },
        secret=secret,
    )
    assert not verify_callback_sign(
        {"uuid": uuid, "invoice_id": invoice_id, "amount": amount, "sign": "deadbeef"},
        secret=secret,
    )
