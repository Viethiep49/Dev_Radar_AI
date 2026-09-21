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
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

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


class DeviceToken(Base):
    """FCM token of one device. Only stored for now; push sending comes later."""

    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True)
    platform: Mapped[str] = mapped_column(String(20))  # "android" | "ios" | "web"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
