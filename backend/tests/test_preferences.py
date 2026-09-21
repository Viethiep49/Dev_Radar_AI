"""Tests for GET/PUT /api/v1/preferences."""

from app.models import User, UserPreference

URL = "/api/v1/preferences"


def test_preferences_empty_by_default(client, auth_headers):
    response = client.get(URL, headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == {"languages": [], "topics": []}


def test_preferences_require_auth(client):
    response = client.get(URL)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


def test_put_preferences_cleans_values(client, auth_headers):
    body = {
        "languages": [" Python ", "Dart", "python", ""],
        "topics": ["Flutter", "  AI ", "flutter"],
    }
    response = client.put(URL, json=body, headers=auth_headers)
    assert response.status_code == 200
    expected = {"languages": ["Python", "Dart"], "topics": ["flutter", "ai"]}
    assert response.json() == expected
    assert client.get(URL, headers=auth_headers).json() == expected


def test_put_preferences_replaces_old_values(client, auth_headers, db, user):
    client.put(URL, json={"languages": ["Go"], "topics": ["web"]}, headers=auth_headers)
    response = client.put(URL, json={"languages": ["Rust"], "topics": []}, headers=auth_headers)

    assert response.json() == {"languages": ["Rust"], "topics": []}
    rows = db.query(UserPreference).filter_by(user_id=user.id).all()
    assert [(row.kind, row.value) for row in rows] == [("language", "Rust")]


def test_put_preferences_only_touches_own_rows(client, auth_headers, db):
    other = User(email="other@example.com", password_hash="x", display_name="Other")
    db.add(other)
    db.flush()
    db.add(UserPreference(user_id=other.id, kind="topic", value="flutter"))
    db.commit()

    client.put(URL, json={"languages": [], "topics": []}, headers=auth_headers)

    assert db.query(UserPreference).filter_by(user_id=other.id).count() == 1


def test_put_preferences_validation(client, auth_headers):
    response = client.put(URL, json={"languages": ["x" * 101]}, headers=auth_headers)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
