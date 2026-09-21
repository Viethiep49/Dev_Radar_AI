"""Repo feed, search, detail, summary (read from repo_summaries) and star history endpoints. Filled by the repos feature (see docs/API_CONVENTIONS.md)."""

from fastapi import APIRouter

router = APIRouter(prefix="/repos", tags=["repos"])
