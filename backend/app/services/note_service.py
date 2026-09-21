"""Business logic for notes (a user's text notes about a repo)."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.pagination import PageParams, paginate
from app.db.base import utcnow
from app.models import Note
from app.schemas.notes import NoteCreate, NoteUpdate
from app.services.repo_service import get_repo_or_404


def get_note_or_404(db: Session, user_id: int, note_id: int) -> Note:
    """Return the user's note. Another user's note is also NOT_FOUND."""
    note = db.get(Note, note_id)
    if note is None or note.user_id != user_id:
        raise AppError(404, ErrorCode.NOT_FOUND, "Note not found")
    return note


def list_notes(
    db: Session,
    user_id: int,
    params: PageParams,
    repo_id: int | None = None,
    q: str | None = None,
) -> dict:
    """One page of the user's notes, newest updated first. Optional filters: repo_id, q (in content)."""
    stmt = select(Note).where(Note.user_id == user_id)
    if repo_id is not None:
        stmt = stmt.where(Note.repo_id == repo_id)
    if q:
        stmt = stmt.where(Note.content.ilike(f"%{q}%"))
    stmt = stmt.order_by(Note.updated_at.desc(), Note.id.desc())
    return paginate(db, stmt, params)


def create_note(db: Session, user_id: int, body: NoteCreate) -> Note:
    get_repo_or_404(db, body.repo_id)
    note = Note(user_id=user_id, repo_id=body.repo_id, content=body.content)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


def update_note(db: Session, user_id: int, note_id: int, body: NoteUpdate) -> Note:
    note = get_note_or_404(db, user_id, note_id)
    note.content = body.content
    note.updated_at = utcnow()
    db.commit()
    db.refresh(note)
    return note


def delete_note(db: Session, user_id: int, note_id: int) -> None:
    note = get_note_or_404(db, user_id, note_id)
    db.delete(note)
    db.commit()
