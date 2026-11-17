import uuid
from typing import Literal

from pydantic import BaseModel, Field


class EmergencyReportIn(BaseModel):
    """Report sent by the app, with its location."""
    user_id: uuid.UUID | None = None
    reporting_for: Literal["self", "other"] = "self"
    patient_name: str | None = Field(default=None, max_length=120)
    reason: str | None = Field(default=None, max_length=255)
    injured_count: int = Field(default=1, ge=0, le=100)
    injury: str | None = Field(default=None, max_length=255)
    place: str | None = Field(default=None, max_length=255)
    reference: str | None = Field(default=None, max_length=255)
    mental_state: str | None = Field(default=None, max_length=60)
    breathing: str | None = Field(default=None, max_length=60)
    skin: str | None = Field(default=None, max_length=60)
    transcript: str | None = Field(default=None, max_length=4000)
    summary: str | None = Field(default=None, max_length=1000)
    medical_summary: str | None = Field(default=None, max_length=1000)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    address: str | None = Field(default=None, max_length=255)


class EmergencyReportCreated(BaseModel):
    """Id of the stored report and its operator link."""
    id: uuid.UUID
    share_url: str
