"""Schemas for /stats (personal feature)."""

from datetime import date

from pydantic import BaseModel


class StatusCounts(BaseModel):
    want_to_try: int
    learning: int
    used: int


class OverviewOut(BaseModel):
    total_repos: int
    by_status: StatusCounts
    collections_count: int
    notes_count: int
    completed_this_week: int


class WeeklyOut(BaseModel):
    week_start: date  # Monday of the week (UTC), e.g. "2026-09-21"
    completed: int
    started: int


class LanguageOut(BaseModel):
    language: str
    count: int
