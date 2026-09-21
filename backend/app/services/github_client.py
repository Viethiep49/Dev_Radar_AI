"""Small httpx client for the GitHub REST/Search API (uses settings.github_token).

The function signatures below are the contract other features rely on.
Every function raises GitHubError on network problems, rate limits (403/429) and 5xx.
"""

import logging
from datetime import datetime, timezone

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

BASE_URL = "https://api.github.com"
API_VERSION = "2022-11-28"
JSON_MEDIA_TYPE = "application/vnd.github+json"
RAW_MEDIA_TYPE = "application/vnd.github.raw+json"  # README as plain markdown text
TIMEOUT = httpx.Timeout(20.0, connect=5.0)


class GitHubError(Exception):
    """Network problem, rate limit (403/429) or 5xx from GitHub."""

    def __init__(self, message: str, rate_limited: bool = False, reset_at: datetime | None = None):
        super().__init__(message)
        self.rate_limited = rate_limited
        self.reset_at = reset_at  # when the rate limit ends (UTC), if GitHub told us


def _headers(accept: str) -> dict:
    headers = {"Accept": accept, "X-GitHub-Api-Version": API_VERSION}
    if settings.github_token:
        headers["Authorization"] = f"Bearer {settings.github_token}"
    return headers


def _rate_limit_reset(response: httpx.Response) -> datetime | None:
    reset = response.headers.get("X-RateLimit-Reset")  # unix timestamp
    if reset and reset.isdigit():
        return datetime.fromtimestamp(int(reset), tz=timezone.utc)
    return None


def _get(path: str, params: dict | None = None, accept: str = JSON_MEDIA_TYPE) -> httpx.Response | None:
    """GET a GitHub URL. Returns None on 404, raises GitHubError on other problems."""
    try:
        response = httpx.get(
            BASE_URL + path,
            params=params,
            headers=_headers(accept),
            timeout=TIMEOUT,
            follow_redirects=True,  # renamed repos answer with a redirect
        )
    except httpx.HTTPError as exc:
        raise GitHubError(f"GitHub request failed: {exc}") from exc

    status = response.status_code
    if status == 404:
        return None
    if status in (403, 429):
        reset_at = _rate_limit_reset(response)
        rate_limited = status == 429 or response.headers.get("X-RateLimit-Remaining") == "0" or (
            "rate limit" in response.text.lower()
        )
        message = f"GitHub returned {status} for {path}"
        if rate_limited:
            message = f"GitHub rate limit reached (resets at {reset_at.isoformat() if reset_at else 'unknown'})"
        raise GitHubError(message, rate_limited=rate_limited, reset_at=reset_at)
    if status >= 400:
        raise GitHubError(f"GitHub returned {status} for {path}")
    return response


def search_repositories(query: str, sort: str = "stars", per_page: int = 30, page: int = 1) -> list[dict]:
    """Return the "items" of a GitHub repository search."""
    params = {"q": query, "sort": sort, "order": "desc", "per_page": per_page, "page": page}
    response = _get("/search/repositories", params=params)
    if response is None:
        return []
    return response.json().get("items", [])


def get_repo(full_name: str) -> dict | None:
    """Return the repo JSON, or None if it does not exist."""
    response = _get(f"/repos/{full_name}")
    return response.json() if response is not None else None


def get_readme(full_name: str) -> str | None:
    """Return the README as markdown text, or None if the repo has no README."""
    response = _get(f"/repos/{full_name}/readme", accept=RAW_MEDIA_TYPE)
    return response.text if response is not None else None


def get_latest_release(full_name: str) -> dict | None:
    """Return the latest release JSON (tag_name, name, html_url, published_at), or None if there is none."""
    response = _get(f"/repos/{full_name}/releases/latest")
    return response.json() if response is not None else None
