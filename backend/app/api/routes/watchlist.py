"""Watchlist (follow / unfollow repo) endpoints."""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams
from app.db.session import get_db
from app.models import User
from app.schemas.watchlist import WatchlistItemOut
from app.services import watchlist_service
from app.services.repo_service import get_repo_or_404

router = APIRouter(prefix="/watchlist", tags=["watchlist"])


@router.get("", response_model=Page[WatchlistItemOut])
def list_watchlist(
    params: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return watchlist_service.list_watchlist(db, current_user.id, params)


@router.post("/{repo_id}", response_model=WatchlistItemOut, status_code=201)
def watch_repo(
    repo_id: int,
    response: Response,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """201 when newly watched, 200 when the repo was already in the watchlist."""
    get_repo_or_404(db, repo_id)
    entry, created = watchlist_service.add(db, current_user.id, repo_id)
    if not created:
        response.status_code = 200
    return watchlist_service.to_item(db, entry)


@router.delete("/{repo_id}", status_code=204)
def unwatch_repo(
    repo_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    watchlist_service.remove(db, current_user.id, repo_id)
    return Response(status_code=204)
