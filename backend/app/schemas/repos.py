"""Schemas for /repos (repos feature)."""

from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class RepoOut(BaseModel):
    """One repo in a list (feed, search). The README text is not included (it can be large)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    github_id: int
    full_name: str
    owner: str
    name: str
    description: str | None
    html_url: str
    homepage: str | None
    language: str | None
    topics: list[str]
    stars: int
    forks: int
    open_issues: int
    license: str | None
    owner_avatar_url: str | None
    github_created_at: datetime | None
    github_pushed_at: datetime | None
    fetched_at: datetime
    # Computed from repo_star_snapshots, not stored on the repo row.
    stars_gained_7d: int = 0
    is_hot: bool = False


class RepoSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    summary: str
    quickstart: str | None
    model: str | None
    created_at: datetime


class RepoDetailOut(RepoOut):
    readme_available: bool
    summary: RepoSummaryOut | None
    # Flags of the logged-in user for this repo
    is_watched: bool
    learning_status: str | None  # "want_to_try" | "learning" | "used" | null
    collection_ids: list[int]


class StarPoint(BaseModel):
    date: date
    stars: int


class FilterCount(BaseModel):
    name: str
    count: int


class FilterOptions(BaseModel):
    languages: list[FilterCount]
    topics: list[FilterCount]
