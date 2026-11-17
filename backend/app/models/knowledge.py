from datetime import datetime

from sqlalchemy import REAL, DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

# Short enough for the embedding model's 512 token limit
MAX_CHUNK_CHARS = 1800


# A first-aid text with its vector
class KbChunk(Base):
    __tablename__ = "kb_chunks"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    text: Mapped[str] = mapped_column(Text)
    # Empty until load_knowledge runs, and again when the text changes
    embedding: Mapped[list[float] | None] = mapped_column(ARRAY(REAL))
    embedding_model: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
