"""httpx client for the internal AI engine (contract: docs/AI_ENGINE_CONTRACT.md).

- settings.ai_engine_url empty -> every function uses app.services.fallback_ai instead.
- Timeout                      -> AppError(504, UPSTREAM_TIMEOUT)
- Any other failure / non-2xx  -> AppError(502, UPSTREAM_ERROR)
"""

import logging

import httpx

from app.core.config import settings
from app.core.errors import AppError, ErrorCode
from app.services import fallback_ai

logger = logging.getLogger(__name__)

TIMEOUT_MESSAGE = "AI đang bận, vui lòng thử lại"
ERROR_MESSAGE = "AI engine đang gặp lỗi, vui lòng thử lại sau"


def use_fallback() -> bool:
    return not settings.ai_engine_url.strip()


def _make_client() -> httpx.Client:
    # Separate function so tests can replace it with a client using httpx.MockTransport.
    return httpx.Client(base_url=settings.ai_engine_url.rstrip("/"), timeout=settings.ai_timeout_seconds)


def _post(path: str, payload: dict) -> dict:
    """POST JSON to the AI engine and return the JSON answer, or raise AppError."""
    try:
        with _make_client() as client:
            response = client.post(path, json=payload)
            response.raise_for_status()
            return response.json()
    except httpx.TimeoutException:
        logger.warning("AI engine timeout on %s", path)
        raise AppError(504, ErrorCode.UPSTREAM_TIMEOUT, TIMEOUT_MESSAGE)
    except (httpx.HTTPError, ValueError) as exc:  # ValueError: answer is not JSON
        logger.warning("AI engine error on %s: %s", path, exc)
        raise AppError(502, ErrorCode.UPSTREAM_ERROR, ERROR_MESSAGE)


def summarize(repo_id: int, full_name: str, readme: str) -> dict:
    """-> {"summary", "quickstart", "model"}"""
    if use_fallback():
        return fallback_ai.summarize(repo_id, full_name, readme)
    return _post("/summarize", {"repo_id": repo_id, "full_name": full_name, "readme": readme})


def index(repo_id: int, full_name: str, documents: list[dict]) -> dict:
    """documents = [{"path", "content"}] -> {"chunks": n}"""
    if use_fallback():
        return fallback_ai.index(repo_id, full_name, documents)
    return _post("/index", {"repo_id": repo_id, "full_name": full_name, "documents": documents})


def chat(repo_id: int, full_name: str, question: str, history: list[dict], readme: str | None = None) -> dict:
    """history = [{"role", "content"}] -> {"answer", "sources": [{"path", "excerpt"}]}

    readme is only used by the fallback; the real engine searches its own index.
    """
    if use_fallback():
        return fallback_ai.chat(repo_id, full_name, question, history, readme)
    payload = {"repo_id": repo_id, "full_name": full_name, "question": question, "history": history}
    return _post("/chat", payload)
