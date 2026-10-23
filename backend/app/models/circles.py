import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import point, timestamp_now, uuid_pk


class CircleRole(enum.Enum):
    admin = "admin"
    member = "member"


class InvitationStatus(enum.Enum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"
    expired = "expired"


class WellbeingStatus(enum.Enum):
    ok = "ok"
    need_help = "need_help"
    no_response = "no_response"


class Circle(Base):
    __tablename__ = "circles"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(80))
    created_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = timestamp_now()


class CircleMember(Base):
    __tablename__ = "circle_members"

    circle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("circles.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True, index=True)
    role: Mapped[CircleRole] = mapped_column(
        Enum(CircleRole, name="circle_role"), default=CircleRole.member, server_default="member"
    )
    shares_location: Mapped[bool] = mapped_column(default=True, server_default="true")
    # How the person who invited them calls them ("Mamá", "Abuelo"...)
    relationship: Mapped[str | None] = mapped_column(String(40))
    joined_at: Mapped[datetime] = timestamp_now()


class CircleInvitation(Base):
    __tablename__ = "circle_invitations"

    id: Mapped[uuid.UUID] = uuid_pk()
    circle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("circles.id", ondelete="CASCADE"), index=True)
    invited_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    contact: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120), server_default="")
    relationship: Mapped[str | None] = mapped_column(String(40))
    token: Mapped[str] = mapped_column(String(64), unique=True)
    status: Mapped[InvitationStatus] = mapped_column(
        Enum(InvitationStatus, name="invitation_status"), default=InvitationStatus.pending, server_default="pending"
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = timestamp_now()


class UserLocation(Base):
    """Last known location only, no history."""

    __tablename__ = "user_locations"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    location = mapped_column(point(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class WellbeingCheck(Base):
    """A "¿Estás bien?" sent to user_id. Stays no_response until they answer."""

    __tablename__ = "wellbeing_checks"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    requested_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    alert_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("official_alerts.id", ondelete="SET NULL"))
    report_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("emergency_reports.id", ondelete="SET NULL"))
    status: Mapped[WellbeingStatus] = mapped_column(Enum(WellbeingStatus, name="wellbeing_status"))
    created_at: Mapped[datetime] = timestamp_now()
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
