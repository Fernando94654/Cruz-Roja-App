import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, LargeBinary, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import uuid_pk


class BloodType(enum.Enum):
    a_pos = "A+"
    a_neg = "A-"
    b_pos = "B+"
    b_neg = "B-"
    ab_pos = "AB+"
    ab_neg = "AB-"
    o_pos = "O+"
    o_neg = "O-"


class MedicalProfile(Base):
    __tablename__ = "medical_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    blood_type: Mapped[BloodType | None] = mapped_column(
        Enum(BloodType, name="blood_type", values_callable=lambda e: [m.value for m in e])
    )
    # Encrypted by the backend (app.crypto)
    allergies: Mapped[bytes | None] = mapped_column(LargeBinary)
    conditions: Mapped[bytes | None] = mapped_column(LargeBinary)
    medications: Mapped[bytes | None] = mapped_column(LargeBinary)
    # Random revocable token shown in the QR; never the data itself
    qr_token: Mapped[str] = mapped_column(
        String(64), unique=True, server_default=text("encode(gen_random_bytes(24), 'hex')")
    )
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    relationship: Mapped[str | None] = mapped_column(String(60))
    phone: Mapped[str] = mapped_column(String(20))
