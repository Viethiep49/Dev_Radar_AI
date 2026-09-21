"""Small httpx client for the GitHub REST/Search API (uses settings.github_token).

The function signatures below are the contract other features rely on.
The repos feature implements the bodies.
"""


class GitHubError(Exception):
    """Network problem, rate limit (403/429) or 5xx from GitHub."""


def search_repositories(query: str, sort: str = "stars", per_page: int = 30, page: int = 1) -> list[dict]:
    """Return the "items" of a GitHub repository search."""
    raise NotImplementedError


def get_repo(full_name: str) -> dict | None:
    """Return the repo JSON, or None if it does not exist."""
    raise NotImplementedError


def get_readme(full_name: str) -> str | None:
    """Return the README as markdown text, or None if the repo has no README."""
    raise NotImplementedError


def get_latest_release(full_name: str) -> dict | None:
    """Return the latest release JSON (tag_name, name, html_url, published_at), or None if there is none."""
    raise NotImplementedError
