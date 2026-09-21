"""Tests for app/services/github_client.py with a fake httpx.get (no network)."""

import httpx
import pytest

from app.core.config import settings
from app.services import github_client
from app.services.github_client import GitHubError


class FakeHttp:
    """Records the last call and returns a prepared response (or raises an exception)."""

    def __init__(self, monkeypatch, status=200, json=None, text=None, headers=None, error=None):
        self.status, self.json, self.text, self.headers, self.error = status, json, text, headers or {}, error
        self.calls = []
        monkeypatch.setattr(github_client.httpx, "get", self.get)

    def get(self, url, params=None, headers=None, timeout=None, follow_redirects=False):
        self.calls.append({"url": url, "params": params, "headers": headers})
        if self.error:
            raise self.error
        request = httpx.Request("GET", url)
        if self.json is not None:
            return httpx.Response(self.status, json=self.json, headers=self.headers, request=request)
        return httpx.Response(self.status, text=self.text or "", headers=self.headers, request=request)


def test_search_repositories(monkeypatch):
    monkeypatch.setattr(settings, "github_token", "secret-token")
    fake = FakeHttp(monkeypatch, json={"total_count": 1, "items": [{"id": 1}]})

    items = github_client.search_repositories("topic:ai", per_page=10)

    assert items == [{"id": 1}]
    call = fake.calls[0]
    assert call["url"] == "https://api.github.com/search/repositories"
    assert call["params"]["q"] == "topic:ai"
    assert call["params"]["per_page"] == 10
    assert call["headers"]["Authorization"] == "Bearer secret-token"
    assert call["headers"]["Accept"] == "application/vnd.github+json"
    assert "X-GitHub-Api-Version" in call["headers"]


def test_no_auth_header_without_token(monkeypatch):
    monkeypatch.setattr(settings, "github_token", "")
    fake = FakeHttp(monkeypatch, json={"id": 1})
    github_client.get_repo("a/b")
    assert "Authorization" not in fake.calls[0]["headers"]


def test_get_repo_not_found(monkeypatch):
    FakeHttp(monkeypatch, status=404, json={"message": "Not Found"})
    assert github_client.get_repo("a/missing") is None


def test_get_readme_raw(monkeypatch):
    fake = FakeHttp(monkeypatch, text="# Hello\n")
    assert github_client.get_readme("a/b") == "# Hello\n"
    assert fake.calls[0]["url"].endswith("/repos/a/b/readme")
    assert fake.calls[0]["headers"]["Accept"] == "application/vnd.github.raw+json"


def test_get_readme_missing(monkeypatch):
    FakeHttp(monkeypatch, status=404, json={"message": "Not Found"})
    assert github_client.get_readme("a/b") is None


def test_get_latest_release(monkeypatch):
    FakeHttp(monkeypatch, json={"tag_name": "v1.0"})
    assert github_client.get_latest_release("a/b") == {"tag_name": "v1.0"}


def test_get_latest_release_none(monkeypatch):
    FakeHttp(monkeypatch, status=404, json={"message": "Not Found"})
    assert github_client.get_latest_release("a/b") is None


def test_rate_limit_error(monkeypatch):
    headers = {"X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1790000000"}
    FakeHttp(monkeypatch, status=403, json={"message": "API rate limit exceeded"}, headers=headers)

    with pytest.raises(GitHubError) as info:
        github_client.search_repositories("x")
    assert info.value.rate_limited is True
    assert info.value.reset_at is not None
    assert info.value.reset_at.timestamp() == 1790000000
    assert "rate limit" in str(info.value)


def test_429_is_rate_limit(monkeypatch):
    FakeHttp(monkeypatch, status=429, json={"message": "slow down"})
    with pytest.raises(GitHubError) as info:
        github_client.get_repo("a/b")
    assert info.value.rate_limited is True


@pytest.mark.parametrize("status", [500, 502, 503])
def test_server_error(monkeypatch, status):
    FakeHttp(monkeypatch, status=status, text="oops")
    with pytest.raises(GitHubError) as info:
        github_client.get_repo("a/b")
    assert info.value.rate_limited is False


def test_network_error(monkeypatch):
    FakeHttp(monkeypatch, error=httpx.ConnectTimeout("timed out"))
    with pytest.raises(GitHubError):
        github_client.get_readme("a/b")
