"""Notification list / mark-as-read / delete endpoints."""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams, paginate
from app.db.session import get_db
from app.models import User
from app.schemas.notifications import NotificationOut, ReadAllOut, UnreadCountOut
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=Page[NotificationOut])
def list_notifications(
    unread_only: bool = Query(False, description="Only unread notifications"),
    params: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Newest first."""
    return paginate(db, notification_service.list_query(current_user.id, unread_only), params)


@router.get("/unread-count", response_model=UnreadCountOut)
def unread_count(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"count": notification_service.unread_count(db, current_user.id)}


@router.post("/read-all", response_model=ReadAllOut)
def read_all(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"updated": notification_service.mark_all_read(db, current_user.id)}


@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return notification_service.mark_read(db, current_user.id, notification_id)


@router.delete("/{notification_id}", status_code=204)
def delete_notification(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notification_service.delete(db, current_user.id, notification_id)
    return Response(status_code=204)
