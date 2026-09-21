"""Password hashing (bcrypt) and JWT tokens (PyJWT, HS256)."""

from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings
from app.core.errors import AppError, ErrorCode

ALGORITHM = "HS256"
ACCESS = "access"
REFRESH = "refresh"


def _password_bytes(password: str) -> bytes:
    # bcrypt only looks at the first 72 bytes of a password (and bcrypt>=5 raises
    # an error for longer input), so we cut it the same way when hashing and checking.
    return password.encode("utf-8")[:72]


def hash_password(password: str) -> str:
    hashed = bcrypt.hashpw(_password_bytes(password), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(_password_bytes(password), password_hash.encode("utf-8"))


def _create_token(user_id: int, token_type: str, lifetime: timedelta) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),  # JWT requires "sub" to be a string
        "type": token_type,
        "iat": now,
        "exp": now + lifetime,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def create_access_token(user_id: int) -> str:
    return _create_token(user_id, ACCESS, timedelta(minutes=settings.jwt_access_minutes))


def create_refresh_token(user_id: int) -> str:
    return _create_token(user_id, REFRESH, timedelta(days=settings.jwt_refresh_days))


def decode_token(token: str, expected_type: str) -> int:
    """Check the token and return the user id stored in "sub".

    Raises AppError(401) if the token is invalid, expired or of the wrong type.
    """
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise AppError(401, ErrorCode.UNAUTHORIZED, "Token has expired")
    except jwt.InvalidTokenError:
        raise AppError(401, ErrorCode.UNAUTHORIZED, "Invalid token")

    if payload.get("type") != expected_type:
        raise AppError(401, ErrorCode.UNAUTHORIZED, f"Expected a {expected_type} token")

    try:
        return int(payload["sub"])
    except (KeyError, ValueError):
        raise AppError(401, ErrorCode.UNAUTHORIZED, "Invalid token")
