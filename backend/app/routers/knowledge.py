from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.knowledge import KbChunk
from app.schemas.knowledge import KbChunkOut

router = APIRouter(prefix="/knowledge", tags=["Knowledge"])


@router.get("", response_model=list[KbChunkOut])
def read_knowledge(db: Session = Depends(get_db)) -> list[KbChunkOut]:
    # The app does the search on the phone, so this just returns everything
    try:
        rows = db.scalars(select(KbChunk).order_by(KbChunk.id)).all()
    except SQLAlchemyError:
        raise HTTPException(503, detail="La información de primeros auxilios no está disponible. Intenta de nuevo.") from None
    return [KbChunkOut.model_validate(row) for row in rows]
