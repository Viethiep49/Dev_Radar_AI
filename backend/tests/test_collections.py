from datetime import datetime, timedelta, timezone

import pytest

from app.core.security import create_access_token, hash_password
from app.models import Collection, CollectionItem, Repo, User

URL = "/api/v1/collections"


def assert_error(response, status_code: int, code: str):
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code


def make_repo(db, n: int, language: str | None = "Python") -> Repo:
    repo = Repo(
        github_id=1000 + n,
        full_name=f"owner{n}/repo{n}",
        owner=f"owner{n}",
        name=f"repo{n}",
        html_url=f"https://github.com/owner{n}/repo{n}",
        language=language,
        stars=n * 10,
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


def create(client, headers, name="Flutter", description=None):
    response = client.post(URL, json={"name": name, "description": description}, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


# ---------- create ----------

def test_create_collection(client, auth_headers):
    body = create(client, auth_headers, "  Flutter  ", "UI libs")
    assert body["name"] == "Flutter"  # spaces stripped
    assert body["description"] == "UI libs"
    assert body["item_count"] == 0
    assert body["id"] and body["created_at"] and body["updated_at"]


def test_create_requires_login(client):
    assert_error(client.post(URL, json={"name": "x"}), 401, "UNAUTHORIZED")


@pytest.mark.parametrize(
    "payload, field",
    [
        ({}, "body.name"),
        ({"name": ""}, "body.name"),
        ({"name": "   "}, "body.name"),
        ({"name": "x" * 101}, "body.name"),
        ({"name": "ok", "description": "x" * 501}, "body.description"),
    ],
)
def test_create_validation_errors(client, auth_headers, payload, field):
    response = client.post(URL, json=payload, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")
    assert field in [d["field"] for d in response.json()["error"]["details"]]


def test_create_duplicate_name_returns_409(client, auth_headers):
    create(client, auth_headers, "Flutter")
    response = client.post(URL, json={"name": "flutter"}, headers=auth_headers)
    assert_error(response, 409, "CONFLICT")


def test_same_name_is_allowed_for_another_user(client, auth_headers, other_headers):
    create(client, auth_headers, "Flutter")
    create(client, other_headers, "Flutter")


# ---------- list, pagination, search ----------

def test_list_is_paginated_newest_updated_first(client, db, user, auth_headers):
    base = datetime(2026, 9, 1, tzinfo=timezone.utc)
    for i in range(3):
        db.add(Collection(user_id=user.id, name=f"c{i}", updated_at=base + timedelta(days=i)))
    db.commit()

    page1 = client.get(URL, params={"page": 1, "limit": 2}, headers=auth_headers).json()
    assert page1["total"] == 3
    assert page1["page"] == 1 and page1["limit"] == 2
    assert [c["name"] for c in page1["items"]] == ["c2", "c1"]

    page2 = client.get(URL, params={"page": 2, "limit": 2}, headers=auth_headers).json()
    assert [c["name"] for c in page2["items"]] == ["c0"]


def test_list_has_item_count(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    create(client, auth_headers, "B")
    for n in (1, 2):
        make_repo(db, n)
        client.post(f"{URL}/{collection['id']}/items", json={"repo_id": n}, headers=auth_headers)

    items = client.get(URL, headers=auth_headers).json()["items"]
    counts = {c["name"]: c["item_count"] for c in items}
    assert counts == {"A": 2, "B": 0}


def test_list_search_by_name_or_description(client, auth_headers):
    create(client, auth_headers, "Flutter UI")
    create(client, auth_headers, "Backend", "Python web FRAMEWORKS")
    create(client, auth_headers, "Misc")

    names = lambda q: sorted(c["name"] for c in client.get(URL, params={"q": q}, headers=auth_headers).json()["items"])
    assert names("flutter") == ["Flutter UI"]
    assert names("framework") == ["Backend"]
    assert names("nothing") == []


def test_list_only_shows_own_collections(client, auth_headers, other_headers):
    create(client, auth_headers, "Mine")
    create(client, other_headers, "Theirs")
    body = client.get(URL, headers=auth_headers).json()
    assert body["total"] == 1
    assert body["items"][0]["name"] == "Mine"


def test_list_bad_pagination_returns_validation_error(client, auth_headers):
    assert_error(client.get(URL, params={"limit": 0}, headers=auth_headers), 422, "VALIDATION_ERROR")


# ---------- detail ----------

def test_get_collection_with_repos_newest_added_first(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    make_repo(db, 1)
    make_repo(db, 2)
    base = datetime(2026, 9, 1, tzinfo=timezone.utc)
    db.add(CollectionItem(collection_id=collection["id"], repo_id=1, added_at=base))
    db.add(CollectionItem(collection_id=collection["id"], repo_id=2, added_at=base + timedelta(hours=1)))
    db.commit()

    body = client.get(f"{URL}/{collection['id']}", headers=auth_headers).json()
    assert body["item_count"] == 2
    assert [r["id"] for r in body["repos"]] == [2, 1]
    assert body["repos"][0]["full_name"] == "owner2/repo2"
    assert body["repos"][0]["added_at"].startswith("2026-09-01T01:00:00")


def test_get_missing_collection_returns_404(client, auth_headers):
    assert_error(client.get(f"{URL}/999", headers=auth_headers), 404, "NOT_FOUND")


# ---------- update ----------

def test_update_collection(client, db, auth_headers):
    collection = create(client, auth_headers, "Old", "desc")
    old = db.get(Collection, collection["id"])
    old.updated_at = datetime(2020, 1, 1, tzinfo=timezone.utc)
    db.commit()

    response = client.patch(f"{URL}/{collection['id']}", json={"name": "New"}, headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "New"
    assert body["description"] == "desc"  # not sent -> unchanged
    assert not body["updated_at"].startswith("2020")  # bumped

    body = client.patch(f"{URL}/{collection['id']}", json={"description": None}, headers=auth_headers).json()
    assert body["description"] is None
    assert body["name"] == "New"


def test_update_to_existing_name_returns_409(client, auth_headers):
    create(client, auth_headers, "A")
    b = create(client, auth_headers, "B")
    response = client.patch(f"{URL}/{b['id']}", json={"name": "a"}, headers=auth_headers)
    assert_error(response, 409, "CONFLICT")


def test_update_keeping_own_name_is_ok(client, auth_headers):
    a = create(client, auth_headers, "A")
    response = client.patch(f"{URL}/{a['id']}", json={"name": "A", "description": "x"}, headers=auth_headers)
    assert response.status_code == 200


def test_update_validation_error(client, auth_headers):
    a = create(client, auth_headers, "A")
    response = client.patch(f"{URL}/{a['id']}", json={"name": ""}, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")


def test_update_missing_returns_404(client, auth_headers):
    assert_error(client.patch(f"{URL}/999", json={"name": "x"}, headers=auth_headers), 404, "NOT_FOUND")


# ---------- delete ----------

def test_delete_collection_also_deletes_items(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    make_repo(db, 1)
    client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 1}, headers=auth_headers)

    response = client.delete(f"{URL}/{collection['id']}", headers=auth_headers)
    assert response.status_code == 204
    assert response.content == b""
    assert db.query(Collection).count() == 0
    assert db.query(CollectionItem).count() == 0
    assert db.query(Repo).count() == 1  # the repo itself stays

    assert_error(client.get(f"{URL}/{collection['id']}", headers=auth_headers), 404, "NOT_FOUND")


def test_delete_missing_returns_404(client, auth_headers):
    assert_error(client.delete(f"{URL}/999", headers=auth_headers), 404, "NOT_FOUND")


# ---------- items ----------

def test_add_and_remove_repo(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    make_repo(db, 1)
    row = db.get(Collection, collection["id"])
    row.updated_at = datetime(2020, 1, 1, tzinfo=timezone.utc)
    db.commit()

    response = client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 1}, headers=auth_headers)
    assert response.status_code == 201
    body = response.json()
    assert body["item_count"] == 1
    assert body["repos"][0]["id"] == 1
    assert not body["updated_at"].startswith("2020")  # bumped

    response = client.delete(f"{URL}/{collection['id']}/items/1", headers=auth_headers)
    assert response.status_code == 204
    assert db.query(CollectionItem).count() == 0


def test_add_same_repo_twice_returns_409(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    make_repo(db, 1)
    client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 1}, headers=auth_headers)
    response = client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 1}, headers=auth_headers)
    assert_error(response, 409, "CONFLICT")


def test_add_unknown_repo_returns_404(client, auth_headers):
    collection = create(client, auth_headers, "A")
    response = client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 999}, headers=auth_headers)
    assert_error(response, 404, "NOT_FOUND")


def test_add_item_validation_error(client, auth_headers):
    collection = create(client, auth_headers, "A")
    response = client.post(f"{URL}/{collection['id']}/items", json={"repo_id": "abc"}, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")


def test_remove_repo_not_in_collection_returns_404(client, db, auth_headers):
    collection = create(client, auth_headers, "A")
    make_repo(db, 1)
    response = client.delete(f"{URL}/{collection['id']}/items/1", headers=auth_headers)
    assert_error(response, 404, "NOT_FOUND")


# ---------- other user's collection ----------

def test_other_user_cannot_touch_my_collection(client, db, auth_headers, other_headers):
    collection = create(client, auth_headers, "Mine")
    make_repo(db, 1)
    client.post(f"{URL}/{collection['id']}/items", json={"repo_id": 1}, headers=auth_headers)
    path = f"{URL}/{collection['id']}"

    assert_error(client.get(path, headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.patch(path, json={"name": "Hacked"}, headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.post(f"{path}/items", json={"repo_id": 1}, headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.delete(f"{path}/items/1", headers=other_headers), 404, "NOT_FOUND")
    assert_error(client.delete(path, headers=other_headers), 404, "NOT_FOUND")

    # still there and unchanged for the owner
    body = client.get(path, headers=auth_headers).json()
    assert body["name"] == "Mine"
    assert body["item_count"] == 1
