"""httpx client for the internal video engine.

- settings.video_engine_url empty -> the feature is off: AppError(503, NOT_CONFIGURED).
  There is no fallback renderer; a video either comes from the engine or not at all.
- Timeout                      -> AppError(504, UPSTREAM_TIMEOUT)
- Any other failure / non-2xx  -> AppError(502, UPSTREAM_ERROR)

The engine's /render offloads its pipeline to a thread, so concurrent requests run
in parallel and compete for the same CPU: under load more than one can cross
video_timeout_seconds at once, not just the one that arrived second.
"""

import logging

import httpx

from app.core.config import settings
from app.core.errors import AppError, ErrorCode

logger = logging.getLogger(__name__)

NOT_CONFIGURED_MESSAGE = "Tính năng tạo video chưa được bật"
TIMEOUT_MESSAGE = "Tạo video quá lâu, vui lòng thử lại"
ERROR_MESSAGE = "Máy tạo video đang gặp lỗi, vui lòng thử lại sau"


def use_fallback() -> bool:
    return not settings.video_engine_url.strip()


def _make_client() -> httpx.Client:
    # Separate function so tests can replace it with a client using httpx.MockTransport.
    return httpx.Client(
        base_url=settings.video_engine_url.rstrip("/"),
        timeout=settings.video_timeout_seconds,
    )


def _post(path: str, payload: dict) -> dict:
    """POST JSON to the video engine and return the JSON answer, or raise AppError."""
    try:
        with _make_client() as client:
            response = client.post(path, json=payload)
            response.raise_for_status()
            return response.json()
    except httpx.TimeoutException:
        logger.warning("Video engine timeout on %s", path)
        raise AppError(504, ErrorCode.UPSTREAM_TIMEOUT, TIMEOUT_MESSAGE)
    except (httpx.HTTPError, ValueError) as exc:  # ValueError: answer is not JSON
        logger.warning("Video engine error on %s: %s", path, exc)
        raise AppError(502, ErrorCode.UPSTREAM_ERROR, ERROR_MESSAGE)


def render(spec: dict) -> dict:
    """spec is a VideoSpec payload -> {"path", "duration_seconds", "size_bytes"}"""
    if use_fallback():
        raise AppError(503, ErrorCode.NOT_CONFIGURED, NOT_CONFIGURED_MESSAGE)
    return _post("/render", spec)
