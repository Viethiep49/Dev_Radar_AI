"""Business logic for repos. get_repo_or_404 is shared by every feature; the rest is filled by the repos feature."""

from collections import Counter
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import String, cast, func, or_, select
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.pagination import PageParams, paginate
from app.db.base import utcnow
from app.models import (
    Collection,
    CollectionItem,
    Repo,
    RepoStarSnapshot,
    RepoSummary,
    User,
    UserPreference,
    UserRepo,
    Watchlist,
)
from app.schemas.repos import RepoDetailOut, RepoOut, RepoSummaryOut, StarPoint

# "Hot" label: many new stars this week, or a young repo that is already popular.
HOT_MIN_STARS_GAINED_7D = 100
HOT_NEW_REPO_DAYS = 30
HOT_NEW_REPO_MIN_STARS = 500

TOP_TOPICS_LIMIT = 50

# SQL order of each sort option ("trending" is sorted in Python, see _trending_page).
SORT_ORDERS = {
    "stars": [Repo.stars.desc()],
    "updated": [Repo.github_pushed_at.desc().nulls_last()],
    "newest": [Repo.github_created_at.desc().nulls_last()],
}


def get_repo_or_404(db: Session, repo_id: int) -> Repo:
    """Return the repo or raise NOT_FOUND (uniform error format)."""
    repo = db.get(Repo, repo_id)
    if repo is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "Không tìm thấy repo")
    return repo


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
def as_utc(value: datetime | None) -> datetime | None:
    """SQLite gives back naive datetimes: treat them as UTC so comparisons work on both DBs."""
    if value is None or value.tzinfo is not None:
        return value
    return value.replace(tzinfo=timezone.utc)


def today_utc() -> date:
    return utcnow().date()


def has_topic(topic: str):
    """SQL condition "repo has this topic", portable between SQLite and PostgreSQL.

    Repo.topics is a JSON list stored as text like ["flutter", "dart"], so we look for "flutter"
    (with the quotes) inside that text.
    """
    return cast(Repo.topics, String).contains(f'"{topic.strip().lower()}"', autoescape=True)


# ---------------------------------------------------------------------------
# Trending: stars gained in the last 7 days + "hot" label
# ---------------------------------------------------------------------------
def stars_gained_7d(db: Session, repos: list[Repo]) -> dict[int, int]:
    """Return {repo_id: stars gained}: current stars minus the snapshot closest to 7 days ago.

    Only snapshots from the last 14 days (before today) are used; no snapshot -> 0.
    """
    if not repos:
        return {}
    today = today_utc()
    target = today - timedelta(days=7)
    rows = db.execute(
        select(RepoStarSnapshot.repo_id, RepoStarSnapshot.date, RepoStarSnapshot.stars).where(
            RepoStarSnapshot.repo_id.in_([repo.id for repo in repos]),
            RepoStarSnapshot.date >= today - timedelta(days=14),
            RepoStarSnapshot.date < today,
        )
    ).all()

    # For each repo keep the snapshot nearest to the target day (on a tie, the older one).
    baseline: dict[int, tuple] = {}
    for repo_id, snapshot_date, stars in rows:
        distance = (abs((snapshot_date - target).days), snapshot_date)
        if repo_id not in baseline or distance < baseline[repo_id][0]:
            baseline[repo_id] = (distance, stars)

    return {repo.id: repo.stars - baseline[repo.id][1] if repo.id in baseline else 0 for repo in repos}


def is_hot(repo: Repo, gained_7d: int) -> bool:
    if gained_7d >= HOT_MIN_STARS_GAINED_7D:
        return True
    created_at = as_utc(repo.github_created_at)
    is_new = created_at is not None and created_at >= utcnow() - timedelta(days=HOT_NEW_REPO_DAYS)
    return is_new and repo.stars >= HOT_NEW_REPO_MIN_STARS


def to_repo_out(repo: Repo, gained_7d: int) -> RepoOut:
    out = RepoOut.model_validate(repo)
    return out.model_copy(update={"stars_gained_7d": gained_7d, "is_hot": is_hot(repo, gained_7d)})


def to_repo_outs(db: Session, repos: list[Repo]) -> list[RepoOut]:
    gains = stars_gained_7d(db, repos)
    return [to_repo_out(repo, gains[repo.id]) for repo in repos]


def _trending_page(db: Session, stmt, params: PageParams) -> dict:
    """Load all repos matching stmt, sort by stars gained (then stars) in Python, return one page.

    Fine for a few thousand repos, and it works the same on SQLite and PostgreSQL.
    """
    repos = db.scalars(stmt).all()
    gains = stars_gained_7d(db, repos)
    repos = sorted(repos, key=lambda repo: (-gains[repo.id], -repo.stars, repo.id))
    page_repos = repos[params.offset : params.offset + params.limit]
    return {
        "items": [to_repo_out(repo, gains[repo.id]) for repo in page_repos],
        "page": params.page,
        "limit": params.limit,
        "total": len(repos),
    }


# ---------------------------------------------------------------------------
# Feed, search, filters
# ---------------------------------------------------------------------------
def get_feed(db: Session, user: User, params: PageParams) -> dict:
    """Repos matching the user's languages OR topics (all repos if no preference), trending first."""
    rows = db.scalars(select(UserPreference).where(UserPreference.user_id == user.id)).all()
    languages = [row.value.lower() for row in rows if row.kind == "language"]
    topics = [row.value for row in rows if row.kind == "topic"]

    conditions = [has_topic(topic) for topic in topics]
    if languages:
        conditions.append(func.lower(Repo.language).in_(languages))

    stmt = select(Repo)
    if conditions:
        stmt = stmt.where(or_(*conditions))
    return _trending_page(db, stmt, params)


def search_repos(
    db: Session,
    params: PageParams,
    q: str | None = None,
    language: str | None = None,
    topic: str | None = None,
    sort: str = "stars",
) -> dict:
    stmt = select(Repo)
    if q and q.strip():
        text = q.strip()
        stmt = stmt.where(
            or_(
                Repo.full_name.icontains(text, autoescape=True),
                Repo.description.icontains(text, autoescape=True),
            )
        )
    if language and language.strip():
        stmt = stmt.where(func.lower(Repo.language) == language.strip().lower())
    if topic and topic.strip():
        stmt = stmt.where(has_topic(topic))

    if sort == "trending":
        return _trending_page(db, stmt, params)

    stmt = stmt.order_by(*SORT_ORDERS[sort], Repo.id)
    page = paginate(db, stmt, params)
    page["items"] = to_repo_outs(db, page["items"])
    return page


def get_filter_options(db: Session) -> dict:
    """Languages (all) and topics (top 50) with the number of repos, for the filter UI."""
    count = func.count(Repo.id)
    language_rows = db.execute(
        select(Repo.language, count)
        .where(Repo.language.is_not(None))
        .group_by(Repo.language)
        .order_by(count.desc(), Repo.language)
    ).all()

    topic_counter = Counter()
    for topics in db.scalars(select(Repo.topics)):
        topic_counter.update(set(topics or []))
    top_topics = sorted(topic_counter.items(), key=lambda item: (-item[1], item[0]))[:TOP_TOPICS_LIMIT]

    return {
        "languages": [{"name": name, "count": n} for name, n in language_rows],
        "topics": [{"name": name, "count": n} for name, n in top_topics],
    }


# ---------------------------------------------------------------------------
# Detail, summary, star history
# ---------------------------------------------------------------------------
def get_repo_detail(db: Session, user: User, repo_id: int) -> RepoDetailOut:
    repo = get_repo_or_404(db, repo_id)
    base = to_repo_out(repo, stars_gained_7d(db, [repo])[repo.id])

    summary = db.scalar(select(RepoSummary).where(RepoSummary.repo_id == repo.id))
    watch_id = db.scalar(
        select(Watchlist.id).where(Watchlist.user_id == user.id, Watchlist.repo_id == repo.id)
    )
    learning_status = db.scalar(
        select(UserRepo.status).where(UserRepo.user_id == user.id, UserRepo.repo_id == repo.id)
    )
    collection_ids = db.scalars(
        select(Collection.id)
        .join(CollectionItem, CollectionItem.collection_id == Collection.id)
        .where(Collection.user_id == user.id, CollectionItem.repo_id == repo.id)
        .order_by(Collection.id)
    ).all()

    return RepoDetailOut(
        **base.model_dump(),
        readme_available=bool(repo.readme and repo.readme.strip()),
        summary=RepoSummaryOut.model_validate(summary) if summary else None,
        is_watched=watch_id is not None,
        learning_status=learning_status,
        collection_ids=list(collection_ids),
    )


def get_summary_or_404(db: Session, repo_id: int) -> RepoSummary:
    repo = get_repo_or_404(db, repo_id)
    summary = db.scalar(select(RepoSummary).where(RepoSummary.repo_id == repo.id))
    if summary is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "Chưa có tóm tắt AI cho repo này")
    return summary


def get_star_history(db: Session, repo_id: int, days: int) -> list[StarPoint]:
    """Star snapshots of the last `days` days (today included), oldest first."""
    repo = get_repo_or_404(db, repo_id)
    start = today_utc() - timedelta(days=days - 1)
    snapshots = db.scalars(
        select(RepoStarSnapshot)
        .where(RepoStarSnapshot.repo_id == repo.id, RepoStarSnapshot.date >= start)
        .order_by(RepoStarSnapshot.date)
    ).all()
    return [StarPoint(date=snapshot.date, stars=snapshot.stars) for snapshot in snapshots]


# ---------------------------------------------------------------------------
# Saving GitHub data (used by the cron jobs)
# ---------------------------------------------------------------------------
def parse_github_datetime(value: str | None) -> datetime | None:
    """GitHub sends "2024-05-01T10:00:00Z"."""
    if not value:
        return None
    return as_utc(datetime.fromisoformat(value.replace("Z", "+00:00")))


def apply_github_data(repo: Repo, data: dict) -> None:
    """Copy the fields of a GitHub repo JSON (search item or /repos/{name}) onto a Repo row."""
    owner = data.get("owner") or {}
    license_id = (data.get("license") or {}).get("spdx_id")
    repo.github_id = data["id"]
    repo.full_name = data["full_name"]
    repo.owner = owner.get("login") or data["full_name"].split("/")[0]
    repo.name = data["name"]
    repo.description = data.get("description")
    repo.html_url = data["html_url"]
    homepage = data.get("homepage")
    repo.homepage = homepage[:500] if homepage else None  # GitHub may send "" for no homepage
    repo.language = data.get("language")
    repo.topics = data.get("topics") or []
    repo.stars = data.get("stargazers_count", 0)
    repo.forks = data.get("forks_count", 0)
    repo.open_issues = data.get("open_issues_count", 0)
    repo.license = license_id if license_id and license_id != "NOASSERTION" else None
    repo.owner_avatar_url = owner.get("avatar_url")
    repo.github_created_at = parse_github_datetime(data.get("created_at"))
    repo.github_pushed_at = parse_github_datetime(data.get("pushed_at"))
    repo.fetched_at = utcnow()


def find_repo(db: Session, github_id: int, full_name: str) -> Repo | None:
    """Find a repo by github_id, or by full_name (e.g. a seeded repo with a placeholder github_id)."""
    repo = db.scalar(select(Repo).where(Repo.github_id == github_id))
    if repo is None:
        repo = db.scalar(select(Repo).where(Repo.full_name == full_name))
    return repo


def upsert_repo_from_github(db: Session, data: dict) -> tuple[Repo, bool]:
    """Insert or update a repo from GitHub JSON.

    Returns (repo, needs_readme): needs_readme is True for a new repo or when pushed_at changed.
    """
    repo = find_repo(db, data["id"], data["full_name"])
    if repo is None:
        repo = Repo()
        db.add(repo)
        needs_readme = True
    else:
        needs_readme = as_utc(repo.github_pushed_at) != parse_github_datetime(data.get("pushed_at"))
    apply_github_data(repo, data)
    db.flush()  # the session has autoflush off: flush so the next find_repo sees this row
    return repo, needs_readme
