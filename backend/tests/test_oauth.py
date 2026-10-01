"""Tests for login with Google / GitHub (app/services/oauth_service.py). No network:
Google token verification is replaced, GitHub calls go to an httpx.MockTransport."""

import httpx
import pytest

from app.core.config import settings
from app.core.errors import ErrorCode
from app.models import OAuthAccount, User
from app.services import oauth_service

GOOGLE_URL = "/api/v1/auth/google"
GITHUB_URL = "/api/v1/auth/github"
PROVIDERS_URL = "/api/v1/auth/oauth/providers"
LOGIN_URL = "/api/v1/auth/login"
ME_URL = "/api/v1/auth/me"

WEB_CLIENT_ID = "web-client.apps.googleusercontent.com"


@pytest.fixture
def google_on(monkeypatch):
    monkeypatch.setattr(settings, "google_client_ids", f"{WEB_CLIENT_ID}, android-client.apps.googleusercontent.com")


@pytest.fixture
def github_on(monkeypatch):
    monkeypatch.setattr(settings, "github_client_id", "gh-client-id")
    monkeypatch.setattr(settings, "github_client_secret", "gh-secret")
    monkeypatch.setattr(settings, "github_redirect_uri", "devradar://oauth/github")


def fake_google(monkeypatch, **overrides):
    claims = {
        "iss": "https://accounts.google.com",
        "aud": WEB_CLIENT_ID,
        "sub": "google-123",
        "email": "Alice@Gmail.com",
        "email_verified": True,
        "name": "Alice",
    }
    claims.update(overrides)
    monkeypatch.setattr(oauth_service, "_verify_google_token", lambda token: claims)
    return claims


def fake_github(monkeypatch, token_json=None, user_json=None, emails_json=None, emails_status=200):
    """Answer GitHub's token/user/emails endpoints; returns the list of requests made."""
    token_json = token_json if token_json is not None else {"access_token": "gho_abc", "token_type": "bearer"}
    user_json = user_json if user_json is not None else {"id": 42, "login": "bob", "name": "Bob"}
    emails_json = emails_json if emails_json is not None else [
        {"email": "bob-old@example.com", "verified": True, "primary": False},
        {"email": "Bob@Example.com", "verified": True, "primary": True},
    ]
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if request.url.path == "/login/oauth/access_token":
            return httpx.Response(200, json=token_json)
        if request.url.path == "/user":
            return httpx.Response(200, json=user_json)
        if request.url.path == "/user/emails":
            return httpx.Response(emails_status, json=emails_json)
        return httpx.Response(404)

    monkeypatch.setattr(
        oauth_service, "_github_client", lambda: httpx.Client(transport=httpx.MockTransport(handler))
    )
    return calls


# ---------- providers ----------

def test_providers_disabled_by_default(client, monkeypatch):
    monkeypatch.setattr(settings, "google_client_ids", "")
    monkeypatch.setattr(settings, "github_client_id", "")
    body = client.get(PROVIDERS_URL).json()
    assert body["google"] == {"enabled": False, "client_id": None}
    assert body["github"]["enabled"] is False


def test_providers_never_expose_the_github_secret(client, google_on, github_on):
    response = client.get(PROVIDERS_URL)
    assert response.status_code == 200
    body = response.json()
    assert body["google"] == {"enabled": True, "client_id": WEB_CLIENT_ID}
    assert body["github"]["enabled"] is True
    assert body["github"]["client_id"] == "gh-client-id"
    assert body["github"]["redirect_uri"] == "devradar://oauth/github"
    assert "gh-secret" not in response.text


# ---------- Google ----------

def test_google_not_configured_returns_503(client, monkeypatch):
    monkeypatch.setattr(settings, "google_client_ids", "")
    response = client.post(GOOGLE_URL, json={"id_token": "x"})
    assert response.status_code == 503
    assert response.json()["error"]["code"] == ErrorCode.NOT_CONFIGURED


def test_google_creates_user_without_password(client, db, google_on, monkeypatch):
    fake_google(monkeypatch)
    response = client.post(GOOGLE_URL, json={"id_token": "token"})

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "alice@gmail.com"
    assert body["user"]["display_name"] == "Alice"
    assert body["access_token"] and body["refresh_token"]

    user = db.query(User).one()
    assert user.password_hash is None
    account = db.query(OAuthAccount).one()
    assert (account.provider, account.provider_user_id, account.user_id) == ("google", "google-123", user.id)

    # The backend's own JWT works for the other endpoints.
    me = client.get(ME_URL, headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.json()["email"] == "alice@gmail.com"


def test_google_second_login_reuses_the_user(client, db, google_on, monkeypatch):
    fake_google(monkeypatch)
    first = client.post(GOOGLE_URL, json={"id_token": "t"}).json()
    # Same Google account, email changed at Google -> still the same local user.
    fake_google(monkeypatch, email="alice.new@gmail.com")
    second = client.post(GOOGLE_URL, json={"id_token": "t"}).json()

    assert first["user"]["id"] == second["user"]["id"]
    assert db.query(User).count() == 1
    assert db.query(OAuthAccount).one().email == "alice.new@gmail.com"


def test_google_links_existing_password_account_by_verified_email(client, db, user, google_on, monkeypatch):
    fake_google(monkeypatch, email="USER@example.com")
    response = client.post(GOOGLE_URL, json={"id_token": "t"})

    assert response.json()["user"]["id"] == user.id
    assert db.query(User).count() == 1
    # The password still works after linking.
    assert client.post(LOGIN_URL, json={"email": "user@example.com", "password": "secret123"}).status_code == 200


def test_google_unverified_email_is_not_linked_or_created(client, db, user, google_on, monkeypatch):
    fake_google(monkeypatch, email="user@example.com", email_verified=False)
    response = client.post(GOOGLE_URL, json={"id_token": "t"})

    assert response.status_code == 400
    assert db.query(OAuthAccount).count() == 0


@pytest.mark.parametrize(
    "claims",
    [
        {"aud": "someone-elses-app.apps.googleusercontent.com"},
        {"iss": "https://evil.example.com"},
        {"sub": ""},
    ],
)
def test_google_rejects_bad_claims(client, google_on, monkeypatch, claims):
    fake_google(monkeypatch, **claims)
    response = client.post(GOOGLE_URL, json={"id_token": "t"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == ErrorCode.UNAUTHORIZED


def test_google_accepts_any_configured_client_id(client, google_on, monkeypatch):
    fake_google(monkeypatch, aud="android-client.apps.googleusercontent.com")
    assert client.post(GOOGLE_URL, json={"id_token": "t"}).status_code == 200


def test_google_malformed_token_returns_401(client, google_on, monkeypatch):
    # Real verification code, but Google's public certs are faked (no network).
    from google.oauth2 import id_token as google_id_token

    monkeypatch.setattr(google_id_token, "_fetch_certs", lambda request, url: {"kid": "cert"})
    response = client.post(GOOGLE_URL, json={"id_token": "not-a-jwt"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == ErrorCode.UNAUTHORIZED


def test_google_certs_download_failure_returns_502(client, google_on, monkeypatch):
    from google.auth import exceptions as google_exceptions
    from google.oauth2 import id_token as google_id_token

    def down(request, url):
        raise google_exceptions.TransportError("no network")

    monkeypatch.setattr(google_id_token, "_fetch_certs", down)
    response = client.post(GOOGLE_URL, json={"id_token": "a.b.c"})
    assert response.status_code == 502
    assert response.json()["error"]["code"] == ErrorCode.UPSTREAM_ERROR


def test_password_login_rejected_for_oauth_only_account(client, google_on, monkeypatch):
    fake_google(monkeypatch)
    client.post(GOOGLE_URL, json={"id_token": "t"})
    response = client.post(LOGIN_URL, json={"email": "alice@gmail.com", "password": "anything"})
    assert response.status_code == 401


# ---------- GitHub ----------

def test_github_not_configured_returns_503(client, monkeypatch):
    monkeypatch.setattr(settings, "github_client_id", "")
    response = client.post(GITHUB_URL, json={"code": "abc"})
    assert response.status_code == 503
    assert response.json()["error"]["code"] == ErrorCode.NOT_CONFIGURED


def test_github_creates_user_from_primary_verified_email(client, db, github_on, monkeypatch):
    calls = fake_github(monkeypatch)
    verifier = "v" * 43
    response = client.post(GITHUB_URL, json={"code": "the-code", "code_verifier": verifier})

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "bob@example.com"
    assert body["user"]["display_name"] == "Bob"
    account = db.query(OAuthAccount).one()
    assert (account.provider, account.provider_user_id) == ("github", "42")

    # Code exchange sent the server-side secret, redirect_uri and PKCE verifier.
    token_call = calls[0]
    form = dict(httpx.QueryParams(token_call.content.decode()))
    assert form["client_secret"] == "gh-secret"
    assert form["code"] == "the-code"
    assert form["redirect_uri"] == "devradar://oauth/github"
    assert form["code_verifier"] == verifier
    assert token_call.headers["Accept"] == "application/json"
    # The GitHub access token is used for the API calls.
    assert calls[1].headers["Authorization"] == "Bearer gho_abc"


def test_github_bad_code_returns_401(client, github_on, monkeypatch):
    fake_github(monkeypatch, token_json={"error": "bad_verification_code"})
    response = client.post(GITHUB_URL, json={"code": "expired"})
    assert response.status_code == 401


def test_github_without_verified_email_returns_400(client, db, github_on, monkeypatch):
    fake_github(monkeypatch, emails_json=[{"email": "x@example.com", "verified": False, "primary": True}])
    response = client.post(GITHUB_URL, json={"code": "c"})
    assert response.status_code == 400
    assert db.query(User).count() == 0


def test_github_emails_forbidden_returns_400(client, github_on, monkeypatch):
    # Token without the user:email scope -> /user/emails answers 403.
    fake_github(monkeypatch, emails_status=403, emails_json={"message": "forbidden"})
    assert client.post(GITHUB_URL, json={"code": "c"}).status_code == 400


def test_github_network_error_returns_502(client, github_on, monkeypatch):
    def handler(request):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(
        oauth_service, "_github_client", lambda: httpx.Client(transport=httpx.MockTransport(handler))
    )
    response = client.post(GITHUB_URL, json={"code": "c"})
    assert response.status_code == 502
    assert response.json()["error"]["code"] == ErrorCode.UPSTREAM_ERROR


def test_same_email_google_and_github_share_one_user(client, db, google_on, github_on, monkeypatch):
    fake_google(monkeypatch, email="bob@example.com")
    fake_github(monkeypatch)
    a = client.post(GOOGLE_URL, json={"id_token": "t"}).json()
    b = client.post(GITHUB_URL, json={"code": "c"}).json()

    assert a["user"]["id"] == b["user"]["id"]
    assert db.query(OAuthAccount).count() == 2


def test_code_verifier_too_short_is_rejected(client, github_on):
    response = client.post(GITHUB_URL, json={"code": "c", "code_verifier": "short"})
    assert response.status_code == 422
