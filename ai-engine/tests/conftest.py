import os

# app.core.config reads DATABASE_URL at import time; unit tests never connect
# to it (the engine is lazy and every DB access is mocked).
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")

import pytest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    # Start-up must not need a real DB, the embedding model or Ollama:
    # ensure_schema() and the warm-up thread are patched out.
    with patch("app.main.ensure_schema"), patch("app.main._warm_up"):
        with TestClient(app) as c:
            yield c


@pytest.fixture
def mock_health_db():
    """engine.connect() used by /health, without a real database."""
    with patch("app.main.engine") as engine:
        yield engine


@pytest.fixture
def mock_embedder():
    with patch("app.api.v1.embedder") as mock:
        def fake_encode(text_or_list):
            mock_res = MagicMock()
            if isinstance(text_or_list, list):
                mock_res.tolist.return_value = [[0.1, 0.2, 0.3] for _ in text_or_list]
            else:
                mock_res.tolist.return_value = [0.1, 0.2, 0.3]
            return mock_res
        mock.encode.side_effect = fake_encode
        yield mock


@pytest.fixture
def mock_ollama():
    with patch("app.api.v1.call_ollama") as mock:
        yield mock


@pytest.fixture
def mock_db():
    with patch("app.api.v1.SessionLocal") as mock_session_local:
        mock_session = MagicMock()
        mock_session_local.return_value = mock_session

        # Default behavior for execute().fetchall()
        mock_result = MagicMock()
        mock_result.fetchall.return_value = [("README.md", "mocked content")]
        mock_session.execute.return_value = mock_result

        yield mock_session
