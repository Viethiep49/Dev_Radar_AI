"""Cron jobs of the repos feature: fetch trending repos, refresh tracked repos, daily star snapshot.

Each "logic" function takes a db session (easy to test with the `db` fixture) and returns a
small dict of counters. The *_job functions open their own session, commit and never raise.
See app/jobs/scheduler.py for the JOBS format.
"""

import logging
import time
from datetime import timedelta

from sqlalchemy import select, union
from sqlalchemy.orm import Session

from app.db.base import utcnow
from app.db.session import SessionLocal
from app.models import CollectionItem, Repo, RepoStarSnapshot, UserPreference, UserRepo, Watchlist
from app.services import github_client
from app.services.github_client import GitHubError
from app.services.repo_service import apply_github_data, find_repo, today_utc, upsert_repo_from_github

logger = logging.getLogger(__name__)

# Topics always searched by fetch_trending (+ the languages chosen by users).
CATEGORIES = ["flutter", "dart", "ai", "llm", "machine-learning", "web", "react", "python", "devtools", "database"]
TRENDING_WINDOW_DAYS = 30  # only repos created in the last 30 days
SEARCH_PER_PAGE = 30
SEARCH_PAUSE_SECONDS = 2.5  # the Search API allows about 30 requests per minute
MAX_README_FETCHES = 20

REFRESH_AFTER_HOURS = 12
MAX_REFRESH_PER_RUN = 100
REFRESH_PAUSE_SECONDS = 0.5


# ---------------------------------------------------------------------------
# fetch_trending
# ---------------------------------------------------------------------------
def trending_queries(db: Session) -> list[str]:
    since = (utcnow() - timedelta(days=TRENDING_WINDOW_DAYS)).date().isoformat()
    queries = [f"topic:{category} created:>{since}" for category in CATEGORIES]
    languages = db.scalars(
        select(UserPreference.value).where(UserPreference.kind == "language").distinct()
    ).all()
    for language in sorted(set(languages)):
        queries.append(f'language:"{language}" created:>{since}')
    return queries


def fetch_trending(db: Session) -> dict:
    """Search GitHub for new popular repos per category/language and save them (+ some READMEs)."""
    stats = {"queries": 0, "repos": 0, "new": 0, "readmes": 0}
    readme_budget = MAX_README_FETCHES
    for index, query in enumerate(trending_queries(db)):
        if index > 0:
            time.sleep(SEARCH_PAUSE_SECONDS)
        try:
            items = github_client.search_repositories(query, sort="stars", per_page=SEARCH_PER_PAGE)
        except GitHubError as exc:
            if exc.rate_limited:
                logger.warning("fetch_trending: stopping this run, %s", exc)
                break
            logger.warning("fetch_trending: search %r failed: %s", query, exc)
            continue
        stats["queries"] += 1

        for item in items:
            is_new = find_repo(db, item["id"], item["full_name"]) is None
            repo, needs_readme = upsert_repo_from_github(db, item)
            stats["repos"] += 1
            stats["new"] += int(is_new)
            if needs_readme and readme_budget > 0:
                readme_budget -= 1
                try:
                    readme = github_client.get_readme(repo.full_name)
                except GitHubError as exc:
                    logger.warning("fetch_trending: README of %s failed: %s", repo.full_name, exc)
                    if exc.rate_limited:
                        readme_budget = 0  # no more README calls in this run
                    continue
                if readme is not None:
                    repo.readme = readme
                    stats["readmes"] += 1
        db.commit()  # keep what we have so far, even if a later search fails
    return stats


# ---------------------------------------------------------------------------
# refresh_tracked
# ---------------------------------------------------------------------------
def refresh_tracked(db: Session) -> dict:
    """Update stars etc. of repos used by someone (watchlist, collections, learning) that are stale."""
    tracked_ids = union(
        select(Watchlist.repo_id),
        select(CollectionItem.repo_id),
        select(UserRepo.repo_id),
    )
    cutoff = utcnow() - timedelta(hours=REFRESH_AFTER_HOURS)
    repos = db.scalars(
        select(Repo)
        .where(Repo.id.in_(tracked_ids), Repo.fetched_at < cutoff)
        .order_by(Repo.fetched_at)
        .limit(MAX_REFRESH_PER_RUN)
    ).all()

    stats = {"checked": 0, "updated": 0, "missing": 0}
    for index, repo in enumerate(repos):
        if index > 0:
            time.sleep(REFRESH_PAUSE_SECONDS)
        try:
            data = github_client.get_repo(repo.full_name)
        except GitHubError as exc:
            if exc.rate_limited:
                logger.warning("refresh_tracked: stopping this run, %s", exc)
                break
            logger.warning("refresh_tracked: %s failed: %s", repo.full_name, exc)
            continue
        stats["checked"] += 1
        if data is None:
            # Deleted or private now: remember we tried, so it is not retried on every run.
            repo.fetched_at = utcnow()
            stats["missing"] += 1
        else:
            apply_github_data(repo, data)
            stats["updated"] += 1
        db.commit()
    return stats


# ---------------------------------------------------------------------------
# snapshot_stars
# ---------------------------------------------------------------------------
def snapshot_stars(db: Session) -> dict:
    """Save today's star count of every repo. Running it again the same day updates the rows."""
    today = today_utc()
    existing = {
        snapshot.repo_id: snapshot
        for snapshot in db.scalars(select(RepoStarSnapshot).where(RepoStarSnapshot.date == today))
    }
    stats = {"created": 0, "updated": 0}
    for repo_id, stars in db.execute(select(Repo.id, Repo.stars)).all():
        snapshot = existing.get(repo_id)
        if snapshot is None:
            db.add(RepoStarSnapshot(repo_id=repo_id, date=today, stars=stars))
            stats["created"] += 1
        else:
            snapshot.stars = stars
            stats["updated"] += 1
    db.flush()
    return stats


# ---------------------------------------------------------------------------
# Scheduler entry points
# ---------------------------------------------------------------------------
def run_in_session(name: str, logic) -> None:
    """Run logic(db) in its own session, commit, log a one-line summary. Never raises."""
    started = time.monotonic()
    try:
        with SessionLocal() as db:
            stats = logic(db)
            db.commit()
        logger.info("Job %s done in %.1fs: %s", name, time.monotonic() - started, stats)
    except Exception:
        logger.exception("Job %s failed", name)


def fetch_trending_job() -> None:
    run_in_session("fetch_trending", fetch_trending)


def refresh_tracked_job() -> None:
    run_in_session("refresh_tracked", refresh_tracked)


def snapshot_stars_job() -> None:
    run_in_session("snapshot_stars", snapshot_stars)


JOBS: list[dict] = [
    {"id": "fetch_trending", "func": fetch_trending_job, "trigger": "interval", "kwargs": {"hours": 6}},
    {"id": "refresh_tracked", "func": refresh_tracked_job, "trigger": "interval", "kwargs": {"hours": 12}},
    {"id": "snapshot_stars", "func": snapshot_stars_job, "trigger": "cron", "kwargs": {"hour": 0, "minute": 0}},
]
