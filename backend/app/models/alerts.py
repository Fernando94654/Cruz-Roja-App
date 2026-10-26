import enum
import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import point, timestamp_now, uuid_pk


class Severity(enum.Enum):
    info = "info"
    moderate = "moderate"
    high = "high"
    extreme = "extreme"


class CommunityReportType(enum.Enum):
    flood = "flood"
    traffic_light = "traffic_light"
    accident = "accident"
    fallen_tree = "fallen_tree"
    blocked_street = "blocked_street"
    power_outage = "power_outage"
    fire = "fire"
    other = "other"


class OfficialAlert(Base):
    __tablename__ = "official_alerts"
    __table_args__ = (Index("ix_official_alerts_area", "area", postgresql_using="gist"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    source: Mapped[str] = mapped_column(String(80))
    type: Mapped[str] = mapped_column(String(60))
    title: Mapped[str] = mapped_column(String(160))
    description: Mapped[str | None] = mapped_column(Text)
    area_name: Mapped[str | None] = mapped_column(String(120))
    severity: Mapped[Severity] = mapped_column(Enum(Severity, name="severity"))
    area = mapped_column(Geography(geometry_type="MULTIPOLYGON", srid=4326, spatial_index=False), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)


class CommunityReport(Base):
    __tablename__ = "community_reports"
    __table_args__ = (Index("ix_community_reports_location", "location", postgresql_using="gist"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    type: Mapped[CommunityReportType] = mapped_column(Enum(CommunityReportType, name="community_report_type"))
    details: Mapped[str | None] = mapped_column(Text)
    location = mapped_column(point(), nullable=False)
    created_at: Mapped[datetime] = timestamp_now()
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class CommunityReportConfirmation(Base):
    __tablename__ = "community_report_confirmations"

    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("community_reports.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = timestamp_now()


class CommunityReportFlag(Base):
    __tablename__ = "community_report_flags"

    report_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("community_reports.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = timestamp_now()
