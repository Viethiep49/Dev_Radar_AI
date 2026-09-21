"""Statistics for the personal dashboard (charts in the app).

Everything is read from the DB and counted in Python, so the same code works on
PostgreSQL and SQLite (no DB-specific date functions).
Every function takes an optional `now` so tests can use a fixed date.
"""

from collections import Counter
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.base import utcnow
from app.models import Collection, Note, Repo, UserRepo
from app.models.personal import LEARNING_STATUSES


def _as_utc(value: datetime) -> datetime:
    """SQLite returns datetimes without timezone; treat them as UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def week_start(value: datetime) -> date:
    """Monday (UTC) of the week that contains `value`."""
    day = _as_utc(value).date()
    return day - timedelta(days=day.weekday())  # weekday(): Monday = 0


def _user_repos(db: Session, user_id: int) -> list[UserRepo]:
    return list(db.scalars(select(UserRepo).where(UserRepo.user_id == user_id)))


def get_overview(db: Session, user_id: int, now: datetime | None = None) -> dict:
    if now is None:
        now = utcnow()
    rows = _user_repos(db, user_id)

    # Start with 0 for every status so the app always gets all three keys.
    by_status = {status: 0 for status in LEARNING_STATUSES}
    for row in rows:
        by_status[row.status] += 1

    this_week = week_start(now)
    completed_this_week = sum(
        1 for row in rows if row.completed_at is not None and week_start(row.completed_at) == this_week
    )

    collections_count = db.scalar(select(func.count()).where(Collection.user_id == user_id))
    notes_count = db.scalar(select(func.count()).where(Note.user_id == user_id))

    return {
        "total_repos": len(rows),
        "by_status": by_status,
        "collections_count": collections_count,
        "notes_count": notes_count,
        "completed_this_week": completed_this_week,
    }


def get_weekly(db: Session, user_id: int, weeks: int = 8, now: datetime | None = None) -> list[dict]:
    """Repos started / completed per week for the last `weeks` weeks (oldest first).

    Weeks without activity are included with 0, so the chart has no gaps.
    """
    if now is None:
        now = utcnow()

    # e.g. weeks=3 -> [Monday 2 weeks ago, Monday last week, Monday this week]
    current = week_start(now)
    mondays = [current - timedelta(weeks=i) for i in range(weeks - 1, -1, -1)]
    result = {monday: {"week_start": monday, "completed": 0, "started": 0} for monday in mondays}

    for row in _user_repos(db, user_id):
        if row.started_at is not None:
            monday = week_start(row.started_at)
            if monday in result:  # ignore dates outside the requested weeks
                result[monday]["started"] += 1
        if row.completed_at is not None:
            monday = week_start(row.completed_at)
            if monday in result:
                result[monday]["completed"] += 1

    return [result[monday] for monday in mondays]


def get_languages(db: Session, user_id: int) -> list[dict]:
    """How many of the user's repos use each language (for the pie chart), biggest first.

    Repos without a language are counted as "Other".
    """
    stmt = select(Repo.language).join(UserRepo, UserRepo.repo_id == Repo.id).where(UserRepo.user_id == user_id)
    counter = Counter(language or "Other" for language in db.scalars(stmt))

    # Sort by count (desc), then by name so the order is always the same.
    ordered = sorted(counter.items(), key=lambda pair: (-pair[1], pair[0]))
    return [{"language": language, "count": count} for language, count in ordered]
