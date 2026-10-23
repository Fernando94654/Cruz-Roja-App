import uuid

from sqlalchemy import String, Text
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base
from app.models.common import uuid_pk


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = uuid_pk()
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text)
    duration_seconds: Mapped[int | None]
    video_url: Mapped[str | None] = mapped_column(String(500))
    guide_id: Mapped[str | None] = mapped_column(String(80))
    publisher: Mapped[str | None] = mapped_column(Text)
    steps: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    position: Mapped[int] = mapped_column(default=0, server_default="0")
