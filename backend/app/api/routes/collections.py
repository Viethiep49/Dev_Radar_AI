"""Collections CRUD and add/remove repo endpoints. Filled by the personal feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/collections", tags=["collections"])
