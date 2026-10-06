"""HTTP client for Ollama (shared connection pool, sane timeout, specific errors)."""

import logging

import httpx
from fastapi import HTTPException

from app.core.config import OLLAMA_URL, OLLAMA_MODEL, OLLAMA_TIMEOUT_SECONDS

logger = logging.getLogger(__name__)

_client: httpx.Client | None = None


def _get_client() -> httpx.Client:
    """One client for the whole process, so keep-alive is reused."""
    global _client
    if _client is None:
        _client = httpx.Client(timeout=OLLAMA_TIMEOUT_SECONDS)
    return _client


def call_ollama(prompt: str, json_format: bool = False, timeout: float | None = None) -> str:
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
    }
    if json_format:
        payload["format"] = "json"

    try:
        effective_timeout = timeout if timeout is not None else OLLAMA_TIMEOUT_SECONDS
        response = _get_client().post(OLLAMA_URL, json=payload, timeout=effective_timeout)
        response.raise_for_status()
    except httpx.TimeoutException as exc:
        logger.warning("Ollama timed out after %ss", effective_timeout)
        raise HTTPException(status_code=504, detail="Ollama phản hồi quá lâu, vui lòng thử lại.") from exc
    except httpx.HTTPError as exc:
        logger.warning("Ollama request failed: %s", exc)
        raise HTTPException(status_code=503, detail=f"Lỗi kết nối Ollama: {exc}") from exc

    try:
        return response.json()["response"]
    except (ValueError, KeyError) as exc:
        logger.warning("Ollama returned an unexpected body")
        raise HTTPException(status_code=502, detail="Ollama trả về dữ liệu không hợp lệ.") from exc
