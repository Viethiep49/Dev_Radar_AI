"""Business logic for repos. get_repo_or_404 is shared by every feature; the rest is filled by the repos feature."""

from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.models import Repo


def get_repo_or_404(db: Session, repo_id: int) -> Repo:
    """Return the repo or raise NOT_FOUND (uniform error format)."""
    repo = db.get(Repo, repo_id)
    if repo is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "Không tìm thấy repo")
    return repo
