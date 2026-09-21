"""Collections CRUD and add/remove repo endpoints."""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams
from app.db.session import get_db
from app.models import User
from app.schemas.collections import (
    CollectionCreate,
    CollectionDetailOut,
    CollectionItemCreate,
    CollectionOut,
    CollectionUpdate,
)
from app.services import collection_service

router = APIRouter(prefix="/collections", tags=["collections"])


@router.get("", response_model=Page[CollectionOut])
def list_collections(
    params: PageParams = Depends(),
    q: str | None = Query(None, description="Search in name and description"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return collection_service.list_collections(db, current_user.id, params, q)


@router.post("", response_model=CollectionOut, status_code=201)
def create_collection(
    body: CollectionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return collection_service.create_collection(db, current_user.id, body)


@router.get("/{collection_id}", response_model=CollectionDetailOut)
def get_collection(
    collection_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return collection_service.get_collection_detail(db, current_user.id, collection_id)


@router.patch("/{collection_id}", response_model=CollectionOut)
def update_collection(
    collection_id: int,
    body: CollectionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return collection_service.update_collection(db, current_user.id, collection_id, body)


@router.delete("/{collection_id}", status_code=204)
def delete_collection(
    collection_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    collection_service.delete_collection(db, current_user.id, collection_id)
    return Response(status_code=204)


@router.post("/{collection_id}/items", response_model=CollectionDetailOut, status_code=201)
def add_repo(
    collection_id: int,
    body: CollectionItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return collection_service.add_repo(db, current_user.id, collection_id, body.repo_id)


@router.delete("/{collection_id}/items/{repo_id}", status_code=204)
def remove_repo(
    collection_id: int,
    repo_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    collection_service.remove_repo(db, current_user.id, collection_id, repo_id)
    return Response(status_code=204)
