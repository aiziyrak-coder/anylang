import asyncio
import logging
import smtplib
from email.message import EmailMessage

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_OTP_SUBJECTS = {
    "uz_UZ": "AnyLang — tasdiqlash kodi",
    "ru_RU": "AnyLang — код подтверждения",
    "us_US": "AnyLang — verification code",
}

_OTP_BODIES = {
    "uz_UZ": "AnyLang tasdiqlash kodingiz: {code}\n\nKod 5 daqiqa amal qiladi.",
    "ru_RU": "Ваш код подтверждения AnyLang: {code}\n\nКод действует 5 минут.",
    "us_US": "Your AnyLang verification code: {code}\n\nThe code expires in 5 minutes.",
}


def _build_message(to_email: str, code: str, app_language: str) -> EmailMessage:
    settings = get_settings()
    lang = app_language if app_language in _OTP_SUBJECTS else "uz_UZ"
    msg = EmailMessage()
    msg["Subject"] = _OTP_SUBJECTS[lang]
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(_OTP_BODIES[lang].format(code=code))
    return msg


def _send_smtp_sync(msg: EmailMessage) -> None:
    settings = get_settings()
    if settings.smtp_tls:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as client:
            client.starttls()
            if settings.smtp_user:
                client.login(settings.smtp_user, settings.smtp_password)
            client.send_message(msg)
    else:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as client:
            if settings.smtp_user:
                client.login(settings.smtp_user, settings.smtp_password)
            client.send_message(msg)


async def send_otp_email(to_email: str, code: str, app_language: str = "uz_UZ") -> bool:
    """Send OTP via SMTP. Returns True if delivered; False if logged/fallback."""
    settings = get_settings()
    msg = _build_message(to_email, code, app_language)

    try:
        await asyncio.to_thread(_send_smtp_sync, msg)
        logger.info("OTP email sent to %s", to_email)
        return True
    except Exception as exc:
        logger.warning(
            "SMTP send failed (%s); OTP fallback — email=%s code=%s",
            exc,
            to_email,
            code,
        )
        print(f"[AnyLang OTP] email={to_email} code={code} (SMTP unavailable: {exc})")
        if settings.is_production and not settings.smtp_fail_open:
            raise
        return False
