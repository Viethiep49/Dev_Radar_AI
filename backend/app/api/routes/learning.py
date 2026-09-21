"""Learning status (want_to_try / learning / used) endpoints. Filled by the personal feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/learning", tags=["learning"])
