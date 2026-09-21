"""Tests for /watchlist."""

from datetime import datetime, timezone

from app.core.security import create_access_token
from app.models import Repo, RepoRelease, User


def make_repo(db, n):
    repo = Repo(
        github_id=n,
        full_name=f"owner/repo{n}",
        owner="owner",
        name=f"repo{n}",
        html_url=f"https://github.com/owner/repo{n}",
        stars=n,
    )
    db.add(repo)
    db.commit()
    return repo


def test_add_is_idempotent(client, db, auth_headers):
    repo = make_repo(db, 1)

    first = client.post(f"/api/v1/watchlist/{repo.id}", headers=auth_headers)
    assert first.status_code == 201
    assert first.json()["repo"]["full_name"] == "owner/repo1"
    assert first.json()["latest_release"] is None

    again = client.post(f"/api/v1/watchlist/{repo.id}", headers=auth_headers)
    assert again.status_code == 200
    assert again.json()["watched_at"] == first.json()["watched_at"]

    assert client.get("/api/v1/watchlist", headers=auth_headers).json()["total"] == 1


def test_add_unknown_repo(client, auth_headers):
    response = client.post("/api/v1/watchlist/999", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"


def test_list_with_latest_release(client, db, auth_headers):
    repo1 = make_repo(db, 1)
    repo2 = make_repo(db, 2)
    db.add(
        RepoRelease(repo_id=repo1.id, tag_name="v1.2.0", published_at=datetime(2026, 9, 1, tzinfo=timezone.utc))
    )
    db.commit()
    client.post(f"/api/v1/watchlist/{repo1.id}", headers=auth_headers)
    client.post(f"/api/v1/watchlist/{repo2.id}", headers=auth_headers)

    body = client.get("/api/v1/watchlist", headers=auth_headers).json()
    assert body["total"] == 2
    by_name = {item["repo"]["full_name"]: item for item in body["items"]}
    assert by_name["owner/repo1"]["latest_release"]["tag_name"] == "v1.2.0"
    assert by_name["owner/repo1"]["latest_release"]["published_at"].startswith("2026-09-01")
    assert by_name["owner/repo2"]["latest_release"] is None
    # Most recently watched first.
    assert body["items"][0]["repo"]["full_name"] == "owner/repo2"


def test_remove(client, db, auth_headers):
    repo = make_repo(db, 1)
    client.post(f"/api/v1/watchlist/{repo.id}", headers=auth_headers)

    assert client.delete(f"/api/v1/watchlist/{repo.id}", headers=auth_headers).status_code == 204
    assert client.get("/api/v1/watchlist", headers=auth_headers).json()["total"] == 0

    again = client.delete(f"/api/v1/watchlist/{repo.id}", headers=auth_headers)
    assert again.status_code == 404
    assert again.json()["error"]["code"] == "NOT_FOUND"


def test_user_isolation(client, db, auth_headers):
    repo = make_repo(db, 1)
    client.post(f"/api/v1/watchlist/{repo.id}", headers=auth_headers)

    other = User(email="other@example.com", password_hash="x", display_name="Other")
    db.add(other)
    db.commit()
    other_headers = {"Authorization": f"Bearer {create_access_token(other.id)}"}

    assert client.get("/api/v1/watchlist", headers=other_headers).json()["total"] == 0
    assert client.delete(f"/api/v1/watchlist/{repo.id}", headers=other_headers).status_code == 404
    assert client.get("/api/v1/watchlist", headers=auth_headers).json()["total"] == 1


def test_requires_auth(client):
    assert client.get("/api/v1/watchlist").status_code == 401
