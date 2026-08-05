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


_WELCOME_SUBJECTS = {
    "uz_UZ": "AnyLang — biznes akkountingiz tayyor!",
    "ru_RU": "AnyLang — ваш бизнес-аккаунт готов!",
    "us_US": "AnyLang — your business account is ready!",
}


async def send_partner_welcome_email(
    *,
    to_email: str,
    contact_name: str,
    company_name: str,
    number: str,
    app_language: str = "uz_UZ",
    checklist: list[dict[str, str]] | None = None,
) -> bool:
    """Welcome email after partner application approve. Fail-open like OTP."""
    settings = get_settings()
    lang = _lang(app_language)
    name = escape(contact_name or "")
    company = escape(company_name or "")
    num = escape(number or "")
    steps = checklist or []
    steps_html = "".join(
        f'<li style="margin:0 0 8px;color:#c7d8cf;font-size:14px;line-height:1.4;">'
        f'{escape(str(s.get("label") or ""))}</li>'
        for s in steps
    )
    if lang == "ru_RU":
        title = "Добро пожаловать в AnyLang Business"
        intro = (
            f"Здравствуйте, {name}! Заявка «{company}» одобрена. "
            f"Ваш AnyLang номер: <strong style='color:#B8F25A'>{num}</strong>. "
            "Войдите в приложение с email и паролем, указанными в анкете."
        )
        checklist_title = "Чеклист онбординга"
        plain = (
            f"Здравствуйте, {contact_name}!\n\n"
            f"Заявка «{company_name}» одобрена. AnyLang номер: {number}.\n"
            "Войдите в приложение с email/паролем из анкеты.\n\n"
            "Онбординг:\n"
            + "\n".join(f"- {s.get('label')}" for s in steps)
        )
    elif lang == "us_US":
        title = "Welcome to AnyLang Business"
        intro = (
            f"Hi {name}! Your application for «{company}» was approved. "
            f"Your AnyLang number: <strong style='color:#B8F25A'>{num}</strong>. "
            "Sign in with the email and password from your application."
        )
        checklist_title = "Onboarding checklist"
        plain = (
            f"Hi {contact_name}!\n\n"
            f"Your application for «{company_name}» was approved. AnyLang number: {number}.\n"
            "Sign in with the email/password from your application.\n\n"
            "Onboarding:\n"
            + "\n".join(f"- {s.get('label')}" for s in steps)
        )
    else:
        title = "AnyLang Business’ga xush kelibsiz"
        intro = (
            f"Salom, {name}! «{company}» anketangiz tasdiqlandi. "
            f"AnyLang raqamingiz: <strong style='color:#B8F25A'>{num}</strong>. "
            "Anketada ko‘rsatgan email/parol bilan ilovaga kiring."
        )
        checklist_title = "Onboarding checklist"
        plain = (
            f"Salom, {contact_name}!\n\n"
            f"«{company_name}» anketangiz tasdiqlandi. AnyLang raqam: {number}.\n"
            "Anketadagi email/parol bilan ilovaga kiring.\n\n"
            "Onboarding:\n"
            + "\n".join(f"- {s.get('label')}" for s in steps)
        )

    html = f"""\
<!DOCTYPE html>
<html lang="{lang[:2]}">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width" /></head>
<body style="margin:0;padding:0;background:#06131c;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#06131c;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:520px;background:#0b1a14;border:1px solid rgba(184,242,90,0.2);border-radius:16px;padding:28px 24px;">
        <tr><td style="text-align:center;color:#f4faf6;font-size:22px;font-weight:700;padding-bottom:8px;">AnyLang</td></tr>
        <tr><td style="text-align:center;color:#c7d8cf;font-size:16px;font-weight:600;padding-bottom:12px;">{escape(title)}</td></tr>
        <tr><td style="color:#849990;font-size:14px;line-height:1.55;padding-bottom:16px;">{intro}</td></tr>
        <tr><td style="color:#B8F25A;font-size:13px;font-weight:700;padding-bottom:8px;">{escape(checklist_title)}</td></tr>
        <tr><td><ol style="margin:0;padding-left:18px;">{steps_html}</ol></td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""

    msg = EmailMessage()
    msg["Subject"] = _WELCOME_SUBJECTS[lang]
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(plain)
    msg.add_alternative(html, subtype="html")

    try:
        if (settings.resend_api_key or "").strip():
            payload = {
                "from": settings.smtp_from,
                "to": [to_email],
                "subject": _WELCOME_SUBJECTS[lang],
                "text": plain,
                "html": html,
            }
            def _resend() -> None:
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
                        raise RuntimeError(
                            f"Resend HTTP {resp.status_code}: {resp.text[:300]}"
                        )

            await asyncio.to_thread(_resend)
            logger.info("Partner welcome email sent via Resend to %s", to_email)
            return True

        if not _smtp_configured(settings.smtp_host):
            logger.warning("Welcome email skipped (no mail config) — %s", to_email)
            return False

        await asyncio.to_thread(_send_smtp_sync, msg)
        logger.info("Partner welcome email sent via SMTP to %s", to_email)
        return True
    except Exception as exc:
        logger.warning(
            "Partner welcome email failed (%s): %s — %s",
            type(exc).__name__,
            str(exc)[:200],
            to_email,
        )
        return False


_PAYMENT_FAIL_SUBJECTS = {
    "uz_UZ": "AnyLang — to‘lov amalga oshmadi",
    "ru_RU": "AnyLang — платёж не прошёл",
    "us_US": "AnyLang — payment failed",
}


async def send_payment_failed_email(
    *,
    to_email: str,
    full_name: str,
    payment_id: int,
    amount: str,
    currency: str,
    kind: str,
    app_language: str = "uz_UZ",
) -> bool:
    """Notify user that a payment failed / needs retry. Fail-open."""
    settings = get_settings()
    lang = _lang(app_language)
    name = escape(full_name or "") or "—"
    amt = escape(f"{amount} {currency}")
    pid = escape(str(payment_id))
    kind_e = escape(kind)

    if lang == "ru_RU":
        title = "Платёж не прошёл"
        body = (
            f"Здравствуйте, {name}. Платёж #{pid} ({kind_e}, {amt}) не завершён. "
            "Откройте приложение AnyLang и повторите оплату в разделе подписки."
        )
        plain = (
            f"Здравствуйте, {full_name or ''}!\n\n"
            f"Платёж #{payment_id} ({kind}, {amount} {currency}) не завершён.\n"
            "Откройте AnyLang и повторите оплату.\n"
        )
    elif lang == "us_US":
        title = "Payment failed"
        body = (
            f"Hi {name}. Payment #{pid} ({kind_e}, {amt}) did not complete. "
            "Open the AnyLang app and retry checkout from Subscriptions."
        )
        plain = (
            f"Hi {full_name or ''}!\n\n"
            f"Payment #{payment_id} ({kind}, {amount} {currency}) did not complete.\n"
            "Open AnyLang and retry checkout.\n"
        )
    else:
        title = "To‘lov amalga oshmadi"
        body = (
            f"Salom, {name}. #{pid} to‘lov ({kind_e}, {amt}) yakunlanmadi. "
            "AnyLang ilovasida Obunalar bo‘limidan qayta to‘lashga urinib ko‘ring."
        )
        plain = (
            f"Salom, {full_name or ''}!\n\n"
            f"#{payment_id} to‘lov ({kind}, {amount} {currency}) yakunlanmadi.\n"
            "Ilovada Obunalar orqali qayta urinib ko‘ring.\n"
        )

    html = f"""\
<!DOCTYPE html>
<html lang="{lang[:2]}">
<head><meta charset="utf-8" /></head>
<body style="margin:0;padding:0;background:#06131c;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#06131c;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:520px;background:#0b1a14;border:1px solid rgba(184,242,90,0.2);border-radius:16px;padding:28px 24px;">
        <tr><td style="text-align:center;color:#f4faf6;font-size:22px;font-weight:700;padding-bottom:8px;">AnyLang</td></tr>
        <tr><td style="text-align:center;color:#c7d8cf;font-size:16px;font-weight:600;padding-bottom:12px;">{escape(title)}</td></tr>
        <tr><td style="color:#849990;font-size:14px;line-height:1.55;">{body}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""

    msg = EmailMessage()
    msg["Subject"] = _PAYMENT_FAIL_SUBJECTS[lang]
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(plain)
    msg.add_alternative(html, subtype="html")

    try:
        if (settings.resend_api_key or "").strip():
            payload = {
                "from": settings.smtp_from,
                "to": [to_email],
                "subject": _PAYMENT_FAIL_SUBJECTS[lang],
                "text": plain,
                "html": html,
            }

            def _resend() -> None:
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
                        raise RuntimeError(
                            f"Resend HTTP {resp.status_code}: {resp.text[:300]}"
                        )

            await asyncio.to_thread(_resend)
            logger.info("Payment failed email sent via Resend to %s", to_email)
            return True

        if not _smtp_configured(settings.smtp_host):
            logger.warning("Payment failed email skipped (no mail) — %s", to_email)
            return False

        await asyncio.to_thread(_send_smtp_sync, msg)
        logger.info("Payment failed email sent via SMTP to %s", to_email)
        return True
    except Exception as exc:
        logger.warning(
            "Payment failed email failed (%s): %s — %s",
            type(exc).__name__,
            str(exc)[:200],
            to_email,
        )
        return False


_RESTORE_SUBJECTS = {
    "uz_UZ": {
        "pending": "AnyLang — tiklash arizasi ko‘rib chiqilmoqda",
        "approved": "AnyLang — akkauntingiz tiklandi",
        "rejected": "AnyLang — tiklash arizasi rad etildi",
    },
    "ru_RU": {
        "pending": "AnyLang — заявка на восстановление на рассмотрении",
        "approved": "AnyLang — аккаунт восстановлен",
        "rejected": "AnyLang — заявка на восстановление отклонена",
    },
    "us_US": {
        "pending": "AnyLang — restore request under review",
        "approved": "AnyLang — your account was restored",
        "rejected": "AnyLang — restore request declined",
    },
}


async def send_restore_status_email(
    *,
    to_email: str,
    full_name: str,
    status: str,
    age_hours: float | None,
    sla_hours: int,
    keep_chats: bool,
    must_change_password: bool,
    decision_note: str | None,
    app_language: str = "uz_UZ",
) -> bool:
    """Notify user about restore request status / SLA reminder. Fail-open."""
    settings = get_settings()
    lang = _lang(app_language)
    name = escape(full_name or "") or "—"
    st = status if status in ("pending", "approved", "rejected") else "pending"
    age_s = f"{age_hours:.0f}" if age_hours is not None else "—"
    note = escape((decision_note or "").strip()[:500]) if decision_note else ""

    if lang == "ru_RU":
        if st == "approved":
            title = "Аккаунт восстановлен"
            body = (
                f"Здравствуйте, {name}. Ваш аккаунт AnyLang восстановлен. "
                + ("При входе необходимо сменить пароль. " if must_change_password else "")
                + (
                    "Чаты сохранены. "
                    if keep_chats
                    else "Чаты не восстановлены (по вашему запросу). "
                )
            )
            plain = (
                f"Здравствуйте, {full_name or ''}!\n\n"
                "Ваш аккаунт AnyLang восстановлен.\n"
                + ("Смените пароль при входе.\n" if must_change_password else "")
                + ("Чаты сохранены.\n" if keep_chats else "Чаты не восстановлены.\n")
            )
        elif st == "rejected":
            title = "Заявка отклонена"
            body = f"Здравствуйте, {name}. Заявка на восстановление отклонена."
            if note:
                body += f" Комментарий: {note}"
            plain = (
                f"Здравствуйте, {full_name or ''}!\n\n"
                "Заявка на восстановление отклонена.\n"
                + (f"Комментарий: {decision_note}\n" if decision_note else "")
            )
        else:
            title = "Заявка на рассмотрении"
            body = (
                f"Здравствуйте, {name}. Заявка на восстановление ещё рассматривается "
                f"(~{escape(age_s)} ч из SLA {sla_hours} ч). Мы сообщим о решении."
            )
            plain = (
                f"Здравствуйте, {full_name or ''}!\n\n"
                f"Заявка на рассмотрении (~{age_s} ч / SLA {sla_hours} ч).\n"
            )
    elif lang == "us_US":
        if st == "approved":
            title = "Account restored"
            body = (
                f"Hi {name}. Your AnyLang account has been restored. "
                + ("You must change your password on next sign-in. " if must_change_password else "")
                + ("Chats were kept. " if keep_chats else "Chats were not restored. ")
            )
            plain = (
                f"Hi {full_name or ''}!\n\nYour AnyLang account was restored.\n"
                + ("Change your password on next sign-in.\n" if must_change_password else "")
                + ("Chats kept.\n" if keep_chats else "Chats not restored.\n")
            )
        elif st == "rejected":
            title = "Restore declined"
            body = f"Hi {name}. Your restore request was declined."
            if note:
                body += f" Note: {note}"
            plain = (
                f"Hi {full_name or ''}!\n\nRestore request declined.\n"
                + (f"Note: {decision_note}\n" if decision_note else "")
            )
        else:
            title = "Restore under review"
            body = (
                f"Hi {name}. Your restore request is still under review "
                f"(~{escape(age_s)}h of {sla_hours}h SLA). We will email you when decided."
            )
            plain = (
                f"Hi {full_name or ''}!\n\n"
                f"Restore under review (~{age_s}h / SLA {sla_hours}h).\n"
            )
    else:
        if st == "approved":
            title = "Akkount tiklandi"
            body = (
                f"Salom, {name}. AnyLang akkauntingiz tiklandi. "
                + (
                    "Keyingi kirishda parolni almashtirishingiz shart. "
                    if must_change_password
                    else ""
                )
                + (
                    "Chatlar saqlangan. "
                    if keep_chats
                    else "Chatlar tiklanmadi (so‘rovingiz bo‘yicha). "
                )
            )
            plain = (
                f"Salom, {full_name or ''}!\n\nAkkountingiz tiklandi.\n"
                + ("Kirishda parolni almashtiring.\n" if must_change_password else "")
                + ("Chatlar saqlangan.\n" if keep_chats else "Chatlar tiklanmadi.\n")
            )
        elif st == "rejected":
            title = "Ariza rad etildi"
            body = f"Salom, {name}. Tiklash arizangiz rad etildi."
            if note:
                body += f" Izoh: {note}"
            plain = (
                f"Salom, {full_name or ''}!\n\nTiklash arizasi rad etildi.\n"
                + (f"Izoh: {decision_note}\n" if decision_note else "")
            )
        else:
            title = "Ariza ko‘rib chiqilmoqda"
            body = (
                f"Salom, {name}. Tiklash arizangiz hali ko‘rib chiqilmoqda "
                f"(~{escape(age_s)} soat / SLA {sla_hours} soat). Qaror haqida xabar beramiz."
            )
            plain = (
                f"Salom, {full_name or ''}!\n\n"
                f"Ariza ko‘rib chiqilmoqda (~{age_s} soat / SLA {sla_hours} soat).\n"
            )

    subjects = _RESTORE_SUBJECTS.get(lang) or _RESTORE_SUBJECTS["uz_UZ"]
    subject = subjects.get(st, subjects["pending"])

    html = f"""\
<!DOCTYPE html>
<html lang="{lang[:2]}">
<head><meta charset="utf-8" /></head>
<body style="margin:0;padding:0;background:#06131c;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#06131c;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:520px;background:#0b1a14;border:1px solid rgba(184,242,90,0.2);border-radius:16px;padding:28px 24px;">
        <tr><td style="text-align:center;color:#f4faf6;font-size:22px;font-weight:700;padding-bottom:8px;">AnyLang</td></tr>
        <tr><td style="text-align:center;color:#c7d8cf;font-size:16px;font-weight:600;padding-bottom:12px;">{escape(title)}</td></tr>
        <tr><td style="color:#849990;font-size:14px;line-height:1.55;">{body}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
"""

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(plain)
    msg.add_alternative(html, subtype="html")

    try:
        if (settings.resend_api_key or "").strip():
            payload = {
                "from": settings.smtp_from,
                "to": [to_email],
                "subject": subject,
                "text": plain,
                "html": html,
            }

            def _resend() -> None:
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
                        raise RuntimeError(
                            f"Resend HTTP {resp.status_code}: {resp.text[:300]}"
                        )

            await asyncio.to_thread(_resend)
            logger.info("Restore status email sent via Resend to %s (%s)", to_email, st)
            return True

        if not _smtp_configured(settings.smtp_host):
            logger.warning("Restore status email skipped (no mail) — %s", to_email)
            return False

        await asyncio.to_thread(_send_smtp_sync, msg)
        logger.info("Restore status email sent via SMTP to %s (%s)", to_email, st)
        return True
    except Exception as exc:
        logger.warning(
            "Restore status email failed (%s): %s — %s",
            type(exc).__name__,
            str(exc)[:200],
            to_email,
        )
        return False
