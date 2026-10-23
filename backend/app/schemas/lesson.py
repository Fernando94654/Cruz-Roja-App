from uuid import UUID

from pydantic import BaseModel, ConfigDict


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
