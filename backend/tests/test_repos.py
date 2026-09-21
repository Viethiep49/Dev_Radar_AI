"""Tests for the /api/v1/repos endpoints."""

import itertools
from datetime import timedelta

import pytest

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
from app.services.repo_service import today_utc

URL = "/api/v1/repos"
_github_ids = itertools.count(1)


def make_repo(db, full_name: str, **fields) -> Repo:
    owner, name = full_name.split("/")
    values = {
        "github_id": next(_github_ids),
        "full_name": full_name,
        "owner": owner,
        "name": name,
        "html_url": f"https://github.com/{full_name}",
        "stars": 10,
        "topics": [],
        "github_created_at": utcnow() - timedelta(days=400),
    }
    values.update(fields)
    repo = Repo(**values)
    db.add(repo)
    db.commit()
    db.refresh(repo)
    return repo


def add_snapshot(db, repo: Repo, days_ago: int, stars: int) -> None:
    db.add(RepoStarSnapshot(repo_id=repo.id, date=today_utc() - timedelta(days=days_ago), stars=stars))
    db.commit()


def names(response) -> list[str]:
    return [item["full_name"] for item in response.json()["items"]]


@pytest.fixture
def sample_repos(db):
    """Three repos with different stars / growth / dates."""
    flutter = make_repo(
        db, "flutter/flutter", language="Dart", topics=["flutter", "dart"], stars=1000,
        description="UI toolkit", github_pushed_at=utcnow() - timedelta(days=5),
    )
    fastapi = make_repo(
        db, "fastapi/fastapi", language="Python", topics=["api", "web"], stars=5000,
        description="Modern web framework", github_pushed_at=utcnow() - timedelta(days=1),
    )
    ollama = make_repo(
        db, "ollama/ollama", language="Go", topics=["llm", "ai"], stars=3000,
        description="Run LLMs locally", github_pushed_at=utcnow() - timedelta(days=10),
        github_created_at=utcnow() - timedelta(days=100),
    )
    add_snapshot(db, flutter, 7, 700)  # +300 in 7 days -> hot
    add_snapshot(db, fastapi, 7, 4990)  # +10
    add_snapshot(db, ollama, 7, 2950)  # +50
    return {"flutter": flutter, "fastapi": fastapi, "ollama": ollama}


# ---------------------------------------------------------------------------
# Feed
# ---------------------------------------------------------------------------
def test_feed_without_preferences_returns_all_by_trending(client, auth_headers, sample_repos):
    response = client.get(f"{URL}/feed", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 3
    assert names(response) == ["flutter/flutter", "ollama/ollama", "fastapi/fastapi"]
    first = body["items"][0]
    assert first["stars_gained_7d"] == 300
    assert first["is_hot"] is True
    assert body["items"][2]["is_hot"] is False
    assert "readme" not in first


def test_feed_filtered_by_preferences(client, auth_headers, db, user, sample_repos):
    db.add(UserPreference(user_id=user.id, kind="language", value="python"))  # case-insensitive
    db.add(UserPreference(user_id=user.id, kind="topic", value="llm"))
    db.commit()

    response = client.get(f"{URL}/feed", headers=auth_headers)
    assert names(response) == ["ollama/ollama", "fastapi/fastapi"]


def test_feed_pagination(client, auth_headers, sample_repos):
    response = client.get(f"{URL}/feed?page=2&limit=2", headers=auth_headers)
    body = response.json()
    assert body["total"] == 3
    assert body["page"] == 2
    assert names(response) == ["fastapi/fastapi"]


def test_feed_requires_auth(client):
    assert client.get(f"{URL}/feed").status_code == 401


def test_stars_gained_uses_snapshot_closest_to_7_days(client, auth_headers, db):
    repo = make_repo(db, "a/a", stars=500)
    add_snapshot(db, repo, 3, 480)
    add_snapshot(db, repo, 6, 400)  # closest to 7 days ago
    add_snapshot(db, repo, 20, 100)  # too old, ignored
    add_snapshot(db, repo, 0, 500)  # today's snapshot is not a baseline

    item = client.get(f"{URL}/feed", headers=auth_headers).json()["items"][0]
    assert item["stars_gained_7d"] == 100
    assert item["is_hot"] is True


def test_new_popular_repo_is_hot(client, auth_headers, db):
    make_repo(db, "new/popular", stars=800, github_created_at=utcnow() - timedelta(days=10))
    make_repo(db, "new/small", stars=100, github_created_at=utcnow() - timedelta(days=10))
    make_repo(db, "old/popular", stars=800)

    items = client.get(URL, headers=auth_headers).json()["items"]
    hot = {item["full_name"]: item["is_hot"] for item in items}
    assert hot == {"new/popular": True, "new/small": False, "old/popular": False}


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
def test_search_default_sort_by_stars(client, auth_headers, sample_repos):
    response = client.get(URL, headers=auth_headers)
    assert response.status_code == 200
    assert names(response) == ["fastapi/fastapi", "ollama/ollama", "flutter/flutter"]


def test_search_q_matches_name_and_description(client, auth_headers, sample_repos):
    assert names(client.get(f"{URL}?q=FLUTTER", headers=auth_headers)) == ["flutter/flutter"]
    assert names(client.get(f"{URL}?q=llms", headers=auth_headers)) == ["ollama/ollama"]
    # "_" is not a LIKE wildcard: "t_o" must not match "UI toolkit"
    assert names(client.get(URL, params={"q": "t_o"}, headers=auth_headers)) == []


def test_search_language_filter(client, auth_headers, sample_repos):
    assert names(client.get(f"{URL}?language=python", headers=auth_headers)) == ["fastapi/fastapi"]


def test_search_topic_filter(client, auth_headers, db, sample_repos):
    make_repo(db, "x/flutter-like", topics=["flutterish"])  # must not match "flutter"
    assert names(client.get(f"{URL}?topic=Flutter", headers=auth_headers)) == ["flutter/flutter"]
    assert names(client.get(f"{URL}?topic=web", headers=auth_headers)) == ["fastapi/fastapi"]


def test_search_filters_combine(client, auth_headers, sample_repos):
    response = client.get(f"{URL}?q=framework&topic=api&language=Python", headers=auth_headers)
    assert names(response) == ["fastapi/fastapi"]
    assert names(client.get(f"{URL}?q=framework&language=Go", headers=auth_headers)) == []


@pytest.mark.parametrize(
    "sort, expected",
    [
        ("stars", ["fastapi/fastapi", "ollama/ollama", "flutter/flutter"]),
        ("trending", ["flutter/flutter", "ollama/ollama", "fastapi/fastapi"]),
        ("updated", ["fastapi/fastapi", "flutter/flutter", "ollama/ollama"]),
        ("newest", ["ollama/ollama", "fastapi/fastapi", "flutter/flutter"]),
    ],
)
def test_search_sort(client, auth_headers, db, sample_repos, sort, expected):
    # Make "newest" deterministic: fastapi created before ollama but after flutter.
    sample_repos["flutter"].github_created_at = utcnow() - timedelta(days=900)
    sample_repos["fastapi"].github_created_at = utcnow() - timedelta(days=500)
    db.commit()
    assert names(client.get(f"{URL}?sort={sort}", headers=auth_headers)) == expected


def test_search_invalid_sort(client, auth_headers):
    response = client.get(f"{URL}?sort=random", headers=auth_headers)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_search_pagination(client, auth_headers, sample_repos):
    body = client.get(f"{URL}?limit=1&page=2", headers=auth_headers).json()
    assert body["total"] == 3
    assert [item["full_name"] for item in body["items"]] == ["ollama/ollama"]
    assert body["items"][0]["stars_gained_7d"] == 50


# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------
def test_filters(client, auth_headers, db, sample_repos):
    make_repo(db, "other/dart-lib", language="Dart", topics=["dart", "flutter"])
    make_repo(db, "other/no-language", language=None, topics=[])

    body = client.get(f"{URL}/filters", headers=auth_headers).json()
    assert body["languages"] == [
        {"name": "Dart", "count": 2},
        {"name": "Go", "count": 1},
        {"name": "Python", "count": 1},
    ]
    assert body["topics"][:2] == [{"name": "dart", "count": 2}, {"name": "flutter", "count": 2}]
    assert {"name": "llm", "count": 1} in body["topics"]


# ---------------------------------------------------------------------------
# Detail, summary, stars
# ---------------------------------------------------------------------------
def test_detail_without_user_data(client, auth_headers, sample_repos):
    repo = sample_repos["fastapi"]
    response = client.get(f"{URL}/{repo.id}", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "fastapi/fastapi"
    assert body["readme_available"] is False
    assert body["summary"] is None
    assert body["is_watched"] is False
    assert body["learning_status"] is None
    assert body["collection_ids"] == []
    assert body["stars_gained_7d"] == 10


def test_detail_with_user_flags(client, auth_headers, db, user, sample_repos):
    repo = sample_repos["flutter"]
    repo.readme = "# Flutter"
    other = User(email="other@example.com", password_hash="x", display_name="Other")
    db.add(other)
    db.flush()

    mine = Collection(user_id=user.id, name="Mobile")
    empty = Collection(user_id=user.id, name="Empty")
    not_mine = Collection(user_id=other.id, name="Other's")
    db.add_all([mine, empty, not_mine])
    db.flush()
    db.add_all(
        [
            CollectionItem(collection_id=mine.id, repo_id=repo.id),
            CollectionItem(collection_id=not_mine.id, repo_id=repo.id),
            Watchlist(user_id=user.id, repo_id=repo.id),
            UserRepo(user_id=user.id, repo_id=repo.id, status="learning"),
            UserRepo(user_id=other.id, repo_id=sample_repos["fastapi"].id, status="used"),
            RepoSummary(repo_id=repo.id, summary="A UI toolkit", quickstart="flutter create app", model="test-model"),
        ]
    )
    db.commit()

    body = client.get(f"{URL}/{repo.id}", headers=auth_headers).json()
    assert body["readme_available"] is True
    assert body["is_watched"] is True
    assert body["learning_status"] == "learning"
    assert body["collection_ids"] == [mine.id]
    assert body["summary"]["summary"] == "A UI toolkit"
    assert body["summary"]["quickstart"] == "flutter create app"
    assert body["summary"]["model"] == "test-model"

    # Other user's learning status is not visible to us
    other_repo = client.get(f"{URL}/{sample_repos['fastapi'].id}", headers=auth_headers).json()
    assert other_repo["learning_status"] is None


def test_detail_not_found(client, auth_headers):
    response = client.get(f"{URL}/999", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"


def test_summary_missing(client, auth_headers, sample_repos):
    response = client.get(f"{URL}/{sample_repos['flutter'].id}/summary", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["error"] == {
        "code": "NOT_FOUND",
        "message": "Chưa có tóm tắt AI cho repo này",
        "details": None,
    }


def test_summary_present(client, auth_headers, db, sample_repos):
    repo = sample_repos["ollama"]
    db.add(RepoSummary(repo_id=repo.id, summary="Run LLMs locally", quickstart=None, model="m"))
    db.commit()

    response = client.get(f"{URL}/{repo.id}/summary", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["summary"] == "Run LLMs locally"
    assert body["quickstart"] is None
    assert "created_at" in body


def test_summary_unknown_repo(client, auth_headers):
    response = client.get(f"{URL}/999/summary", headers=auth_headers)
    assert response.status_code == 404


def test_star_history(client, auth_headers, db):
    repo = make_repo(db, "a/a", stars=130)
    for days_ago, stars in [(40, 10), (29, 100), (2, 120), (0, 130)]:
        add_snapshot(db, repo, days_ago, stars)

    response = client.get(f"{URL}/{repo.id}/stars", headers=auth_headers)
    assert response.status_code == 200
    today = today_utc()
    assert response.json() == [
        {"date": (today - timedelta(days=29)).isoformat(), "stars": 100},
        {"date": (today - timedelta(days=2)).isoformat(), "stars": 120},
        {"date": today.isoformat(), "stars": 130},
    ]

    short = client.get(f"{URL}/{repo.id}/stars?days=1", headers=auth_headers).json()
    assert short == [{"date": today.isoformat(), "stars": 130}]


def test_star_history_validation(client, auth_headers, db):
    repo = make_repo(db, "a/a")
    assert client.get(f"{URL}/{repo.id}/stars?days=0", headers=auth_headers).status_code == 422
    assert client.get(f"{URL}/{repo.id}/stars?days=366", headers=auth_headers).status_code == 422
    assert client.get(f"{URL}/999/stars", headers=auth_headers).status_code == 404
