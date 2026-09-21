"""Watchlist: repos a user follows to be notified about new releases."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.pagination import PageParams, paginate
from app.models import RepoRelease, Watchlist


def get_entry(db: Session, user_id: int, repo_id: int) -> Watchlist | None:
    return db.scalar(select(Watchlist).where(Watchlist.user_id == user_id, Watchlist.repo_id == repo_id))


def to_item(db: Session, entry: Watchlist) -> dict:
    """Shape of WatchlistItemOut: repo card + when it was watched + latest known release."""
    release = db.scalar(select(RepoRelease).where(RepoRelease.repo_id == entry.repo_id))
    latest_release = None
    if release is not None:
        latest_release = {"tag_name": release.tag_name, "published_at": release.published_at}
    return {"repo": entry.repo, "watched_at": entry.created_at, "latest_release": latest_release}


def list_watchlist(db: Session, user_id: int, params: PageParams) -> dict:
    """One page of the user's watchlist, most recently watched first."""
    stmt = select(Watchlist).where(Watchlist.user_id == user_id).order_by(Watchlist.id.desc())
    page = paginate(db, stmt, params)
    page["items"] = [to_item(db, entry) for entry in page["items"]]
    return page


def add(db: Session, user_id: int, repo_id: int) -> tuple[Watchlist, bool]:
    """Watch a repo. Returns (entry, created); already watched -> (existing entry, False)."""
    entry = get_entry(db, user_id, repo_id)
    if entry is not None:
        return entry, False
    entry = Watchlist(user_id=user_id, repo_id=repo_id)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry, True


def remove(db: Session, user_id: int, repo_id: int) -> None:
    entry = get_entry(db, user_id, repo_id)
    if entry is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "Repo không có trong danh sách theo dõi")
    db.delete(entry)
    db.commit()
