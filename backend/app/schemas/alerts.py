import uuid
from datetime import datetime, timezone
from typing import Annotated, Literal

from pydantic import BaseModel, Field, PlainSerializer, field_validator


def iso_utc(value: datetime) -> str:
    # Se utiliza el mismo formato de fecha para mantener la compatibilidad con iOS
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


# Datos que envia la app al publicar un reporte, con validacion del titulo y las coordenadas
class CommunityReportIn(BaseModel):
    type: ReportType
    title: str = Field(min_length=1, max_length=160)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    # Valida que el titulo no quede vacio despues de eliminar los espacios
    @field_validator("title")
    @classmethod
    def title_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("describe qué pasó")
        return value


class CommunityReportOut(BaseModel):
    """No se expone quien publico el reporte; is_mine solo indica si pertenece al usuario actual."""

    id: uuid.UUID
    type: ReportType
    title: str
    confirmations: int
    confirmed_by_me: bool
    flags: int
    flagged_by_me: bool
    is_mine: bool
    expires_at: UtcDatetime
