import uuid

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import delete, literal, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.deps import get_db
from app.models.learning import Lesson, LessonCompletion
from app.models.users import User
from app.schemas.lesson import LessonCompletionOut, LessonCompletionsIn, LessonOut

router = APIRouter(prefix="/lessons", tags=["Lessons"])


@router.get("", response_model=list[LessonOut])
def read_lessons(db: Session = Depends(get_db)) -> list[LessonOut]:
    try:
        rows = db.scalars(select(Lesson).order_by(Lesson.position, Lesson.id)).all()
    except SQLAlchemyError:
        raise HTTPException(503, detail="Las lecciones no están disponibles. Intenta de nuevo.") from None
    return [LessonOut.model_validate(row) for row in rows]


def completions_of(db: Session, me: User) -> list[LessonCompletionOut]:
    rows = db.scalars(
        select(LessonCompletion).where(LessonCompletion.user_id == me.id).order_by(LessonCompletion.completed_at)
    )
    return [LessonCompletionOut.model_validate(row) for row in rows]


@router.get("/completions", response_model=list[LessonCompletionOut])
def read_completions(me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[LessonCompletionOut]:
    return completions_of(db, me)


@router.post("/completions", response_model=list[LessonCompletionOut])
def complete_lessons(
    data: LessonCompletionsIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[LessonCompletionOut]:
    # Repeats are ignored and ids of deleted lessons are skipped, so syncing what the app saved offline is always safe
    if data.lesson_ids:
        existing = select(literal(me.id), Lesson.id).where(Lesson.id.in_(data.lesson_ids))
        db.execute(
            insert(LessonCompletion)
            .from_select(["user_id", "lesson_id"], existing)
            .on_conflict_do_nothing()
        )
        db.commit()
    return completions_of(db, me)


@router.delete("/{lesson_id}/completion", status_code=status.HTTP_204_NO_CONTENT)
def uncomplete_lesson(
    lesson_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Response:
    db.execute(delete(LessonCompletion).where(LessonCompletion.user_id == me.id, LessonCompletion.lesson_id == lesson_id))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
