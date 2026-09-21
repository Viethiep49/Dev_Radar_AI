"""Tests for /notifications."""

from app.core.security import create_access_token
from app.models import Notification, User


def add_notification(db, user_id, title, is_read=False):
    notification = Notification(user_id=user_id, type="release", title=title, is_read=is_read)
    db.add(notification)
    db.commit()
    return notification


def make_other_user(db):
    other = User(email="other@example.com", password_hash="x", display_name="Other")
    db.add(other)
    db.commit()
    return other, {"Authorization": f"Bearer {create_access_token(other.id)}"}


def test_list_newest_first_and_unread_filter(client, db, user, auth_headers):
    add_notification(db, user.id, "old", is_read=True)
    add_notification(db, user.id, "middle")
    add_notification(db, user.id, "new")

    body = client.get("/api/v1/notifications", headers=auth_headers).json()
    assert body["total"] == 3
    assert [n["title"] for n in body["items"]] == ["new", "middle", "old"]

    unread = client.get("/api/v1/notifications?unread_only=true", headers=auth_headers).json()
    assert [n["title"] for n in unread["items"]] == ["new", "middle"]

    count = client.get("/api/v1/notifications/unread-count", headers=auth_headers).json()
    assert count == {"count": 2}


def test_mark_read_and_read_all(client, db, user, auth_headers):
    first = add_notification(db, user.id, "a")
    add_notification(db, user.id, "b")
    add_notification(db, user.id, "c")

    response = client.patch(f"/api/v1/notifications/{first.id}/read", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["is_read"] is True
    assert client.get("/api/v1/notifications/unread-count", headers=auth_headers).json()["count"] == 2

    assert client.post("/api/v1/notifications/read-all", headers=auth_headers).json() == {"updated": 2}
    assert client.get("/api/v1/notifications/unread-count", headers=auth_headers).json()["count"] == 0
    assert client.post("/api/v1/notifications/read-all", headers=auth_headers).json() == {"updated": 0}


def test_delete(client, db, user, auth_headers):
    notification = add_notification(db, user.id, "a")
    assert client.delete(f"/api/v1/notifications/{notification.id}", headers=auth_headers).status_code == 204
    assert client.get("/api/v1/notifications", headers=auth_headers).json()["total"] == 0
    missing = client.delete(f"/api/v1/notifications/{notification.id}", headers=auth_headers)
    assert missing.status_code == 404


def test_user_isolation(client, db, user, auth_headers):
    mine = add_notification(db, user.id, "mine")
    other, other_headers = make_other_user(db)
    add_notification(db, other.id, "theirs")

    body = client.get("/api/v1/notifications", headers=auth_headers).json()
    assert [n["title"] for n in body["items"]] == ["mine"]

    # The other user can not read, mark or delete my notification.
    patch = client.patch(f"/api/v1/notifications/{mine.id}/read", headers=other_headers)
    assert patch.status_code == 404
    assert patch.json()["error"]["code"] == "NOT_FOUND"
    assert client.delete(f"/api/v1/notifications/{mine.id}", headers=other_headers).status_code == 404

    # read-all only touches the caller's notifications.
    assert client.post("/api/v1/notifications/read-all", headers=other_headers).json() == {"updated": 1}
    assert client.get("/api/v1/notifications/unread-count", headers=auth_headers).json()["count"] == 1


def test_requires_auth(client):
    assert client.get("/api/v1/notifications").status_code == 401
