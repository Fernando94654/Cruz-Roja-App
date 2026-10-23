from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.deps import get_db
from app.lesson_catalog import BY_ID
from app.models.learning import Lesson
from app.schemas.lesson import LessonOut

router = APIRouter(prefix="/lessons", tags=["Lessons"])


@router.get("", response_model=list[LessonOut])
def read_lessons(db: Session = Depends(get_db)) -> list[LessonOut]:
    try:
        rows = db.scalars(select(Lesson).order_by(Lesson.position, Lesson.id)).all()
    except SQLAlchemyError:
        raise HTTPException(503, detail="Las lecciones no están disponibles. Intenta de nuevo.") from None
    result = []
    for row in rows:
        lesson = LessonOut.model_validate(row)
        curated = BY_ID.get(row.id)
        lesson.guide_id = curated.guide_id if curated else None
        result.append(lesson)
    return result
