"""User preferences (languages/topics) endpoints. Filled by the repos feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/preferences", tags=["preferences"])
