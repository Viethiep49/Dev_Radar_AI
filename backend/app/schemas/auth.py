import hashlib
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)
    display_name: str = Field(min_length=1, max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6, max_length=72)


class UpdateAvatarRequest(BaseModel):
    avatar_url: str = Field(min_length=1, max_length=500)


class GoogleLoginRequest(BaseModel):
    # ID token from google_sign_in (Flutter): GoogleSignInAuthentication.idToken
    id_token: str = Field(min_length=1, max_length=4096)


class GitHubLoginRequest(BaseModel):
    # "code" from the redirect github.com -> GITHUB_REDIRECT_URI
    code: str = Field(min_length=1, max_length=500)
    # PKCE: the random string the app used to build code_challenge (recommended)
    code_verifier: str | None = Field(default=None, min_length=43, max_length=128)


class GoogleProviderOut(BaseModel):
    enabled: bool
    client_id: str | None  # Web client ID -> serverClientId in google_sign_in


class GitHubProviderOut(BaseModel):
    enabled: bool
    client_id: str | None
    redirect_uri: str | None
    authorize_url: str = "https://github.com/login/oauth/authorize"
    scope: str


class OAuthProvidersOut(BaseModel):
    google: GoogleProviderOut
    github: GitHubProviderOut


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # allow building it from a User model

    id: int
    email: str
    display_name: str
    created_at: datetime
    avatar_url: str | None = None

    @model_validator(mode="after")
    def compute_avatar(self):
        if not self.avatar_url:
            h = hashlib.md5(self.email.strip().lower().encode("utf-8")).hexdigest()
            self.avatar_url = f"https://www.gravatar.com/avatar/{h}?d=identicon&s=200"
        return self


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
