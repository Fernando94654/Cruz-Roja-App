import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import CITEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import timestamp_now, uuid_pk


class UserRole(enum.Enum):
    user = "user"
    paramedic = "paramedic"
    operator = "operator"
    admin = "admin"


class Platform(enum.Enum):
    ios = "ios"
    watchos = "watchos"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = uuid_pk()
    email: Mapped[str] = mapped_column(CITEXT, unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(20))
    role: Mapped[UserRole] = mapped_column(Enum(UserRole, name="user_role"), default=UserRole.user, server_default="user")
    created_at: Mapped[datetime] = timestamp_now()
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    apns_token: Mapped[str] = mapped_column(String(255), unique=True)
    platform: Mapped[Platform] = mapped_column(Enum(Platform, name="platform"))
    created_at: Mapped[datetime] = timestamp_now()
