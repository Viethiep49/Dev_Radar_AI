"""Schemas for /notifications (notifications feature)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str  # e.g. "release"
    title: str
    body: str | None
    repo_id: int | None
    data: dict | None  # "release": {"tag_name", "html_url"}
    is_read: bool
    created_at: datetime


class UnreadCountOut(BaseModel):
    count: int


class ReadAllOut(BaseModel):
    updated: int
