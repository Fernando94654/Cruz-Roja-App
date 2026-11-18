from pydantic import BaseModel, ConfigDict


class KbChunkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    topic: str
    text: str
    embedding: list[float] | None
    embedding_model: str | None
