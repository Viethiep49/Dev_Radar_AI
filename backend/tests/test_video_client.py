"""Tests for the video-engine HTTP client (fake engine via httpx.MockTransport)."""

import httpx
import pytest

from app.core.config import settings
from app.core.errors import AppError
from app.services import video_client

SPEC = {"job_id": "job1", "title": "t", "quality": "720p", "slides": []}

RESULT = {"path": "/data/videos/job1.mp4", "duration_seconds": 12.4, "size_bytes": 1024}


@pytest.fixture
def engine(monkeypatch):
    """Install a fake engine. Call engine(handler) to set the response."""
    monkeypatch.setattr(settings, "video_engine_url", "http://video-engine:9000")

    def install(handler):
        transport = httpx.MockTransport(handler)
        monkeypatch.setattr(
            video_client,
            "_make_client",
            lambda: httpx.Client(transport=transport, base_url="http://video-engine:9000"),
        )

    return install


def test_returns_the_render_result(engine):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/render"
        return httpx.Response(200, json=RESULT)

    engine(handler)

    assert video_client.render(SPEC) == RESULT


def test_timeout_becomes_504(engine):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("too slow", request=request)

    engine(handler)

    with pytest.raises(AppError) as exc:
        video_client.render(SPEC)
    assert exc.value.status_code == 504
    assert exc.value.code == "UPSTREAM_TIMEOUT"


def test_engine_failure_becomes_502(engine):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, json={"detail": "degraded"})

    engine(handler)

    with pytest.raises(AppError) as exc:
        video_client.render(SPEC)
    assert exc.value.status_code == 502
    assert exc.value.code == "UPSTREAM_ERROR"


def test_unconfigured_engine_is_503(monkeypatch):
    monkeypatch.setattr(settings, "video_engine_url", "")

    assert video_client.use_fallback() is True
    with pytest.raises(AppError) as exc:
        video_client.render(SPEC)
    assert exc.value.status_code == 503
    assert exc.value.code == "NOT_CONFIGURED"
