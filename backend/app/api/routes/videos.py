"""On-demand video rendering and MP4 serving.

GET /{job_id} is deliberately unauthenticated: the mobile share button hands this
URL to the OS share sheet, which cannot attach an Authorization header. The job_id
is a UUID4 hex (122 random bits) and acts as the capability.
"""

import logging
import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.errors import AppError, ErrorCode
from app.db.session import get_db
from app.models import GeneratedVideo, User, UserRepo
from app.schemas.videos import RoadmapVideoOut
from app.services import video_client
from app.services.video_spec import build_roadmap_spec

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/videos", tags=["videos"])

JOB_ID_PATTERN = re.compile(r"[A-Za-z0-9_-]{1,64}")
NOT_FOUND_MESSAGE = "Không tìm thấy video"
MISSING_FILE_MESSAGE = "Không đọc được video vừa tạo, vui lòng thử lại sau"


@router.post("/roadmap", response_model=RoadmapVideoOut)
def create_roadmap_video(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Render a summary video of the caller's learning roadmap. Blocks for 30s-1min."""
    rows = list(db.scalars(select(UserRepo).where(UserRepo.user_id == current_user.id)))
    job_id = uuid4().hex

    spec = build_roadmap_spec(job_id, current_user.display_name, rows)
    # Hand the pooled connection back before rendering: the call blocks for 30s-1min,
    # and holding a connection that long can exhaust QueuePool for every other route.
    db.rollback()

    result = video_client.render(spec)

    # The engine answers 200 but writes into the volume we mount; if that volume is
    # missing or misnamed we would otherwise return a URL that 404s forever.
    if not (Path(settings.video_output_dir) / f"{job_id}.mp4").is_file():
        logger.error("Video engine reported %s but no file is mounted at %s", result.get("path"), job_id)
        raise AppError(502, ErrorCode.UPSTREAM_ERROR, MISSING_FILE_MESSAGE)

    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=current_user.id,
            duration_seconds=result["duration_seconds"],
            size_bytes=result["size_bytes"],
        )
    )
    db.commit()

    return RoadmapVideoOut(
        job_id=job_id,
        url=f"/api/v1/videos/{job_id}",
        duration_seconds=result["duration_seconds"],
        size_bytes=result["size_bytes"],
    )


@router.get("/{job_id}")
def get_video(job_id: str):
    """Serve a rendered MP4. No auth by design - see the module docstring."""
    # Reject anything that is not a plain job_id before touching the filesystem.
    if not JOB_ID_PATTERN.fullmatch(job_id):
        raise AppError(404, ErrorCode.NOT_FOUND, NOT_FOUND_MESSAGE)

    path = Path(settings.video_output_dir) / f"{job_id}.mp4"
    if not path.is_file():
        raise AppError(404, ErrorCode.NOT_FOUND, NOT_FOUND_MESSAGE)

    return FileResponse(path, media_type="video/mp4")
