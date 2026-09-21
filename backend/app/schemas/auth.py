"""Request/response schemas for /auth."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    display_name: str = Field(min_length=1, max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # allow building it from a User model

    id: int
    email: str
    display_name: str
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthResponse(TokenResponse):
    user: UserOut


class DeviceTokenRequest(BaseModel):
    token: str = Field(min_length=1, max_length=500)
    platform: Literal["android", "ios", "web"]


class DeviceTokenOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    token: str
    platform: str
    created_at: datetime
