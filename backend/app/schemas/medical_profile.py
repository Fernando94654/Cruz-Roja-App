import re
import uuid
from datetime import date, datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

BloodTypeValue = Literal["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "unknown"]

MAX_ITEMS = 20
MAX_CONTACTS = 5
MAX_ITEM_LENGTH = 120


class EmergencyContactSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str = Field(min_length=1, max_length=120)
    relationship: str = Field(min_length=1, max_length=60)
    phone: str

    @field_validator("name", "relationship")
    @classmethod
    def not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("no puede estar vacío")
        return value

    @field_validator("phone")
    @classmethod
    def ten_digits(cls, value: str) -> str:
        digits = re.sub(r"\D", "", value)
        if len(digits) != 10:
            raise ValueError("el teléfono debe tener 10 dígitos")
        return digits


class MedicalProfileIn(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    date_of_birth: date | None = None
    blood_type: BloodTypeValue = "unknown"
    allergies: list[str] = Field(default_factory=list, max_length=MAX_ITEMS)
    conditions: list[str] = Field(default_factory=list, max_length=MAX_ITEMS)
    medications: list[str] = Field(default_factory=list, max_length=MAX_ITEMS)
    contacts: list[EmergencyContactSchema] = Field(default_factory=list, max_length=MAX_CONTACTS)

    @field_validator("full_name")
    @classmethod
    def name_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("el nombre es obligatorio")
        return value

    @field_validator("date_of_birth")
    @classmethod
    def not_in_future(cls, value: date | None) -> date | None:
        if value and value > date.today():
            raise ValueError("la fecha de nacimiento no puede ser futura")
        return value

    @field_validator("allergies", "conditions", "medications")
    @classmethod
    def clean_list(cls, values: list[str]) -> list[str]:
        # Drops blanks and case-insensitive duplicates
        cleaned: list[str] = []
        seen: set[str] = set()
        for value in values:
            value = value.strip()[:MAX_ITEM_LENGTH]
            if value and value.lower() not in seen:
                seen.add(value.lower())
                cleaned.append(value)
        return cleaned


def iso_utc(value: datetime) -> str:
    # ISO 8601 in UTC without microseconds, the format iOS parses as is
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


class MedicalProfileOut(MedicalProfileIn):
    user_id: uuid.UUID
    updated_at: datetime

    @field_serializer("updated_at")
    def serialize_updated_at(self, value: datetime) -> str:
        return iso_utc(value)


class DependentProfileIn(MedicalProfileIn):
    """Profile of someone the user looks after: same fields plus how they are related."""

    relationship: str = Field(min_length=1, max_length=60)

    @field_validator("relationship")
    @classmethod
    def relationship_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("el parentesco es obligatorio")
        return value


class DependentProfileOut(DependentProfileIn):
    id: uuid.UUID
    updated_at: datetime

    @field_serializer("updated_at")
    def serialize_updated_at(self, value: datetime) -> str:
        return iso_utc(value)
