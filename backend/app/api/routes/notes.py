"""Notes CRUD endpoints. Filled by the personal feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/notes", tags=["notes"])
