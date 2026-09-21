from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token, hash_password
from app.models import Repo, User, UserRepo
from app.services import learning_service

URL = "/api/v1/learning"

T1 = datetime(2026, 9, 1, 10, 0, tzinfo=timezone.utc)
T2 = datetime(2026, 9, 5, 10, 0, tzinfo=timezone.utc)
T3 = datetime(2026, 9, 9, 10, 0, tzinfo=timezone.utc)


def assert_error(response, status_code: int, code: str):
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code


def make_repo(db, n: int) -> Repo:
    repo = Repo(
        github_id=1000 + n,
        full_name=f"owner{n}/repo{n}",
        owner=f"owner{n}",
        name=f"repo{n}",
        html_url=f"https://github.com/owner{n}/repo{n}",
        language="Go",
        stars=n,
    )
    db.add(repo)
    db.commit()
    return repo


@pytest.fixture
def other_headers(db) -> dict:
    """Auth headers of a second user (user B)."""
    other = User(email="other@example.com", password_hash=hash_password("secret123"), display_name="B")
    db.add(other)
    db.commit()
    return {"Authorization": f"Bearer {create_access_token(other.id)}"}


@pytest.fixture
def repo(db) -> Repo:
    return make_repo(db, 1)


@pytest.fixture
def clock(monkeypatch):
    """Fixed, changeable "now" for learning_service: set clock.now = ... in the test."""

    class Clock:
        now = T1

    clock = Clock()
    monkeypatch.setattr(learning_service, "utcnow", lambda: clock.now)
    return clock


def put(client, headers, repo_id, status):
    return client.put(f"{URL}/{repo_id}", json={"status": status}, headers=headers)


def parse(value):
    """API datetime string -> aware datetime (SQLite drops the timezone, so add UTC back)."""
    if value is None:
        return None
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ---------- create / upsert ----------

def test_put_creates_row(client, repo, auth_headers, clock):
    response = put(client, auth_headers, repo.id, "want_to_try")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "want_to_try"
    assert body["repo_id"] == repo.id
    assert body["repo"]["full_name"] == "owner1/repo1"
    assert body["started_at"] is None
    assert body["completed_at"] is None
    assert parse(body["updated_at"]) == T1


def test_put_again_updates_same_row(client, db, repo, auth_headers, clock):
    first = put(client, auth_headers, repo.id, "want_to_try").json()
    second = put(client, auth_headers, repo.id, "learning").json()
    assert second["id"] == first["id"]
    assert db.query(UserRepo).count() == 1


def test_put_unknown_repo_returns_404(client, auth_headers):
    assert_error(put(client, auth_headers, 999, "learning"), 404, "NOT_FOUND")


def test_put_invalid_status_returns_validation_error(client, repo, auth_headers):
    response = put(client, auth_headers, repo.id, "done")
    assert_error(response, 422, "VALIDATION_ERROR")
    assert "body.status" in [d["field"] for d in response.json()["error"]["details"]]


def test_put_requires_login(client, repo):
    assert_error(client.put(f"{URL}/{repo.id}", json={"status": "learning"}), 401, "UNAUTHORIZED")


# ---------- timestamp rules ----------

def test_learning_sets_started_at_once(client, repo, auth_headers, clock):
    body = put(client, auth_headers, repo.id, "learning").json()
    assert parse(body["started_at"]) == T1
    assert body["completed_at"] is None

    # back to want_to_try and again to learning: the first start is kept
    clock.now = T2
    put(client, auth_headers, repo.id, "want_to_try")
    clock.now = T3
    body = put(client, auth_headers, repo.id, "learning").json()
    assert parse(body["started_at"]) == T1
    assert parse(body["updated_at"]) == T3


def test_used_sets_completed_and_keeps_started(client, repo, auth_headers, clock):
    put(client, auth_headers, repo.id, "learning")
    clock.now = T2
    body = put(client, auth_headers, repo.id, "used").json()
    assert parse(body["started_at"]) == T1
    assert parse(body["completed_at"]) == T2


def test_used_directly_sets_started_and_completed(client, repo, auth_headers, clock):
    body = put(client, auth_headers, repo.id, "used").json()
    assert parse(body["started_at"]) == T1
    assert parse(body["completed_at"]) == T1


def test_used_again_keeps_completed_at(client, repo, auth_headers, clock):
    put(client, auth_headers, repo.id, "used")
    clock.now = T2
    body = put(client, auth_headers, repo.id, "used").json()
    assert parse(body["completed_at"]) == T1
    assert parse(body["updated_at"]) == T2  # updated_at is always bumped


@pytest.mark.parametrize("new_status", ["learning", "want_to_try"])
def test_leaving_used_clears_completed_at(client, repo, auth_headers, clock, new_status):
    put(client, auth_headers, repo.id, "used")
    clock.now = T2
    body = put(client, auth_headers, repo.id, new_status).json()
    assert body["status"] == new_status
    assert body["completed_at"] is None
    assert parse(body["started_at"]) == T1  # start is kept
    assert parse(body["updated_at"]) == T2


def test_apply_status_rules_directly():
    row = UserRepo(user_id=1, repo_id=1)
    learning_service.apply_status(row, "want_to_try", T1)
    assert (row.started_at, row.completed_at, row.updated_at) == (None, None, T1)

    learning_service.apply_status(row, "learning", T2)
    assert (row.started_at, row.completed_at) == (T2, None)

    learning_service.apply_status(row, "used", T3)
    assert (row.started_at, row.completed_at) == (T2, T3)

    later = T3 + timedelta(days=1)
    learning_service.apply_status(row, "learning", later)
    assert (row.status, row.started_at, row.completed_at, row.updated_at) == ("learning", T2, None, later)


# ---------- list ----------

def test_list_paginated_and_filtered(client, db, repo, auth_headers, clock):
    make_repo(db, 2)
    make_repo(db, 3)
    put(client, auth_headers, 1, "want_to_try")
    clock.now = T2
    put(client, auth_headers, 2, "learning")
    clock.now = T3
    put(client, auth_headers, 3, "learning")

    page1 = client.get(URL, params={"limit": 2}, headers=auth_headers).json()
    assert page1["total"] == 3
    assert [r["repo_id"] for r in page1["items"]] == [3, 2]  # newest updated first
    assert page1["items"][0]["repo"]["id"] == 3
    page2 = client.get(URL, params={"page": 2, "limit": 2}, headers=auth_headers).json()
    assert [r["repo_id"] for r in page2["items"]] == [1]

    learning = client.get(URL, params={"status": "learning"}, headers=auth_headers).json()
    assert learning["total"] == 2
    assert {r["status"] for r in learning["items"]} == {"learning"}


def test_list_invalid_status_filter(client, auth_headers):
    assert_error(client.get(URL, params={"status": "done"}, headers=auth_headers), 422, "VALIDATION_ERROR")


def test_list_only_shows_own_rows(client, repo, auth_headers, other_headers):
    put(client, auth_headers, repo.id, "learning")
    put(client, other_headers, repo.id, "used")
    body = client.get(URL, headers=auth_headers).json()
    assert body["total"] == 1
    assert body["items"][0]["status"] == "learning"


# ---------- delete ----------

def test_delete_status(client, db, repo, auth_headers):
    put(client, auth_headers, repo.id, "learning")
    response = client.delete(f"{URL}/{repo.id}", headers=auth_headers)
    assert response.status_code == 204
    assert db.query(UserRepo).count() == 0


def test_delete_missing_returns_404(client, repo, auth_headers):
    assert_error(client.delete(f"{URL}/{repo.id}", headers=auth_headers), 404, "NOT_FOUND")


# ---------- other user's row ----------

def test_other_user_cannot_touch_my_row(client, db, repo, auth_headers, other_headers):
    put(client, auth_headers, repo.id, "learning")

    # B cannot delete A's row (B has no row for this repo -> 404)
    assert_error(client.delete(f"{URL}/{repo.id}", headers=other_headers), 404, "NOT_FOUND")
    # B cannot see it
    assert client.get(URL, headers=other_headers).json()["total"] == 0
    # B setting a status creates B's own row; A's row is unchanged
    put(client, other_headers, repo.id, "used")
    mine = client.get(URL, headers=auth_headers).json()["items"]
    assert len(mine) == 1 and mine[0]["status"] == "learning"
    assert db.query(UserRepo).count() == 2
