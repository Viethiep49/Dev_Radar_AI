"""Chat with AI about a repo (ask + history) endpoints. Filled by the AI feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/chat", tags=["chat"])
