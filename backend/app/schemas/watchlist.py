"""Schemas for /watchlist (notifications feature)."""

from datetime import datetime

from pydantic import BaseModel

from app.schemas.repo_brief import RepoBrief


class LatestReleaseOut(BaseModel):
    tag_name: str
    published_at: datetime | None


class WatchlistItemOut(BaseModel):
    repo: RepoBrief
    watched_at: datetime
    latest_release: LatestReleaseOut | None  # null until the release check has seen one
