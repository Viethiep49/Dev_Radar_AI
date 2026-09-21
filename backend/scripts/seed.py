"""Seed demo data. Safe to run many times (idempotent).

Run from the backend/ folder:
    python -m scripts.seed
or inside Docker:
    docker compose exec backend python -m scripts.seed
"""

import json
from datetime import timedelta
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import Repo, RepoStarSnapshot, User, UserPreference
from app.services.repo_service import apply_github_data, find_repo, today_utc

DEMO_EMAIL = "demo@devradar.dev"
DEMO_PASSWORD = "demo1234"
DEMO_LANGUAGES = ["Dart", "Python", "TypeScript"]
DEMO_TOPICS = ["flutter", "ai", "web"]


def seed_demo_user(db: Session) -> User:
    user = db.scalar(select(User).where(User.email == DEMO_EMAIL))
    if user is None:
        user = User(
            email=DEMO_EMAIL,
            password_hash=hash_password(DEMO_PASSWORD),
            display_name="Demo User",
        )
        db.add(user)
        db.flush()  # get user.id without committing yet
        print(f"Created user {DEMO_EMAIL}")
    else:
        print(f"User {DEMO_EMAIL} already exists")
    return user


def seed_preferences(db: Session, user: User) -> None:
    wanted = [("language", value) for value in DEMO_LANGUAGES] + [("topic", value) for value in DEMO_TOPICS]
    for kind, value in wanted:
        exists = db.scalar(
            select(UserPreference).where(
                UserPreference.user_id == user.id,
                UserPreference.kind == kind,
                UserPreference.value == value,
            )
        )
        if exists is None:
            db.add(UserPreference(user_id=user.id, kind=kind, value=value))


# ---------------------------------------------------------------------------
# Demo repos (+ 30 days of synthetic star history so the star chart works offline)
# ---------------------------------------------------------------------------
SEED_REPOS_FILE = Path(__file__).parent / "seed_data" / "repos.json"
SEED_HISTORY_DAYS = 30


def _as_github_json(item: dict) -> dict:
    """Turn one entry of repos.json into the shape of a GitHub API repo JSON."""
    owner, name = item["full_name"].split("/")
    return {
        "id": item["github_id"],
        "full_name": item["full_name"],
        "name": name,
        "owner": {"login": owner, "avatar_url": f"https://github.com/{owner}.png"},
        "description": item["description"],
        "html_url": f"https://github.com/{item['full_name']}",
        "homepage": item["homepage"],
        "language": item["language"],
        "topics": item["topics"],
        "stargazers_count": item["stars"],
        "forks_count": item["forks"],
        "open_issues_count": item["open_issues"],
        "license": {"spdx_id": item["license"]},
        "created_at": item["created_at"],
        "pushed_at": item["pushed_at"],
    }


def seed_star_history(db: Session, repo: Repo, gained_30d: int) -> int:
    """Add missing daily snapshots for the last 30 days: a straight line ending at today's stars."""
    today = today_utc()
    existing_dates = set(
        db.scalars(select(RepoStarSnapshot.date).where(RepoStarSnapshot.repo_id == repo.id))
    )
    added = 0
    for days_ago in range(SEED_HISTORY_DAYS - 1, -1, -1):
        day = today - timedelta(days=days_ago)
        if day in existing_dates:
            continue  # never overwrite a snapshot (it may be a real one from the cron job)
        stars = repo.stars - round(gained_30d * days_ago / (SEED_HISTORY_DAYS - 1))
        db.add(RepoStarSnapshot(repo_id=repo.id, date=day, stars=max(stars, 0)))
        added += 1
    return added


def seed_repos(db: Session) -> None:
    items = json.loads(SEED_REPOS_FILE.read_text(encoding="utf-8"))["repos"]
    created = snapshots = 0
    for item in items:
        data = _as_github_json(item)
        repo = find_repo(db, data["id"], data["full_name"])
        if repo is None:
            repo = Repo()
            db.add(repo)
            apply_github_data(repo, data)
            created += 1
        elif repo.github_id == data["id"]:
            # Still our seed row (never refreshed from GitHub): update it from the file.
            apply_github_data(repo, data)
        # else: the cron job already saved real GitHub data for this repo, keep it.
        if not repo.readme:
            repo.readme = item["readme"]
        db.flush()  # get repo.id
        snapshots += seed_star_history(db, repo, item["stars_gained_30d"])
    print(f"Repos: {created} created, {len(items) - created} already there; {snapshots} star snapshots added")


def main() -> None:
    with SessionLocal() as db:
        user = seed_demo_user(db)
        seed_preferences(db, user)
        seed_repos(db)
        db.commit()
    print("Seed done.")


if __name__ == "__main__":
    main()
