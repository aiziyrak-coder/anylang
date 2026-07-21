import re
from datetime import UTC, date, datetime
from typing import Annotated

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user import AppLanguage, Gender, UserOut

PasswordStr = Annotated[str, Field(min_length=8, max_length=128)]


def _validate_password(value: str) -> str:
    if not re.search(r"[A-Za-z]", value):
        raise ValueError("Password must contain at least one letter")
    if not re.search(r"\d", value):
        raise ValueError("Password must contain at least one digit")
    return value


def _validate_birth_date(value: date) -> date:
    today = datetime.now(UTC).date()
    if value > today:
        raise ValueError("Birth date cannot be in the future")
    min_birth = today.replace(year=today.year - 13)
    if value > min_birth:
        raise ValueError("User must be at least 13 years old")
    return value


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    password: PasswordStr
    birth_date: date
    gender: Gender
    country: str = Field(min_length=2, max_length=2)
    terms_accepted: bool
    app_language: AppLanguage = "uz_UZ"
    native_language: str = Field(min_length=2, max_length=8)

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        return _validate_password(value)

    @field_validator("birth_date")
    @classmethod
    def birth_date_valid(cls, value: date) -> date:
        return _validate_birth_date(value)

    @field_validator("terms_accepted")
    @classmethod
    def terms_required(cls, value: bool) -> bool:
        if not value:
            raise ValueError("Terms must be accepted")
        return value

    @field_validator("country")
    @classmethod
    def country_upper(cls, value: str) -> str:
        return value.upper()


class LoginIn(BaseModel):
    email: EmailStr
    password: str
    app_language: AppLanguage | None = None
    native_language: str | None = Field(default=None, min_length=2, max_length=8)


class VerifyEmailIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class ResendIn(BaseModel):
    email: EmailStr
    app_language: AppLanguage = "uz_UZ"


class GoogleIn(BaseModel):
    id_token: str = Field(min_length=10)
    app_language: AppLanguage | None = None
    native_language: str | None = Field(default=None, min_length=2, max_length=8)


class ForgotIn(BaseModel):
    email: EmailStr
    app_language: AppLanguage = "uz_UZ"


class ResetIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")
    new_password: PasswordStr

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        return _validate_password(value)


class LogoutIn(BaseModel):
    refresh_token: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenPairOut(BaseModel):
    access_token: str
    refresh_token: str


class RegisterOut(BaseModel):
    email: EmailStr
    message: str
    resend_after_seconds: int = Field(ge=0)


class AuthSessionOut(TokenPairOut):
    user: UserOut
