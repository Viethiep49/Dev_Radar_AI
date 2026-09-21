"""Tests for the repos cron jobs, the seed and scripts/run_job (GitHub is always faked)."""

from datetime import timedelta

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import sessionmaker

from app.db.base import utcnow
from app.jobs import repo_jobs
from app.models import Collection, CollectionItem, Repo, RepoStarSnapshot, User, UserPreference, Watchlist
from app.services import github_client
from app.services.github_client import GitHubError
from app.services.repo_service import today_utc
from scripts import run_job, seed


def github_item(github_id: int, full_name: str, stars: int = 100, pushed_at: str = "2026-09-01T10:00:00Z") -> dict:
    """A (short) GitHub search item."""
    owner, name = full_name.split("/")
    return {
        "id": github_id,
        "full_name": full_name,
        "name": name,
        "owner": {"login": owner, "avatar_url": f"https://avatars.example/{owner}.png"},
        "description": f"{name} description",
        "html_url": f"https://github.com/{full_name}",
        "homepage": "",
        "language": "Python",
        "topics": ["ai", "llm"],
        "stargazers_count": stars,
        "forks_count": 5,
        "open_issues_count": 2,
        "license": {"spdx_id": "MIT"},
        "created_at": "2026-09-01T00:00:00Z",
        "pushed_at": pushed_at,
    }


def count(db, model) -> int:
    return db.scalar(select(func.count()).select_from(model))


@pytest.fixture
def no_sleep(monkeypatch):
    monkeypatch.setattr(repo_jobs.time, "sleep", lambda seconds: None)


class FakeGitHub:
    """Replaces the github_client functions; `results` maps a query prefix to items (or an exception)."""

    def __init__(self, monkeypatch, results: dict):
        self.results = results
        self.searches = []
        self.readmes = []
        monkeypatch.setattr(github_client, "search_repositories", self.search_repositories)
        monkeypatch.setattr(github_client, "get_readme", self.get_readme)

    def search_repositories(self, query, sort="stars", per_page=30, page=1):
        self.searches.append(query)
        for prefix, result in self.results.items():
            if query.startswith(prefix):
                if isinstance(result, Exception):
                    raise result
                return result
        return []

    def get_readme(self, full_name):
        self.readmes.append(full_name)
        return f"# {full_name}"


# ---------------------------------------------------------------------------
# fetch_trending
# ---------------------------------------------------------------------------
def test_trending_queries_include_user_languages(db, user):
    db.add(UserPreference(user_id=user.id, kind="language", value="Dart"))
    db.add(UserPreference(user_id=user.id, kind="language", value="Jupyter Notebook"))
    db.commit()

    queries = repo_jobs.trending_queries(db)
    since = (utcnow() - timedelta(days=30)).date().isoformat()
    assert queries[0] == f"topic:flutter created:>{since}"
    assert len(queries) == len(repo_jobs.CATEGORIES) + 2
    assert f'language:"Jupyter Notebook" created:>{since}' in queries


def test_fetch_trending_inserts_and_updates(db, monkeypatch, no_sleep):
    fake = FakeGitHub(
        monkeypatch,
        {
            "topic:ai": [github_item(1, "a/one", stars=100), github_item(2, "b/two")],
            "topic:llm": [github_item(1, "a/one", stars=100)],  # same repo in two categories
        },
    )

    stats = repo_jobs.fetch_trending(db)

    assert stats == {"queries": len(repo_jobs.CATEGORIES), "repos": 3, "new": 2, "readmes": 2}
    assert count(db, Repo) == 2
    assert sorted(fake.readmes) == ["a/one", "b/two"]
    repo = db.scalar(select(Repo).where(Repo.github_id == 1))
    assert repo.owner == "a"
    assert repo.stars == 100
    assert repo.topics == ["ai", "llm"]
    assert repo.license == "MIT"
    assert repo.homepage is None
    assert repo.readme == "# a/one"

    # Second run: stars changed, pushed_at unchanged for one/changed for two.
    fake.results = {
        "topic:ai": [
            github_item(1, "a/one", stars=250),
            github_item(2, "b/two", pushed_at="2026-09-10T10:00:00Z"),
        ]
    }
    fake.readmes.clear()
    stats = repo_jobs.fetch_trending(db)

    assert stats["new"] == 0
    assert count(db, Repo) == 2
    db.refresh(repo)
    assert repo.stars == 250
    assert fake.readmes == ["b/two"]  # only the repo that was pushed again


def test_fetch_trending_matches_seeded_repo_by_full_name(db, monkeypatch, no_sleep):
    db.add(Repo(github_id=900000001, full_name="a/one", owner="a", name="one", html_url="x", stars=1))
    db.commit()
    FakeGitHub(monkeypatch, {"topic:ai": [github_item(1, "a/one", stars=999)]})

    repo_jobs.fetch_trending(db)

    repo = db.scalar(select(Repo))
    assert count(db, Repo) == 1
    assert (repo.github_id, repo.stars) == (1, 999)


def test_fetch_trending_caps_readme_fetches(db, monkeypatch, no_sleep):
    items = [github_item(i, f"owner/repo{i}") for i in range(1, 26)]
    fake = FakeGitHub(monkeypatch, {"topic:ai": items})

    stats = repo_jobs.fetch_trending(db)

    assert count(db, Repo) == 25
    assert len(fake.readmes) == repo_jobs.MAX_README_FETCHES == stats["readmes"]


def test_fetch_trending_stops_on_rate_limit(db, monkeypatch, no_sleep):
    fake = FakeGitHub(
        monkeypatch,
        {
            "topic:flutter": [github_item(1, "a/one")],
            "topic:dart": GitHubError("rate limit", rate_limited=True),
        },
    )

    stats = repo_jobs.fetch_trending(db)

    assert len(fake.searches) == 2  # stopped after the rate limit
    assert stats["queries"] == 1
    db.rollback()  # data of the first query was committed
    assert count(db, Repo) == 1


def test_fetch_trending_skips_other_errors(db, monkeypatch, no_sleep):
    fake = FakeGitHub(monkeypatch, {"topic:flutter": GitHubError("GitHub returned 502")})

    stats = repo_jobs.fetch_trending(db)

    assert len(fake.searches) == len(repo_jobs.CATEGORIES)
    assert stats["queries"] == len(repo_jobs.CATEGORIES) - 1


# ---------------------------------------------------------------------------
# refresh_tracked
# ---------------------------------------------------------------------------
def test_refresh_tracked(db, user, monkeypatch, no_sleep):
    old = utcnow() - timedelta(hours=13)
    stale = Repo(github_id=1, full_name="a/stale", owner="a", name="stale", html_url="x", stars=1, fetched_at=old)
    fresh = Repo(github_id=2, full_name="a/fresh", owner="a", name="fresh", html_url="x", stars=1)
    untracked = Repo(github_id=3, full_name="a/untracked", owner="a", name="untracked", html_url="x", fetched_at=old)
    gone = Repo(github_id=4, full_name="a/gone", owner="a", name="gone", html_url="x", stars=7, fetched_at=old)
    db.add_all([stale, fresh, untracked, gone])
    db.flush()
    collection = Collection(user_id=user.id, name="C")
    db.add(collection)
    db.flush()
    db.add_all(
        [
            Watchlist(user_id=user.id, repo_id=stale.id),
            Watchlist(user_id=user.id, repo_id=fresh.id),
            CollectionItem(collection_id=collection.id, repo_id=gone.id),
        ]
    )
    db.commit()

    asked = []

    def fake_get_repo(full_name):
        asked.append(full_name)
        return github_item(1, "a/stale", stars=500) if full_name == "a/stale" else None

    monkeypatch.setattr(github_client, "get_repo", fake_get_repo)

    stats = repo_jobs.refresh_tracked(db)

    assert sorted(asked) == ["a/gone", "a/stale"]
    assert stats == {"checked": 2, "updated": 1, "missing": 1}
    db.refresh(stale)
    db.refresh(gone)
    assert stale.stars == 500
    assert gone.stars == 7  # unchanged, only fetched_at moved
    assert repo_jobs.refresh_tracked(db)["checked"] == 0  # nothing stale any more


# ---------------------------------------------------------------------------
# snapshot_stars
# ---------------------------------------------------------------------------
def test_snapshot_stars_is_idempotent(db):
    repo = Repo(github_id=1, full_name="a/a", owner="a", name="a", html_url="x", stars=10)
    db.add_all([repo, Repo(github_id=2, full_name="b/b", owner="b", name="b", html_url="x", stars=20)])
    db.commit()

    assert repo_jobs.snapshot_stars(db) == {"created": 2, "updated": 0}
    db.commit()
    repo.stars = 15
    db.commit()
    assert repo_jobs.snapshot_stars(db) == {"created": 0, "updated": 2}
    db.commit()

    assert count(db, RepoStarSnapshot) == 2
    snapshot = db.scalar(select(RepoStarSnapshot).where(RepoStarSnapshot.repo_id == repo.id))
    assert (snapshot.date, snapshot.stars) == (today_utc(), 15)


def test_job_wrapper_opens_session_and_commits(db, monkeypatch):
    db.add(Repo(github_id=1, full_name="a/a", owner="a", name="a", html_url="x", stars=10))
    db.commit()
    monkeypatch.setattr(repo_jobs, "SessionLocal", sessionmaker(bind=db.get_bind(), autoflush=False))

    repo_jobs.snapshot_stars_job()

    assert count(db, RepoStarSnapshot) == 1


def test_job_wrapper_never_raises():
    def broken(db):
        raise RuntimeError("boom")

    repo_jobs.run_in_session("broken", broken)  # must not raise


def test_jobs_registered():
    ids = [job["id"] for job in repo_jobs.JOBS]
    assert ids == ["fetch_trending", "refresh_tracked", "snapshot_stars"]


# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------
def test_seed_repos_is_idempotent(db):
    seed.seed_repos(db)
    db.commit()
    repos = count(db, Repo)
    snapshots = count(db, RepoStarSnapshot)
    assert repos >= 25
    assert snapshots == repos * seed.SEED_HISTORY_DAYS

    seed.seed_repos(db)
    db.commit()
    assert count(db, Repo) == repos
    assert count(db, RepoStarSnapshot) == snapshots

    flutter = db.scalar(select(Repo).where(Repo.full_name == "flutter/flutter"))
    assert flutter.readme
    history = db.scalars(
        select(RepoStarSnapshot).where(RepoStarSnapshot.repo_id == flutter.id).order_by(RepoStarSnapshot.date)
    ).all()
    assert history[-1].date == today_utc()
    assert history[-1].stars == flutter.stars
    assert history[0].stars < flutter.stars


def test_seed_keeps_real_github_data(db):
    seed.seed_repos(db)
    db.commit()
    flutter = db.scalar(select(Repo).where(Repo.full_name == "flutter/flutter"))
    flutter.github_id = 14101776  # as if fetch_trending saved the real repo
    flutter.stars = 123456
    db.commit()

    seed.seed_repos(db)
    db.commit()
    db.refresh(flutter)
    assert flutter.stars == 123456


def test_seed_main_seeds_everything(db, monkeypatch):
    monkeypatch.setattr(seed, "SessionLocal", sessionmaker(bind=db.get_bind(), autoflush=False))
    seed.main()
    assert count(db, User) == 1
    assert count(db, Repo) >= 25


# ---------------------------------------------------------------------------
# scripts/run_job
# ---------------------------------------------------------------------------
def test_run_job_list_and_run(monkeypatch, capsys):
    calls = []
    monkeypatch.setattr(
        repo_jobs, "JOBS", [{"id": "dummy", "func": lambda: calls.append(1), "trigger": "interval", "kwargs": {}}]
    )

    assert run_job.main(["--list"]) == 0
    assert "dummy" in capsys.readouterr().out

    assert run_job.main(["dummy"]) == 0
    assert calls == [1]

    assert run_job.main(["nope"]) == 1
    assert run_job.main([]) == 1
