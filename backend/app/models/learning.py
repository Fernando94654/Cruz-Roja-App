import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import timestamp_now, uuid_pk


class Guide(Base):
    """Step-by-step emergency protocol; the app ships a copy for when it's offline."""

    __tablename__ = "guides"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    icon: Mapped[str] = mapped_column(String(80))
    keywords: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    manual_page: Mapped[int | None]
    position: Mapped[int] = mapped_column(default=0, server_default="0")
    # Ordered list of {title, instruction, icon, seconds?, rate?}
    steps: Mapped[list[dict]] = mapped_column(JSONB, default=list, server_default="[]")


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = uuid_pk()
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text)
    duration_seconds: Mapped[int | None]
    video_url: Mapped[str | None] = mapped_column(String(500))
    guide_id: Mapped[str | None] = mapped_column(ForeignKey("guides.id", onupdate="CASCADE", ondelete="SET NULL"))
    publisher: Mapped[str | None] = mapped_column(Text)
    steps: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    position: Mapped[int] = mapped_column(default=0, server_default="0")


class LessonCompletion(Base):
    __tablename__ = "lesson_completions"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    lesson_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), primary_key=True)
    completed_at: Mapped[datetime] = timestamp_now()
