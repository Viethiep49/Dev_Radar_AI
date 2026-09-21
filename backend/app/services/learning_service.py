"""Business logic for the learning status of repos (table user_repos)."""

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.pagination import PageParams, paginate
from app.db.base import utcnow
from app.models import UserRepo
from app.services.repo_service import get_repo_or_404


def get_user_repo_or_404(db: Session, user_id: int, repo_id: int) -> UserRepo:
    row = db.scalar(select(UserRepo).where(UserRepo.user_id == user_id, UserRepo.repo_id == repo_id))
    if row is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "This repo has no learning status")
    return row


def list_learning(db: Session, user_id: int, params: PageParams, status: str | None = None) -> dict:
    """One page of the user's repos with a learning status, newest updated first."""
    stmt = select(UserRepo).where(UserRepo.user_id == user_id)
    if status is not None:
        stmt = stmt.where(UserRepo.status == status)
    stmt = stmt.order_by(UserRepo.updated_at.desc(), UserRepo.id.desc())
    return paginate(db, stmt, params)


def apply_status(row: UserRepo, new_status: str, now: datetime) -> None:
    """Change row.status and keep started_at / completed_at correct.

    Rules (they feed the weekly statistics chart):
    1. -> "learning": started_at = now, but only if it was never set
       (the first time the user started learning is kept).
    2. -> "used": completed_at = now, and started_at = now if it was never set
       (a repo marked "used" directly counts as started and finished now).
       If the repo was already "used", completed_at is kept (nothing changed).
    3. -> any status other than "used": completed_at is cleared
       (the repo is no longer finished, e.g. "used" -> "learning").
    4. updated_at is always set to now.
    """
    if new_status == "used":
        if row.status != "used":
            row.completed_at = now
        if row.started_at is None:
            row.started_at = now
    else:
        row.completed_at = None
        if new_status == "learning" and row.started_at is None:
            row.started_at = now

    row.status = new_status
    row.updated_at = now


def set_status(db: Session, user_id: int, repo_id: int, status: str, now: datetime | None = None) -> UserRepo:
    """Create or update the learning status of one repo (upsert)."""
    if now is None:
        now = utcnow()
    get_repo_or_404(db, repo_id)

    row = db.scalar(select(UserRepo).where(UserRepo.user_id == user_id, UserRepo.repo_id == repo_id))
    if row is None:
        row = UserRepo(user_id=user_id, repo_id=repo_id)
        db.add(row)

    apply_status(row, status, now)
    db.commit()
    db.refresh(row)
    return row


def delete_status(db: Session, user_id: int, repo_id: int) -> None:
    row = get_user_repo_or_404(db, user_id, repo_id)
    db.delete(row)
    db.commit()
