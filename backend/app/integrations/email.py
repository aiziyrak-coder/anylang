"""Transactional email for OTP (verify / reset).

Delivery order:
1. Resend HTTP API — if RESEND_API_KEY is set (preferred in production)
2. SMTP — if SMTP_HOST is a real (non-loopback) host
"""

from __future__ import annotations

import asyncio
import logging
import smtplib
from email.message import EmailMessage
from html import escape

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_OTP_SUBJECTS = {
    "uz_UZ": "AnyLang — tasdiqlash kodi",
    "ru_RU": "AnyLang — код подтверждения",
    "us_US": "AnyLang — verification code",
}

_OTP_TITLES = {
    "uz_UZ": "Emailni tasdiqlang",
    "ru_RU": "Подтвердите email",
    "us_US": "Verify your email",
}

_OTP_INTROS = {
    "uz_UZ": "AnyLang hisobingizni tasdiqlash uchun quyidagi koddan foydalaning:",
    "ru_RU": "Используйте этот код, чтобы подтвердить аккаунт AnyLang:",
    "us_US": "Use this code to verify your AnyLang account:",
}

_OTP_FOOTERS = {
    "uz_UZ": "Kod 5 daqiqa amal qiladi. Agar bu siz bo‘lmasangiz — xabarni e’tiborsiz qoldiring.",
    "ru_RU": "Код действует 5 минут. Если это не вы — просто проигнорируйте письмо.",
    "us_US": "The code expires in 5 minutes. If you didn’t request this, ignore this email.",
}

_OTP_PLAIN = {
    "uz_UZ": (
        "AnyLang tasdiqlash kodingiz: {code}\n\n"
        "Kod 5 daqiqa amal qiladi.\n"
        "Agar bu so‘rovni siz yubormagan bo‘lsangiz — xabarni e’tiborsiz qoldiring."
    ),
    "ru_RU": (
        "Ваш код подтверждения AnyLang: {code}\n\n"
        "Код действует 5 минут.\n"
        "Если вы не запрашивали код — просто проигнорируйте письмо."
    ),
    "us_US": (
        "Your AnyLang verification code: {code}\n\n"
        "The code expires in 5 minutes.\n"
        "If you didn’t request this, you can ignore this email."
    ),
}


def _lang(app_language: str) -> str:
    return app_language if app_language in _OTP_SUBJECTS else "uz_UZ"


def _html_body(code: str, lang: str) -> str:
    title = escape(_OTP_TITLES[lang])
    intro = escape(_OTP_INTROS[lang])
    footer = escape(_OTP_FOOTERS[lang])
    digits = escape(code)
    return f"""\
<!DOCTYPE html>
<html lang="{lang[:2]}">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width" /></head>
<body style="margin:0;padding:0;background:#06131c;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#06131c;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:480px;background:#0b1a14;border:1px solid rgba(184,242,90,0.2);border-radius:16px;padding:28px 24px;">
        <tr><td style="text-align:center;padding-bottom:8px;">
          <div style="display:inline-block;width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#B8F25A,#00C4B8);"></div>
        </td></tr>
        <tr><td style="text-align:center;color:#f4faf6;font-size:22px;font-weight:700;padding:8px 0 12px;">AnyLang</td></tr>
        <tr><td style="text-align:center;color:#c7d8cf;font-size:16px;font-weight:600;padding-bottom:8px;">{title}</td></tr>
        <tr><td style="text-align:center;color:#849990;font-size:14px;line-height:1.5;padding-bottom:20px;">{intro}</td></tr>
        <tr><td align="center" style="padding-bottom:20px;">
          <div style="display:inline-block;letter-spacing:10px;font-size:32px;font-weight:800;color:#0B1A14;background:#B8F25A;padding:14px 22px;border-radius:12px;">{digits}</div>
        </td></tr>
        <tr><td style="text-align:center;color:#849990;font-size:12px;line-height:1.5;">{footer}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""


def _build_message(to_email: str, code: str, app_language: str) -> EmailMessage:
    settings = get_settings()
    lang = _lang(app_language)
    msg = EmailMessage()
    msg["Subject"] = _OTP_SUBJECTS[lang]
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(_OTP_PLAIN[lang].format(code=code))
    msg.add_alternative(_html_body(code, lang), subtype="html")
    return msg


def _smtp_configured(host: str) -> bool:
    h = (host or "").strip().lower()
    return bool(h) and h not in {"localhost", "127.0.0.1", "::1"}


def _send_smtp_sync(msg: EmailMessage) -> None:
    settings = get_settings()
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as client:
        client.ehlo()
        if settings.smtp_tls:
            client.starttls()
            client.ehlo()
        if settings.smtp_user:
            client.login(settings.smtp_user, settings.smtp_password)
        client.send_message(msg)


def _send_resend_sync(to_email: str, code: str, app_language: str) -> None:
    settings = get_settings()
    lang = _lang(app_language)
    # From: prefer smtp_from; Resend requires a verified domain.
    payload = {
        "from": settings.smtp_from,
        "to": [to_email],
        "subject": _OTP_SUBJECTS[lang],
        "text": _OTP_PLAIN[lang].format(code=code),
        "html": _html_body(code, lang),
    }
    with httpx.Client(timeout=20.0) as client:
        resp = client.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {settings.resend_api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"Resend HTTP {resp.status_code}: {resp.text[:300]}")


def email_delivery_configured() -> bool:
    settings = get_settings()
    if (settings.resend_api_key or "").strip():
        return True
    return _smtp_configured(settings.smtp_host)


async def send_otp_email(to_email: str, code: str, app_language: str = "uz_UZ") -> bool:
    """Send OTP. Returns True if accepted by provider; False on soft-fail (fail-open)."""
    settings = get_settings()
    msg = _build_message(to_email, code, app_language)

    try:
        if (settings.resend_api_key or "").strip():
            await asyncio.to_thread(_send_resend_sync, to_email, code, app_language)
            logger.info("OTP email sent via Resend to %s", to_email)
            return True

        if not _smtp_configured(settings.smtp_host):
            logger.warning(
                "Email delivery not configured (no RESEND_API_KEY / SMTP_HOST); OTP not emailed — %s",
                to_email,
            )
            if settings.is_production and not settings.smtp_fail_open:
                raise RuntimeError("Email delivery is not configured")
            return False

        await asyncio.to_thread(_send_smtp_sync, msg)
        logger.info("OTP email sent via SMTP to %s", to_email)
        return True
    except Exception as exc:
        logger.warning(
            "OTP email failed (%s): %s — email=%s",
            type(exc).__name__,
            str(exc)[:200],
            to_email,
        )
        if settings.is_production and not settings.smtp_fail_open:
            raise
        return False
