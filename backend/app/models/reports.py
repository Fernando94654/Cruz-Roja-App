import enum
import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Enum, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import point, timestamp_now, uuid_pk


class ReportingFor(enum.Enum):
    self = "self"
    other = "other"


class ReportStatus(enum.Enum):
    draft = "draft"
    sent = "sent"
    received = "received"
    attended = "attended"
    cancelled = "cancelled"


class EmergencyReport(Base):
    __tablename__ = "emergency_reports"
    __table_args__ = (
        CheckConstraint("injured_count >= 0", name="injured_count_non_negative"),
        Index("ix_emergency_reports_location", "location", postgresql_using="gist"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), index=True)
    reporting_for: Mapped[ReportingFor] = mapped_column(Enum(ReportingFor, name="reporting_for"))
    patient_name: Mapped[str | None] = mapped_column(String(120))
    reason: Mapped[str | None] = mapped_column(String(255))
    injured_count: Mapped[int] = mapped_column(default=1, server_default="1")
    injury: Mapped[str | None] = mapped_column(String(255))
    place: Mapped[str | None] = mapped_column(String(255))
    reference: Mapped[str | None] = mapped_column(String(255))
    mental_state: Mapped[str | None] = mapped_column(String(60))
    breathing: Mapped[str | None] = mapped_column(String(60))
    skin: Mapped[str | None] = mapped_column(String(60))
    transcript: Mapped[str | None] = mapped_column(Text)
    ai_summary: Mapped[str | None] = mapped_column(Text)
    # Profile summary sent by the app, shown to the operator
    medical_summary: Mapped[str | None] = mapped_column(Text)
    # Random token for the public operator link
    share_token: Mapped[str | None] = mapped_column(String(32), unique=True)
    location = mapped_column(point())
    address: Mapped[str | None] = mapped_column(String(255))
    status: Mapped[ReportStatus] = mapped_column(
        Enum(ReportStatus, name="report_status"), default=ReportStatus.draft, server_default="draft"
    )
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = timestamp_now()
