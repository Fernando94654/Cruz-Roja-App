from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models.learning import Guide
from app.schemas.guide import GuideOut

router = APIRouter(prefix="/guides", tags=["Guides"])


@router.get("", response_model=list[GuideOut])
def read_guides(db: Session = Depends(get_db)) -> list[GuideOut]:
    try:
        rows = db.scalars(select(Guide).order_by(Guide.position, Guide.id)).all()
    except SQLAlchemyError:
        raise HTTPException(503, detail="Las guías no están disponibles. Intenta de nuevo.") from None
    return [GuideOut.model_validate(row) for row in rows]
