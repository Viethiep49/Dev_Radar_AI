"""Shared FastAPI dependencies."""

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.security import ACCESS, decode_token
from app.db.session import get_db
from app.models import User

# auto_error=False: we raise our own AppError instead of FastAPI's default 403.
# HTTPBearer also adds the "Authorize" button in Swagger (/docs).
bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Read "Authorization: Bearer <access_token>" and return the logged-in user."""
    if credentials is None:
        raise AppError(401, ErrorCode.UNAUTHORIZED, "Missing access token")

    user_id = decode_token(credentials.credentials, ACCESS)
    user = db.get(User, user_id)
    if user is None:
        raise AppError(401, ErrorCode.UNAUTHORIZED, "User no longer exists")
    return user
