"""Detect new releases of watched repos and notify their watchers.

For each watched repo we keep the latest release we have seen in repo_releases:
- first time we see a release -> store it as the baseline, no notification
  (otherwise watching a repo would immediately notify about an old release);
- tag changed since last time -> update the row and notify every watcher.
"""

import logging
import time
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.base import utcnow
from app.models import Notification, Repo, RepoRelease, Watchlist
from app.services import github_client, notification_service

logger = logging.getLogger(__name__)

SLEEP_BETWEEN_CALLS = 1.0  # seconds, be gentle with the GitHub rate limit


def _parse_datetime(value: str | None) -> datetime | None:
    """GitHub dates look like "2026-09-21T10:00:00Z"."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def watched_repos(db: Session) -> list[Repo]:
    """Repos that are in at least one user's watchlist."""
    watched_ids = select(Watchlist.repo_id).distinct()
    return list(db.scalars(select(Repo).where(Repo.id.in_(watched_ids)).order_by(Repo.id)).all())


def watcher_ids(db: Session, repo_id: int) -> list[int]:
    return list(db.scalars(select(Watchlist.user_id).where(Watchlist.repo_id == repo_id)).all())


def _save_release(db: Session, repo: Repo, release: dict) -> RepoRelease:
    row = db.scalar(select(RepoRelease).where(RepoRelease.repo_id == repo.id))
    if row is None:
        row = RepoRelease(repo_id=repo.id)
        db.add(row)
    row.tag_name = release["tag_name"]
    row.name = release.get("name")
    row.html_url = release.get("html_url")
    row.published_at = _parse_datetime(release.get("published_at"))
    row.checked_at = utcnow()
    return row


def notify_new_release(db: Session, repo: Repo, release: dict) -> list[Notification]:
    """Save the release and create one notification per watcher (then "push" them)."""
    _save_release(db, repo, release)
    tag_name = release["tag_name"]
    notifications = []
    for user_id in watcher_ids(db, repo.id):
        notification = notification_service.create(
            db,
            user_id=user_id,
            type="release",
            title=f"{repo.full_name} vừa phát hành {tag_name}",
            body=release.get("name") or "Có phiên bản mới",
            repo_id=repo.id,
            data={"tag_name": tag_name, "html_url": release.get("html_url")},
        )
        notifications.append(notification)
    db.commit()

    for notification in notifications:
        notification_service.send_push(notification)
    return notifications


def process_release(db: Session, repo: Repo, release: dict | None) -> list[Notification]:
    """Compare the release from GitHub with the one we stored. Returns the new notifications."""
    if release is None or not release.get("tag_name"):
        return []  # repo has no release

    row = db.scalar(select(RepoRelease).where(RepoRelease.repo_id == repo.id))
    if row is None:
        _save_release(db, repo, release)  # baseline, no notification
        db.commit()
        return []
    if row.tag_name == release["tag_name"]:
        row.checked_at = utcnow()
        db.commit()
        return []
    return notify_new_release(db, repo, release)


def check_releases(db: Session, sleep_seconds: float = SLEEP_BETWEEN_CALLS) -> int:
    """Check every watched repo. Returns how many notifications were created.

    A repo failing (GitHub error, bad data) is logged and skipped.
    """
    created = 0
    for i, repo in enumerate(watched_repos(db)):
        if i > 0 and sleep_seconds:
            time.sleep(sleep_seconds)
        try:
            # Module attribute looked up at call time (easy to monkeypatch in tests).
            release = github_client.get_latest_release(repo.full_name)
            created += len(process_release(db, repo, release))
        except (github_client.GitHubError, KeyError, TypeError) as exc:
            db.rollback()
            logger.warning("Could not check releases of %s: %s", repo.full_name, exc)
    return created
