"""Auth endpoints: register, login, refresh token, current user, device tokens."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.errors import AppError, ErrorCode
from app.core.security import (
    REFRESH,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models import DeviceToken, User
from app.schemas.auth import (
    AuthResponse,
    DeviceTokenOut,
    DeviceTokenRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        user=UserOut.model_validate(user),
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/register", response_model=AuthResponse, status_code=201)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    email = body.email.lower()
    existing = db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise AppError(409, ErrorCode.CONFLICT, "Email is already registered")

    user = User(
        email=email,
        password_hash=hash_password(body.password),
        display_name=body.display_name.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _auth_response(user)


@router.post("/login", response_model=AuthResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    # Same message for "no such email" and "wrong password", so nobody can guess emails.
    if user is None or not verify_password(body.password, user.password_hash):
        raise AppError(401, ErrorCode.UNAUTHORIZED, "Wrong email or password")
    return _auth_response(user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)):
    user_id = decode_token(body.refresh_token, REFRESH)
    user = db.get(User, user_id)
    if user is None:
        raise AppError(401, ErrorCode.UNAUTHORIZED, "User no longer exists")
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/device-tokens", response_model=DeviceTokenOut, status_code=201)
def register_device_token(
    body: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Save the FCM token of this device. If the token is already known, it is
    moved to the current user (e.g. another account logged in on the same phone)."""
    device = db.scalar(select(DeviceToken).where(DeviceToken.token == body.token))
    if device is None:
        device = DeviceToken(token=body.token, user_id=current_user.id, platform=body.platform)
        db.add(device)
    else:
        device.user_id = current_user.id
        device.platform = body.platform
    db.commit()
    db.refresh(device)
    return device
