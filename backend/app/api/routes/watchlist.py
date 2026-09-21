"""Watchlist (follow / unfollow repo) endpoints. Filled by the notifications feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/watchlist", tags=["watchlist"])
