from pydantic import BaseModel, ConfigDict


class GuideStepOut(BaseModel):
    title: str
    instruction: str
    icon: str
    seconds: int | None = None
    # Compressions per minute, when the step has a rhythm
    rate: int | None = None


class GuideOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    icon: str
    keywords: list[str]
    manual_page: int | None
    position: int
    steps: list[GuideStepOut]
