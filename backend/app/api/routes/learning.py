"""Learning status (want_to_try / learning / used) endpoints."""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams
from app.db.session import get_db
from app.models import User
from app.schemas.learning import LearningOut, LearningStatus, LearningStatusUpdate
from app.services import learning_service

router = APIRouter(prefix="/learning", tags=["learning"])


@router.get("", response_model=Page[LearningOut])
def list_learning(
    params: PageParams = Depends(),
    status: LearningStatus | None = Query(None, description="Only repos with this status"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return learning_service.list_learning(db, current_user.id, params, status)


@router.put("/{repo_id}", response_model=LearningOut)
def set_status(
    repo_id: int,
    body: LearningStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create or change the learning status of a repo (see learning_service.apply_status)."""
    return learning_service.set_status(db, current_user.id, repo_id, body.status)


@router.delete("/{repo_id}", status_code=204)
def delete_status(
    repo_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    learning_service.delete_status(db, current_user.id, repo_id)
    return Response(status_code=204)
