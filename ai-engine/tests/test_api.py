import json
from unittest.mock import MagicMock, patch

from app.api.v1 import README_MAX_CHARS, _readme_excerpt
from app.main import app


def _tags(models):
    response = MagicMock()
    response.json.return_value = {"models": [{"name": name} for name in models]}
    return response


def test_health(client, mock_health_db):
    with patch("app.main.httpx.get", return_value=_tags(["qwen2.5:7b"])):
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "ok", "ollama": "ok"}


def test_health_degraded_when_model_missing(client, mock_health_db):
    with patch("app.main.httpx.get", return_value=_tags(["other:1b"])):
        response = client.get("/health")
    assert response.status_code == 503
    assert response.json()["ollama"] == "error"


def test_health_degraded_when_db_down(client, mock_health_db):
    mock_health_db.connect.side_effect = Exception("db down")
    with patch("app.main.httpx.get", return_value=_tags(["qwen2.5:7b"])):
        response = client.get("/health")
    assert response.status_code == 503
    assert response.json()["db"] == "error"


# ---------- _readme_excerpt (issue #5) ----------

def test_readme_excerpt_short_readme_is_unchanged():
    text = "# Proj\n\nIntro.\n\n## Installation\n\npip install proj\n"
    assert _readme_excerpt(text) == text


def test_readme_excerpt_keeps_intro_and_whole_install_section():
    intro = "# Proj\n\n" + "Proj does useful things. " * 120  # ~3000 chars of intro
    install = "## Installation\n\n### Requirements\n\nPython 3.12\n\n```bash\npip install proj\n```\n"
    text = intro + "\n\n## Features\n\n" + "x " * 2000 + "\n\n" + install + "\n## License\n\nMIT\n"

    excerpt = _readme_excerpt(text)

    assert len(excerpt) <= README_MAX_CHARS
    assert excerpt.startswith("# Proj")  # intro kept for the summary
    assert "pip install proj" in excerpt  # body of the section, not only its heading
    assert "### Requirements" in excerpt  # sub-headings stay inside the section
    assert "## License" not in excerpt  # stops at the next same-level heading


def test_readme_excerpt_vietnamese_heading():
    text = "# Dự án\n\n" + "Giới thiệu. " * 300 + "\n\n## Cài đặt\n\nnpm install\n"
    assert "npm install" in _readme_excerpt(text)


def test_readme_excerpt_without_setup_section_falls_back_to_top():
    text = "# Proj\n\n" + "a" * 5000
    assert _readme_excerpt(text) == text[:README_MAX_CHARS]


def test_routes_are_registered():
    """Regression test for the missing include_router() call.

    Reads the OpenAPI schema instead of app.routes: since starlette 1.x an
    included router shows up as one _IncludedRouter entry with no .path.
    """
    paths = set(app.openapi()["paths"])
    assert {"/summarize", "/index", "/chat", "/health"} <= paths


def test_summarize(client, mock_ollama):
    mock_ollama.return_value = json.dumps({
        "summary": "Dự án test",
        "quickstart": "npm start",
        "model": "test-model",
    })

    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "readme": "# Hello",
    }

    response = client.post("/summarize", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["summary"] == "Dự án test"
    assert data["quickstart"] == "npm start"
    mock_ollama.assert_called_once()


def test_summarize_invalid_json(client, mock_ollama):
    mock_ollama.return_value = "not json"
    response = client.post("/summarize", json={"repo_id": 1, "full_name": "t/r", "readme": "# x"})
    assert response.status_code == 502


def test_index(client, mock_embedder, mock_db):
    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "documents": [
            {"path": "README.md", "content": "Hello World"},
        ],
    }

    response = client.post("/index", json=payload)
    assert response.status_code == 200
    assert response.json() == {"chunks": 1}

    # Verify DB calls
    assert mock_db.execute.call_count >= 2  # DELETE + INSERT
    mock_db.commit.assert_called_once()
    mock_embedder.encode.assert_called_once()

    # The vector must be written in pgvector format: [0.1,0.2,0.3] (no spaces).
    insert_params = mock_db.execute.call_args_list[-1].args[1]
    assert insert_params[0]["embedding"] == "[0.1,0.2,0.3]"


def test_chat(client, mock_embedder, mock_db, mock_ollama):
    mock_ollama.return_value = "Đây là câu trả lời mock."

    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "question": "Làm thế nào để chạy?",
        "history": [],
    }

    response = client.post("/chat", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert data["answer"] == "Đây là câu trả lời mock."
    assert len(data["sources"]) == 1
    assert data["sources"][0]["path"] == "README.md"

    mock_embedder.encode.assert_called_once()
    mock_db.execute.assert_called_once()
    mock_ollama.assert_called_once()


def test_chat_without_relevant_chunks(client, mock_embedder, mock_db, mock_ollama):
    """No chunk passes the similarity threshold -> no answer, no LLM call."""
    mock_db.execute.return_value.fetchall.return_value = []

    response = client.post("/chat", json={
        "repo_id": 1,
        "full_name": "test/repo",
        "question": "không liên quan",
        "history": [],
    })

    assert response.status_code == 200
    assert response.json() == {"answer": "Không tìm thấy trong tài liệu", "sources": []}
    mock_ollama.assert_not_called()


def test_chat_does_not_filter_chunks_by_similarity(client, mock_embedder, mock_db, mock_ollama):
    """The similarity floor must stay off.

    Measured against the real model, the two groups overlap: on one repo an
    unrelated question scored 0.354 while a question the README answers scored
    0.037. No floor separates them, so any value in use drops correct chunks and
    /chat replies "Không tìm thấy trong tài liệu" for questions it could answer.
    Retrieval returns the closest chunks and the LLM judges relevance: the prompt
    already tells it to refuse when the documents do not cover the question.
    """
    mock_ollama.return_value = "Câu trả lời."

    client.post("/chat", json={
        "repo_id": 1, "full_name": "test/repo", "question": "Repo này dùng để làm gì?", "history": [],
    })

    params = mock_db.execute.call_args[0][1]
    assert params["max_distance"] >= 1.0  # 1.0 = every chunk with similarity >= 0 is kept


def test_chat_keeps_ollama_timeout_status(client, mock_embedder, mock_db, mock_ollama):
    """A 504 from call_ollama must not become a 500 (issue #7)."""
    from fastapi import HTTPException

    mock_ollama.side_effect = HTTPException(status_code=504, detail="timeout")
    response = client.post("/chat", json={
        "repo_id": 1, "full_name": "test/repo", "question": "?", "history": [],
    })
    assert response.status_code == 504


# ---------- chunk size (issue #7 / V-1) ----------

def test_chunks_fit_embedding_model_max_seq_length():
    """Every chunk must fit in the 128-token window of the embedding model,
    otherwise its end is silently truncated before embedding."""
    from app.services.embedder import get_model
    from app.services.text_processor import chunker

    model = get_model()
    text = (
        "# Dự án\n\nThư viện giúp lập trình viên xây dựng API nhanh chóng với Python. " * 40
        + "\n\n## Installation\n\n```bash\npip install \"fastapi[standard]\" uvicorn==0.34.0\n```\n" * 10
    )
    chunks = chunker.split_text(text)
    assert len(chunks) > 1
    assert max(len(model.tokenizer(c)["input_ids"]) for c in chunks) <= model.max_seq_length
