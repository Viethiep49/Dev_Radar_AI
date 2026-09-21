"""Notes CRUD endpoints."""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams
from app.db.session import get_db
from app.models import User
from app.schemas.notes import NoteCreate, NoteOut, NoteUpdate
from app.services import note_service

router = APIRouter(prefix="/notes", tags=["notes"])


@router.get("", response_model=Page[NoteOut])
def list_notes(
    params: PageParams = Depends(),
    repo_id: int | None = Query(None, description="Only notes of this repo"),
    q: str | None = Query(None, description="Search in the note content"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return note_service.list_notes(db, current_user.id, params, repo_id, q)


@router.post("", response_model=NoteOut, status_code=201)
def create_note(
    body: NoteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return note_service.create_note(db, current_user.id, body)


@router.get("/{note_id}", response_model=NoteOut)
def get_note(
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return note_service.get_note_or_404(db, current_user.id, note_id)


@router.patch("/{note_id}", response_model=NoteOut)
def update_note(
    note_id: int,
    body: NoteUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return note_service.update_note(db, current_user.id, note_id, body)


@router.delete("/{note_id}", status_code=204)
def delete_note(
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    note_service.delete_note(db, current_user.id, note_id)
    return Response(status_code=204)
