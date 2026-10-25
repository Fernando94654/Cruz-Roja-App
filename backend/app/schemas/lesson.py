from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class LessonOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: str | None
    duration_seconds: int | None
    video_url: str | None
    publisher: str | None
    steps: list[str]
    position: int
    guide_id: str | None


class LessonCompletionsIn(BaseModel):
    # Everything the app marked while offline or signed out, sent in one request
    lesson_ids: list[UUID] = Field(max_length=200)


class LessonCompletionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    lesson_id: UUID
    completed_at: datetime
