"""Users, their preferences (onboarding) and their devices' FCM tokens."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, utcnow

# Allowed values of UserPreference.kind
PREFERENCE_KINDS = ("language", "topic")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)  # stored lower-case
    # None for accounts created with Google/GitHub login (they have no password).
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    display_name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    preferences: Mapped[list["UserPreference"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class UserPreference(Base):
    """One row per chosen language or topic, e.g. (kind="language", value="Dart")."""

    __tablename__ = "user_preferences"
    __table_args__ = (UniqueConstraint("user_id", "kind", "value"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(20))  # "language" | "topic"
    value: Mapped[str] = mapped_column(String(100))

    user: Mapped["User"] = relationship(back_populates="preferences")


class OAuthAccount(Base):
    """A Google/GitHub identity linked to a user. One user can have several.

    The provider's user id (Google "sub", GitHub numeric id) is the stable key;
    the email is only kept for display because the user can change it.
    """

    __tablename__ = "oauth_accounts"
    __table_args__ = (UniqueConstraint("provider", "provider_user_id"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(20))  # "google" | "github"
    provider_user_id: Mapped[str] = mapped_column(String(255))
    email: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class DeviceToken(Base):
    """FCM token of one device. Only stored for now; push sending comes later."""

    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True)
    platform: Mapped[str] = mapped_column(String(20))  # "android" | "ios" | "web"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
