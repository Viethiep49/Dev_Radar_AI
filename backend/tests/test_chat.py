"""Tests for /chat: ask, history, clear, user isolation, AI errors."""

from sqlalchemy import select

from app.core.config import settings
from app.core.errors import AppError, ErrorCode
from app.core.security import create_access_token
from app.models import ChatMessage, Repo, User
from app.services import ai_client

README = """# Fastlib

Fastlib is a tiny Python library for building fast HTTP servers with very little code.

## License

Fastlib is released under the MIT license.
"""


def make_repo(db, readme=README):
    repo = Repo(
        github_id=1,
        full_name="owner/fastlib",
        owner="owner",
        name="fastlib",
        html_url="https://github.com/owner/fastlib",
        readme=readme,
    )
    db.add(repo)
    db.commit()
    return repo


def other_user_headers(db):
    other = User(email="other@example.com", password_hash="x", display_name="Other")
    db.add(other)
    db.commit()
    return {"Authorization": f"Bearer {create_access_token(other.id)}"}


def test_ask_with_fallback(client, db, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "ai_engine_url", "")
    repo = make_repo(db)

    response = client.post(f"/api/v1/chat/{repo.id}", json={"question": "Which license?"}, headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["question"]["role"] == "user"
    assert body["question"]["content"] == "Which license?"
    assert body["answer"]["role"] == "assistant"
    assert "MIT license" in body["answer"]["content"]
    assert body["answer"]["sources"][0]["path"] == "README.md"


def test_ask_requires_auth_and_valid_question(client, db, auth_headers):
    repo = make_repo(db)
    assert client.post(f"/api/v1/chat/{repo.id}", json={"question": "hi"}).status_code == 401

    empty = client.post(f"/api/v1/chat/{repo.id}", json={"question": "   "}, headers=auth_headers)
    assert empty.status_code == 422
    too_long = client.post(f"/api/v1/chat/{repo.id}", json={"question": "a" * 1001}, headers=auth_headers)
    assert too_long.status_code == 422

    missing = client.post("/api/v1/chat/999", json={"question": "hi"}, headers=auth_headers)
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "NOT_FOUND"


def test_ask_repo_without_readme(client, db, auth_headers, monkeypatch):
    repo = make_repo(db, readme=None)

    def fail(*args, **kwargs):
        raise AssertionError("AI engine must not be called without a README")

    monkeypatch.setattr(ai_client, "chat", fail)
    response = client.post(f"/api/v1/chat/{repo.id}", json={"question": "How to install?"}, headers=auth_headers)
    assert response.status_code == 200
    assert "chưa có tài liệu" in response.json()["answer"]["content"]


def test_history_sent_to_ai_is_limited_to_6(client, db, user, auth_headers, monkeypatch):
    repo = make_repo(db)
    calls = []

    def fake_chat(repo_id, full_name, question, history, readme=None):
        calls.append(history)
        return {"answer": f"answer to {question}", "sources": [{"path": "README.md", "excerpt": "x"}]}

    monkeypatch.setattr(ai_client, "chat", fake_chat)
    for i in range(5):
        client.post(f"/api/v1/chat/{repo.id}", json={"question": f"q{i}"}, headers=auth_headers)

    assert calls[0] == []
    last_history = calls[-1]
    assert len(last_history) == 6
    # Oldest first, and the current question is not part of the history.
    assert last_history[0] == {"role": "user", "content": "q1"}
    assert last_history[-1] == {"role": "assistant", "content": "answer to q3"}


def test_history_list_and_clear(client, db, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "ai_engine_url", "")
    repo = make_repo(db)
    client.post(f"/api/v1/chat/{repo.id}", json={"question": "first"}, headers=auth_headers)
    client.post(f"/api/v1/chat/{repo.id}", json={"question": "second"}, headers=auth_headers)

    history = client.get(f"/api/v1/chat/{repo.id}", headers=auth_headers).json()
    assert history["total"] == 4
    assert [m["role"] for m in history["items"]] == ["user", "assistant", "user", "assistant"]
    assert history["items"][0]["content"] == "first"

    page2 = client.get(f"/api/v1/chat/{repo.id}?page=2&limit=3", headers=auth_headers).json()
    assert len(page2["items"]) == 1

    assert client.delete(f"/api/v1/chat/{repo.id}", headers=auth_headers).status_code == 204
    assert client.get(f"/api/v1/chat/{repo.id}", headers=auth_headers).json()["total"] == 0


def test_user_isolation(client, db, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "ai_engine_url", "")
    repo = make_repo(db)
    client.post(f"/api/v1/chat/{repo.id}", json={"question": "mine"}, headers=auth_headers)

    other = other_user_headers(db)
    assert client.get(f"/api/v1/chat/{repo.id}", headers=other).json()["total"] == 0

    # Clearing as the other user does not touch my messages.
    assert client.delete(f"/api/v1/chat/{repo.id}", headers=other).status_code == 204
    assert client.get(f"/api/v1/chat/{repo.id}", headers=auth_headers).json()["total"] == 2


def test_ai_error_keeps_user_message(client, db, auth_headers, monkeypatch):
    repo = make_repo(db)

    def busy(*args, **kwargs):
        raise AppError(504, ErrorCode.UPSTREAM_TIMEOUT, "AI đang bận, vui lòng thử lại")

    monkeypatch.setattr(ai_client, "chat", busy)
    response = client.post(f"/api/v1/chat/{repo.id}", json={"question": "hello?"}, headers=auth_headers)
    assert response.status_code == 504
    assert response.json()["error"]["code"] == "UPSTREAM_TIMEOUT"

    saved = db.scalars(select(ChatMessage)).all()
    assert [(m.role, m.content) for m in saved] == [("user", "hello?")]
