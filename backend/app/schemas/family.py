import re
import uuid
from datetime import datetime, timezone
from typing import Annotated, Literal

from pydantic import BaseModel, Field, PlainSerializer, field_validator


def iso_utc(value: datetime) -> str:
    # Same format as the medical profile, iOS parses it as is
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


UtcDatetime = Annotated[datetime, PlainSerializer(iso_utc, return_type=str)]
MemberStatus = Literal["ok", "need_help", "waiting", "unknown"]


def normalize_contact(value: str) -> str:
    """Emails in lowercase, phones as 10 digits."""
    value = value.strip().lower()
    if "@" in value:
        local, _, domain = value.partition("@")
        if not local or "." not in domain or " " in value:
            raise ValueError("el correo no es válido")
        return value
    digits = re.sub(r"\D", "", value)
    if len(digits) != 10:
        raise ValueError("escribe un celular de 10 dígitos o un correo")
    return digits


class CoordinateOut(BaseModel):
    latitude: float
    longitude: float


class MemberOut(BaseModel):
    id: uuid.UUID
    name: str
    relationship: str | None
    phone: str | None
    status: MemberStatus
    updated_at: UtcDatetime
    shares_location: bool
    coordinate: CoordinateOut | None


class InvitationOut(BaseModel):
    id: uuid.UUID
    name: str
    contact: str
    relationship: str | None
    # Who sent it, only for the invitations I received
    from_name: str | None = None
    sent_at: UtcDatetime
    expires_at: UtcDatetime


class WellbeingRequestOut(BaseModel):
    id: uuid.UUID
    from_name: str
    reason: str | None
    sent_at: UtcDatetime


class FamilyOut(BaseModel):
    """Everything the Familia screen shows. Every endpoint returns it so the app just redraws."""

    members: list[MemberOut]
    sent_invitations: list[InvitationOut]
    received_invitations: list[InvitationOut]
    wellbeing_request: WellbeingRequestOut | None
    shares_location: bool


class InvitationIn(BaseModel):
    name: str = Field(max_length=120)
    contact: str = Field(max_length=255)
    relationship: str | None = Field(default=None, max_length=40)

    @field_validator("name")
    @classmethod
    def name_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("escribe el nombre de tu familiar")
        return value

    @field_validator("contact")
    @classmethod
    def valid_contact(cls, value: str) -> str:
        return normalize_contact(value)

    @field_validator("relationship")
    @classmethod
    def blank_is_none(cls, value: str | None) -> str | None:
        return (value or "").strip() or None


class AnswerIn(BaseModel):
    status: Literal["ok", "need_help"]


class SharingIn(BaseModel):
    shares_location: bool
