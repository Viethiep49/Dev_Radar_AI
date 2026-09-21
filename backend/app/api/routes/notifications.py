"""Notification list / mark-as-read endpoints. Filled by the notifications feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/notifications", tags=["notifications"])
