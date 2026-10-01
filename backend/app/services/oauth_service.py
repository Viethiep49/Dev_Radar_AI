"""Login with Google / GitHub.

Flow (the app never sends a password, the backend never sees the user's
Google/GitHub password either):

Google  – the Flutter app signs in with `google_sign_in` (serverClientId = the Web
          client ID) and sends the ID token to POST /auth/google. We verify the
          token signature, issuer, expiry and audience (= one of GOOGLE_CLIENT_IDS)
          with google-auth, then read the user's Google id ("sub") and email.
GitHub  – the app opens github.com/login/oauth/authorize (client_id, redirect_uri,
          state, PKCE code_challenge), GitHub redirects back to GITHUB_REDIRECT_URI
          with ?code=..., the app sends that code (+ code_verifier) to
          POST /auth/github. We exchange the code for an access token with the
          client secret (kept on the server), then read /user and /user/emails.

Both end in `login_with_identity()`, which finds or creates the local user and
the backend issues its own JWTs exactly like the password login.

Account linking rule: an unknown provider identity whose email is VERIFIED by the
provider and matches an existing user is linked to that user. Unverified emails
are never used for linking (otherwise anyone could take over an account by
putting the victim's email on a GitHub/Google profile).
"""

import logging
from dataclasses import dataclass

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import AppError, ErrorCode
from app.models import OAuthAccount, User

logger = logging.getLogger(__name__)

GOOGLE = "google"
GITHUB = "github"

GOOGLE_ISSUERS = ("accounts.google.com", "https://accounts.google.com")

GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_API_URL = "https://api.github.com"
GITHUB_SCOPE = "read:user user:email"  # enough to read the profile and the verified emails
GITHUB_API_VERSION = "2022-11-28"


@dataclass
class ProviderIdentity:
    provider: str  # "google" | "github"
    provider_user_id: str  # stable id at the provider, never the email
    email: str | None  # lower-case
    email_verified: bool
    display_name: str


# ---------------------------------------------------------------- helpers


def _not_configured(provider: str) -> AppError:
    return AppError(
        503,
        ErrorCode.NOT_CONFIGURED,
        f"Đăng nhập bằng {provider} chưa được cấu hình trên server",
    )


def _invalid(message: str) -> AppError:
    return AppError(401, ErrorCode.UNAUTHORIZED, message)


def _upstream_error(provider: str) -> AppError:
    return AppError(502, ErrorCode.UPSTREAM_ERROR, f"Không kết nối được tới {provider}, vui lòng thử lại")


def google_enabled() -> bool:
    return bool(settings.google_client_id_list)


def github_enabled() -> bool:
    return bool(settings.github_client_id and settings.github_client_secret and settings.github_redirect_uri)


# ---------------------------------------------------------------- Google


def _verify_google_token(id_token: str) -> dict:
    """Check signature/issuer/expiry with google-auth. Separate function so tests can replace it."""
    # Imported here so the app still starts if google-auth is missing and Google login is off.
    from google.auth import exceptions as google_exceptions
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token

    try:
        # audience=None: we check "aud" ourselves because several client IDs are allowed.
        return google_id_token.verify_oauth2_token(
            id_token, google_requests.Request(), audience=None, clock_skew_in_seconds=10
        )
    except google_exceptions.TransportError as exc:
        logger.warning("Could not fetch Google certificates: %s", exc)
        raise _upstream_error("Google") from exc
    except (ValueError, google_exceptions.GoogleAuthError) as exc:
        # Wrong signature, expired, malformed...
        logger.info("Rejected Google ID token: %s", exc)
        raise _invalid("Google ID token không hợp lệ hoặc đã hết hạn") from exc


def google_identity(id_token: str) -> ProviderIdentity:
    if not google_enabled():
        raise _not_configured("Google")

    claims = _verify_google_token(id_token)

    if claims.get("iss") not in GOOGLE_ISSUERS:
        raise _invalid("Google ID token có issuer không hợp lệ")
    if claims.get("aud") not in settings.google_client_id_list:
        raise _invalid("Google ID token không được cấp cho ứng dụng này")
    if not claims.get("sub"):
        raise _invalid("Google ID token thiếu thông tin người dùng")

    email = (claims.get("email") or "").lower() or None
    # Google sends email_verified as a bool (sometimes as the string "true").
    verified = claims.get("email_verified") in (True, "true")
    name = claims.get("name") or (email.split("@")[0] if email else "Google user")
    return ProviderIdentity(GOOGLE, str(claims["sub"]), email, verified, name)


# ---------------------------------------------------------------- GitHub


def _github_client() -> httpx.Client:
    # Separate function so tests can use httpx.MockTransport.
    return httpx.Client(timeout=settings.oauth_timeout_seconds)


def github_identity(code: str, code_verifier: str | None = None) -> ProviderIdentity:
    if not github_enabled():
        raise _not_configured("GitHub")

    token_request = {
        "client_id": settings.github_client_id,
        "client_secret": settings.github_client_secret,
        "code": code,
        "redirect_uri": settings.github_redirect_uri,
    }
    if code_verifier:
        token_request["code_verifier"] = code_verifier

    try:
        with _github_client() as client:
            # 1. code -> access token (GitHub answers 200 even for a bad code, with an "error" field)
            response = client.post(GITHUB_TOKEN_URL, data=token_request, headers={"Accept": "application/json"})
            response.raise_for_status()
            token_data = response.json()
            access_token = token_data.get("access_token")
            if not access_token:
                logger.info("GitHub code exchange failed: %s", token_data.get("error"))
                raise _invalid("Mã đăng nhập GitHub không hợp lệ hoặc đã hết hạn")

            api_headers = {
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": GITHUB_API_VERSION,
            }
            # 2. profile
            user_response = client.get(f"{GITHUB_API_URL}/user", headers=api_headers)
            user_response.raise_for_status()
            profile = user_response.json()

            # 3. emails (the profile email can be hidden and says nothing about verification)
            emails_response = client.get(f"{GITHUB_API_URL}/user/emails", headers=api_headers)
            emails = emails_response.json() if emails_response.status_code == 200 else []
    except AppError:
        raise
    except (httpx.HTTPError, ValueError) as exc:  # ValueError: answer is not JSON
        logger.warning("GitHub OAuth request failed: %s", exc)
        raise _upstream_error("GitHub") from exc

    if not profile.get("id"):
        raise _upstream_error("GitHub")

    # Prefer the primary verified email, else any verified email.
    verified_emails = [e for e in emails if isinstance(e, dict) and e.get("verified") and e.get("email")]
    chosen = next((e for e in verified_emails if e.get("primary")), None) or (
        verified_emails[0] if verified_emails else None
    )
    email = chosen["email"].lower() if chosen else None

    name = profile.get("name") or profile.get("login") or "GitHub user"
    return ProviderIdentity(GITHUB, str(profile["id"]), email, chosen is not None, name)


# ---------------------------------------------------------------- local user


def login_with_identity(db: Session, identity: ProviderIdentity) -> User:
    """Find or create the local user for this provider identity."""
    # 1. Already linked -> that user (even if the email changed at the provider).
    account = db.scalar(
        select(OAuthAccount).where(
            OAuthAccount.provider == identity.provider,
            OAuthAccount.provider_user_id == identity.provider_user_id,
        )
    )
    if account is not None:
        if identity.email and account.email != identity.email:
            account.email = identity.email
            db.commit()
        return db.get(User, account.user_id)

    # A new account needs an email we can trust: users.email is required and unique.
    if not identity.email or not identity.email_verified:
        raise AppError(
            400,
            ErrorCode.BAD_REQUEST,
            f"Tài khoản {identity.provider} chưa có email đã xác minh, không thể đăng nhập",
        )

    # 2. Same verified email as an existing user -> link to it.
    user = db.scalar(select(User).where(User.email == identity.email))
    if user is None:
        # 3. Brand new user, without a password.
        user = User(
            email=identity.email,
            password_hash=None,
            display_name=identity.display_name.strip()[:100] or identity.email.split("@")[0],
        )
        db.add(user)
        db.flush()  # get user.id

    db.add(
        OAuthAccount(
            user_id=user.id,
            provider=identity.provider,
            provider_user_id=identity.provider_user_id,
            email=identity.email,
        )
    )
    db.commit()
    db.refresh(user)
    return user


def providers_info() -> dict:
    """Public config the app needs to start each login (no secrets)."""
    google_ids = settings.google_client_id_list
    return {
        "google": {"enabled": google_enabled(), "client_id": google_ids[0] if google_ids else None},
        "github": {
            "enabled": github_enabled(),
            "client_id": settings.github_client_id or None,
            "redirect_uri": settings.github_redirect_uri or None,
            "scope": GITHUB_SCOPE,
        },
    }
