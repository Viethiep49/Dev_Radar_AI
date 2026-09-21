"""Statistics endpoints (by status, by week, by language). Filled by the personal feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/stats", tags=["stats"])
