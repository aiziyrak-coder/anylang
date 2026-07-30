"""Basic disposable / fake mailbox rejection for signup."""

from __future__ import annotations

_DISPOSABLE_DOMAINS = frozenset(
    {
        "mailinator.com",
        "guerrillamail.com",
        "guerrillamail.net",
        "sharklasers.com",
        "grr.la",
        "tempmail.com",
        "temp-mail.org",
        "temp-mail.io",
        "10minutemail.com",
        "10minmail.com",
        "yopmail.com",
        "trashmail.com",
        "trashmail.me",
        "discard.email",
        "dispostable.com",
        "maildrop.cc",
        "getnada.com",
        "nada.email",
        "emailondeck.com",
        "fakeinbox.com",
        "mailnesia.com",
        "throwawaymail.com",
        "mintemail.com",
        "moakt.com",
        "tmpmail.org",
        "tmpmail.net",
        "mailcatch.com",
        "mytemp.email",
        "tempail.com",
        "tempr.email",
    }
)


def is_disposable_email(email: str) -> bool:
    domain = email.lower().strip().rsplit("@", 1)[-1]
    if domain in _DISPOSABLE_DOMAINS:
        return True
    # Common patterns: tempmail.*, trashmail.*
    parts = domain.split(".")
    if len(parts) >= 2 and parts[-2] in {
        "mailinator",
        "yopmail",
        "guerrillamail",
        "tempmail",
        "temp-mail",
        "trashmail",
        "10minutemail",
    }:
        return True
    return False
