from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token, hash_password
from app.models import Note, Repo, User

URL = "/api/v1/notes"


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
        language="Dart",
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


def create(client, headers, repo_id=1, content="Nice repo"):
    response = client.post(URL, json={"repo_id": repo_id, "content": content}, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


# ---------- create ----------

def test_create_note(client, repo, auth_headers):
    body = create(client, auth_headers, content="  Try the CLI  ")
    assert body["content"] == "Try the CLI"
    assert body["repo_id"] == repo.id
    assert body["repo"]["full_name"] == "owner1/repo1"
    assert body["id"] and body["created_at"] and body["updated_at"]


def test_create_note_unknown_repo_returns_404(client, auth_headers):
    response = client.post(URL, json={"repo_id": 999, "content": "x"}, headers=auth_headers)
    assert_error(response, 404, "NOT_FOUND")


@pytest.mark.parametrize(
    "payload, field",
    [
        ({"content": "x"}, "body.repo_id"),
        ({"repo_id": 1}, "body.content"),
        ({"repo_id": 1, "content": ""}, "body.content"),
        ({"repo_id": 1, "content": "   "}, "body.content"),
        ({"repo_id": 1, "content": "x" * 5001}, "body.content"),
    ],
)
def test_create_validation_errors(client, repo, auth_headers, payload, field):
    response = client.post(URL, json=payload, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")
    assert field in [d["field"] for d in response.json()["error"]["details"]]


def test_create_requires_login(client, repo):
    assert_error(client.post(URL, json={"repo_id": 1, "content": "x"}), 401, "UNAUTHORIZED")


# ---------- read / list ----------

def test_get_note(client, repo, auth_headers):
    note = create(client, auth_headers)
    response = client.get(f"{URL}/{note['id']}", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == note


def test_get_missing_note_returns_404(client, auth_headers):
    assert_error(client.get(f"{URL}/999", headers=auth_headers), 404, "NOT_FOUND")


def test_list_is_paginated_newest_updated_first(client, db, user, repo, auth_headers):
    base = datetime(2026, 9, 1, tzinfo=timezone.utc)
    for i in range(3):
        db.add(Note(user_id=user.id, repo_id=repo.id, content=f"n{i}", updated_at=base + timedelta(days=i)))
    db.commit()

    page1 = client.get(URL, params={"limit": 2}, headers=auth_headers).json()
    assert page1["total"] == 3
    assert [n["content"] for n in page1["items"]] == ["n2", "n1"]
    assert page1["items"][0]["repo"]["id"] == repo.id

    page2 = client.get(URL, params={"page": 2, "limit": 2}, headers=auth_headers).json()
    assert [n["content"] for n in page2["items"]] == ["n0"]


def test_list_filter_by_repo_and_search(client, db, auth_headers):
    make_repo(db, 1)
    make_repo(db, 2)
    create(client, auth_headers, 1, "Great DOCS")
    create(client, auth_headers, 1, "slow build")
    create(client, auth_headers, 2, "docs are missing")

    def contents(**params):
        items = client.get(URL, params=params, headers=auth_headers).json()["items"]
        return sorted(n["content"] for n in items)

    assert contents(repo_id=1) == ["Great DOCS", "slow build"]
    assert contents(q="docs") == ["Great DOCS", "docs are missing"]
    assert contents(repo_id=2, q="docs") == ["docs are missing"]
    assert contents(q="nothing") == []


def test_list_only_shows_own_notes(client, repo, auth_headers, other_headers):
    create(client, auth_headers, content="mine")
    create(client, other_headers, content="theirs")
    body = client.get(URL, headers=auth_headers).json()
    assert body["total"] == 1
    assert body["items"][0]["content"] == "mine"


# ---------- update ----------

def test_update_note(client, db, repo, auth_headers):
    note = create(client, auth_headers)
    row = db.get(Note, note["id"])
    row.updated_at = datetime(2020, 1, 1, tzinfo=timezone.utc)
    db.commit()

    response = client.patch(f"{URL}/{note['id']}", json={"content": "Updated"}, headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["content"] == "Updated"
    assert not body["updated_at"].startswith("2020")


def test_update_validation_error(client, repo, auth_headers):
    note = create(client, auth_headers)
    response = client.patch(f"{URL}/{note['id']}", json={"content": ""}, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")


def test_update_missing_returns_404(client, auth_headers):
    assert_error(client.patch(f"{URL}/999", json={"content": "x"}, headers=auth_headers), 404, "NOT_FOUND")


# ---------- delete ----------

def test_delete_note(client, db, repo, auth_headers):
    note = create(client, auth_headers)
    response = client.delete(f"{URL}/{note['id']}", headers=auth_headers)
    assert response.status_code == 204
    assert db.query(Note).count() == 0
    assert_error(client.get(f"{URL}/{note['id']}", headers=auth_headers), 404, "NOT_FOUND")


def test_delete_missing_returns_404(client, auth_headers):
    assert_error(client.delete(f"{URL}/999", headers=auth_headers), 404, "NOT_FOUND")


# ---------- other user's note ----------

def test_other_user_cannot_touch_my_note(client, repo, auth_headers, other_headers):
    note = create(client, auth_headers, content="mine")
    path = f"{URL}/{note['id']}"

    assert_error(client.get(path, headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.patch(path, json={"content": "hacked"}, headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.delete(path, headers=other_headers), 404, "NOT_FOUND")

    assert client.get(path, headers=auth_headers).json()["content"] == "mine"
