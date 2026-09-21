from fastapi.testclient import TestClient

from app.core.security import create_refresh_token
from app.models import DeviceToken

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
REFRESH_URL = "/api/v1/auth/refresh"
ME_URL = "/api/v1/auth/me"
DEVICE_URL = "/api/v1/auth/device-tokens"


def assert_error(response, status_code: int, code: str):
    """Every error must use the shared format {"error": {"code", "message", "details"}}."""
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code
    assert body["error"]["message"]


# ---------- register ----------

def test_register_returns_user_and_tokens(client):
    response = client.post(
        REGISTER_URL,
        json={"email": "New@Example.com", "password": "abc123", "display_name": "New"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "new@example.com"  # stored lower-case
    assert body["user"]["display_name"] == "New"
    assert "password_hash" not in body["user"]
    assert body["access_token"] and body["refresh_token"]
    assert body["token_type"] == "bearer"


def test_register_duplicate_email_returns_409(client, user):
    response = client.post(
        REGISTER_URL,
        json={"email": "USER@example.com", "password": "abc123", "display_name": "Again"},
    )
    assert_error(response, 409, "CONFLICT")


def test_register_short_password_returns_validation_error(client):
    response = client.post(
        REGISTER_URL,
        json={"email": "a@example.com", "password": "123", "display_name": "A"},
    )
    assert_error(response, 422, "VALIDATION_ERROR")
    fields = [d["field"] for d in response.json()["error"]["details"]]
    assert "body.password" in fields


# ---------- login ----------

def test_login_ok(client, user):
    response = client.post(LOGIN_URL, json={"email": "user@example.com", "password": "secret123"})
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["id"] == user.id
    assert body["access_token"] and body["refresh_token"]


def test_login_wrong_password_returns_401(client, user):
    response = client.post(LOGIN_URL, json={"email": "user@example.com", "password": "wrong-pass"})
    assert_error(response, 401, "UNAUTHORIZED")


def test_login_unknown_email_returns_401(client):
    response = client.post(LOGIN_URL, json={"email": "nobody@example.com", "password": "secret123"})
    assert_error(response, 401, "UNAUTHORIZED")


def test_register_then_login_with_new_account(client):
    client.post(REGISTER_URL, json={"email": "b@example.com", "password": "abc123", "display_name": "B"})
    response = client.post(LOGIN_URL, json={"email": "b@example.com", "password": "abc123"})
    assert response.status_code == 200


# ---------- me ----------

def test_me_with_token(client, user, auth_headers):
    response = client.get(ME_URL, headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == "user@example.com"


def test_me_without_token_returns_401(client):
    assert_error(client.get(ME_URL), 401, "UNAUTHORIZED")


def test_me_with_bad_token_returns_401(client):
    response = client.get(ME_URL, headers={"Authorization": "Bearer not-a-jwt"})
    assert_error(response, 401, "UNAUTHORIZED")


def test_me_with_refresh_token_is_rejected(client, user):
    headers = {"Authorization": f"Bearer {create_refresh_token(user.id)}"}
    assert_error(client.get(ME_URL, headers=headers), 401, "UNAUTHORIZED")


# ---------- refresh ----------

def test_refresh_returns_new_tokens(client, user):
    response = client.post(REFRESH_URL, json={"refresh_token": create_refresh_token(user.id)})
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    # the new access token works
    me = client.get(ME_URL, headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200


def test_refresh_with_access_token_is_rejected(client, auth_headers):
    access_token = auth_headers["Authorization"].removeprefix("Bearer ")
    response = client.post(REFRESH_URL, json={"refresh_token": access_token})
    assert_error(response, 401, "UNAUTHORIZED")


# ---------- device tokens ----------

def test_device_token_is_saved_and_upserted(client, db, user, auth_headers):
    payload = {"token": "fcm-token-1", "platform": "android"}
    first = client.post(DEVICE_URL, json=payload, headers=auth_headers)
    assert first.status_code == 201
    assert first.json()["token"] == "fcm-token-1"

    # Same token again -> no duplicate row
    second = client.post(DEVICE_URL, json={"token": "fcm-token-1", "platform": "ios"}, headers=auth_headers)
    assert second.status_code == 201
    assert second.json()["id"] == first.json()["id"]
    assert second.json()["platform"] == "ios"
    assert db.query(DeviceToken).count() == 1


def test_device_token_requires_login(client):
    response = client.post(DEVICE_URL, json={"token": "t", "platform": "android"})
    assert_error(response, 401, "UNAUTHORIZED")


def test_device_token_rejects_unknown_platform(client, auth_headers):
    response = client.post(DEVICE_URL, json={"token": "t", "platform": "nokia"}, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")


# ---------- uniform error format ----------

def test_unknown_url_uses_error_format(client):
    assert_error(client.get("/api/v1/does-not-exist"), 404, "NOT_FOUND")


def test_unhandled_exception_uses_error_format(app):
    @app.get("/boom")
    def boom():
        raise RuntimeError("something broke")

    # raise_server_exceptions=False: get the 500 response instead of the Python error
    client = TestClient(app, raise_server_exceptions=False)
    assert_error(client.get("/boom"), 500, "INTERNAL_ERROR")


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
