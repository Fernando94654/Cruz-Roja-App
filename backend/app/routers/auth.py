import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import check_password, create_token
from app.deps import get_db
from app.models import User

router = APIRouter(prefix="/auth", tags=["Auth"])


class LoginIn(BaseModel):
    email: str
    password: str


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: uuid.UUID
    name: str
    email: str


@router.post("/login", response_model=LoginOut)
def login(data: LoginIn, db: Session = Depends(get_db)) -> LoginOut:
    user = db.scalar(select(User).where(User.email == data.email.strip()))
    # Same message for a wrong email or password, so nobody can find out who has an account
    if not check_password(user, data.password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Correo o contraseña incorrectos")
    return LoginOut(access_token=create_token(user.id), user_id=user.id, name=user.name, email=user.email)
