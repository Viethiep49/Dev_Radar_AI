"""Tests for the AI engine client: fallback mode and error mapping (no network)."""

import json

import httpx
import pytest

from app.core.config import settings
from app.core.errors import AppError
from app.services import ai_client


def use_mock_engine(monkeypatch, handler):
    """Point the client to a fake engine answered by `handler(request)`."""
    monkeypatch.setattr(settings, "ai_engine_url", "http://ai-engine:8000")

    def make_client():
        return httpx.Client(base_url="http://ai-engine:8000", transport=httpx.MockTransport(handler))

    monkeypatch.setattr(ai_client, "_make_client", make_client)


def test_empty_url_uses_fallback(monkeypatch):
    monkeypatch.setattr(settings, "ai_engine_url", "")

    def fail():
        raise AssertionError("must not call the network")

    monkeypatch.setattr(ai_client, "_make_client", fail)
    result = ai_client.summarize(1, "me/x", "A tiny library that does one thing very well indeed.")
    assert result["model"] == "fallback"
    assert ai_client.index(1, "me/x", [{"path": "README.md", "content": "Hello there"}]) == {"chunks": 1}
    answer = ai_client.chat(1, "me/x", "library?", [], readme="A tiny library that does one thing.")
    assert "tiny library" in answer["answer"]


def test_calls_engine_when_url_set(monkeypatch):
    seen = {}

    def handler(request: httpx.Request):
        seen["path"] = request.url.path
        seen["body"] = json.loads(request.read())
        return httpx.Response(200, json={"answer": "Xin chào", "sources": []})

    use_mock_engine(monkeypatch, handler)
    history = [{"role": "user", "content": "trước"}]
    result = ai_client.chat(1, "me/x", "hi?", history, readme="ignored")
    assert result == {"answer": "Xin chào", "sources": []}
    assert seen["path"] == "/chat"
    assert seen["body"] == {"repo_id": 1, "full_name": "me/x", "question": "hi?", "history": history}


def test_timeout_maps_to_504(monkeypatch):
    def handler(request):
        raise httpx.ReadTimeout("too slow", request=request)

    use_mock_engine(monkeypatch, handler)
    with pytest.raises(AppError) as info:
        ai_client.chat(1, "me/x", "hi?", [])
    assert info.value.status_code == 504
    assert info.value.code == "UPSTREAM_TIMEOUT"
    assert info.value.message == "AI đang bận, vui lòng thử lại"


def test_http_500_maps_to_502(monkeypatch):
    use_mock_engine(monkeypatch, lambda request: httpx.Response(500, json={"detail": "boom"}))
    with pytest.raises(AppError) as info:
        ai_client.summarize(1, "me/x", "readme")
    assert info.value.status_code == 502
    assert info.value.code == "UPSTREAM_ERROR"


def test_connection_error_maps_to_502(monkeypatch):
    def handler(request):
        raise httpx.ConnectError("refused", request=request)

    use_mock_engine(monkeypatch, handler)
    with pytest.raises(AppError) as info:
        ai_client.index(1, "me/x", [])
    assert info.value.code == "UPSTREAM_ERROR"
