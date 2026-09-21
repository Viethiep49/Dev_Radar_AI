"""In-app notifications: create, list, mark as read, delete."""

import logging

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.models import Notification

logger = logging.getLogger(__name__)


def create(
    db: Session,
    user_id: int,
    type: str,
    title: str,
    body: str | None = None,
    repo_id: int | None = None,
    data: dict | None = None,
) -> Notification:
    """Add a notification to the session (the caller commits)."""
    notification = Notification(user_id=user_id, type=type, title=title, body=body, repo_id=repo_id, data=data)
    db.add(notification)
    return notification


def send_push(notification: Notification) -> None:
    """Send the notification to the user's phones. Not done yet: in-app list only."""
    # TODO(FCM): gửi push qua Firebase Cloud Messaging - làm ở giai đoạn gần bảo vệ
    return None


def list_query(user_id: int, unread_only: bool = False):
    """Notifications of one user, newest first."""
    stmt = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        stmt = stmt.where(Notification.is_read.is_(False))
    return stmt.order_by(Notification.created_at.desc(), Notification.id.desc())


def unread_count(db: Session, user_id: int) -> int:
    stmt = select(func.count()).where(Notification.user_id == user_id, Notification.is_read.is_(False))
    return db.scalar(stmt)


def get_own_or_404(db: Session, user_id: int, notification_id: int) -> Notification:
    notification = db.get(Notification, notification_id)
    if notification is None or notification.user_id != user_id:
        raise AppError(404, ErrorCode.NOT_FOUND, "Không tìm thấy thông báo")
    return notification


def mark_read(db: Session, user_id: int, notification_id: int) -> Notification:
    notification = get_own_or_404(db, user_id, notification_id)
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


def mark_all_read(db: Session, user_id: int) -> int:
    """Returns how many notifications changed from unread to read."""
    stmt = (
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    result = db.execute(stmt)
    db.commit()
    return result.rowcount


def delete(db: Session, user_id: int, notification_id: int) -> None:
    notification = get_own_or_404(db, user_id, notification_id)
    db.delete(notification)
    db.commit()
