"""Response shapes of the video routes."""

from pydantic import BaseModel


class RoadmapVideoOut(BaseModel):
    job_id: str
    url: str  # relative, e.g. /api/v1/videos/<job_id>
    duration_seconds: float
    size_bytes: int
