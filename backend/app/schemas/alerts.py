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
Severity = Literal["info", "moderate", "high", "extreme"]
ReportType = Literal["flood", "traffic_light", "accident", "fallen_tree", "blocked_street", "power_outage", "fire", "other"]


class OfficialAlertOut(BaseModel):
    id: uuid.UUID
    source: str
    title: str
    description: str | None
    area_name: str | None
    severity: Severity
    starts_at: UtcDatetime


class CommunityReportIn(BaseModel):
    type: ReportType
    title: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    @field_validator("title")
    @classmethod
    def title_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("describe qué pasó")
        return value


class CommunityReportOut(BaseModel):
    """Who published the report is never sent; is_mine only tells the user about their own reports."""

    id: uuid.UUID
    type: ReportType
    title: str
    confirmations: int
    confirmed_by_me: bool
    flags: int
    flagged_by_me: bool
    is_mine: bool
    expires_at: UtcDatetime
