import pytest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    # ensure_schema() runs on startup; patch it so tests do not need a real DB.
    with patch("app.main.ensure_schema"):
        with TestClient(app) as c:
            yield c


@pytest.fixture
def mock_embedder():
    with patch("app.api.v1.embedder") as mock:
        # Mock encode to return a fake numpy array-like object with .tolist()
        mock_result = MagicMock()
        mock_result.tolist.return_value = [0.1, 0.2, 0.3]
        mock.encode.return_value = mock_result
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
