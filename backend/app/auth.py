import os
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import User

ALGORITHM = "HS256"
TOKEN_DAYS = 30

_hasher = PasswordHasher()
# Checked when the email doesn't exist, so both cases take the same time
_dummy_hash = _hasher.hash("not-a-real-password")
_bearer = HTTPBearer(auto_error=False)


def _secret() -> str:
    return os.environ["JWT_SECRET"]


def create_token(user_id: uuid.UUID) -> str:
    expires = datetime.now(timezone.utc) + timedelta(days=TOKEN_DAYS)
    return jwt.encode({"sub": str(user_id), "exp": expires}, _secret(), algorithm=ALGORITHM)


def check_password(user: User | None, password: str) -> bool:
    try:
        _hasher.verify(user.password_hash if user else _dummy_hash, password)
    except (VerificationError, InvalidHashError):
        return False
    return user is not None


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """The signed-in user, taken from the token and never from the URL."""
    unauthorized = HTTPException(
        status.HTTP_401_UNAUTHORIZED,
        detail="Inicia sesión para continuar",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    try:
        payload = jwt.decode(credentials.credentials, _secret(), algorithms=[ALGORITHM])
        user = db.get(User, uuid.UUID(payload["sub"]))
    except (jwt.InvalidTokenError, KeyError, ValueError):
        raise unauthorized
    if user is None:
        raise unauthorized
    return user
