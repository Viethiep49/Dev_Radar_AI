"""Repo feed, search, detail, summary (read from repo_summaries) and star history endpoints."""

from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams
from app.db.session import get_db
from app.models import User
from app.schemas.repos import FilterOptions, RepoDetailOut, RepoOut, RepoSummaryOut, StarPoint
from app.services import repo_service

router = APIRouter(prefix="/repos", tags=["repos"])

# Note: /feed and /filters must be declared before /{repo_id}.


@router.get("/feed", response_model=Page[RepoOut])
def get_feed(
    params: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Repos matching the user's preferences, most trending first."""
    return repo_service.get_feed(db, current_user, params)


@router.get("", response_model=Page[RepoOut])
def search_repos(
    q: str | None = Query(None, max_length=100, description="Text searched in full_name and description"),
    language: str | None = Query(None, max_length=100),
    topic: str | None = Query(None, max_length=100),
    sort: Literal["stars", "trending", "updated", "newest"] = "stars",
    params: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return repo_service.search_repos(db, params, q=q, language=language, topic=topic, sort=sort)


@router.get("/filters", response_model=FilterOptions)
def get_filters(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Languages and top topics with repo counts, for the filter UI."""
    return repo_service.get_filter_options(db)


@router.get("/{repo_id}", response_model=RepoDetailOut)
def get_repo(repo_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return repo_service.get_repo_detail(db, current_user, repo_id)


@router.get("/{repo_id}/summary", response_model=RepoSummaryOut)
def get_summary(repo_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return repo_service.get_summary_or_404(db, repo_id)


@router.get("/{repo_id}/stars", response_model=list[StarPoint])
def get_star_history(
    repo_id: int,
    days: int = Query(30, ge=1, le=365),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Star count per day, oldest first (for the star chart)."""
    return repo_service.get_star_history(db, repo_id, days)
