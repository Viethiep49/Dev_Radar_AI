"""Business logic for collections (a user's named lists of repos)."""

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.errors import AppError, ErrorCode
from app.core.pagination import PageParams, paginate
from app.db.base import utcnow
from app.models import Collection, CollectionItem
from app.schemas.collections import CollectionCreate, CollectionUpdate
from app.schemas.repo_brief import RepoBrief
from app.services.repo_service import get_repo_or_404


def get_collection_or_404(db: Session, user_id: int, collection_id: int) -> Collection:
    """Return the user's collection. Another user's collection is also NOT_FOUND."""
    collection = db.get(Collection, collection_id)
    if collection is None or collection.user_id != user_id:
        raise AppError(404, ErrorCode.NOT_FOUND, "Collection not found")
    return collection


def _count_items(db: Session, collection_ids: list[int]) -> dict[int, int]:
    """{collection_id: number of repos} for the given collections, in one query."""
    if not collection_ids:
        return {}
    stmt = (
        select(CollectionItem.collection_id, func.count())
        .where(CollectionItem.collection_id.in_(collection_ids))
        .group_by(CollectionItem.collection_id)
    )
    return {collection_id: count for collection_id, count in db.execute(stmt)}


def _to_out(collection: Collection, item_count: int) -> dict:
    return {
        "id": collection.id,
        "name": collection.name,
        "description": collection.description,
        "item_count": item_count,
        "created_at": collection.created_at,
        "updated_at": collection.updated_at,
    }


def _check_name_is_free(db: Session, user_id: int, name: str, exclude_id: int | None = None) -> None:
    """Raise CONFLICT if the user already has a collection with this name (case-insensitive)."""
    stmt = select(Collection.id).where(
        Collection.user_id == user_id,
        func.lower(Collection.name) == name.lower(),
    )
    if exclude_id is not None:
        stmt = stmt.where(Collection.id != exclude_id)
    if db.scalar(stmt) is not None:
        raise AppError(409, ErrorCode.CONFLICT, "A collection with this name already exists")


def list_collections(db: Session, user_id: int, params: PageParams, q: str | None = None) -> dict:
    """One page of the user's collections, newest updated first. q searches name/description."""
    stmt = select(Collection).where(Collection.user_id == user_id)
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(or_(Collection.name.ilike(pattern), Collection.description.ilike(pattern)))
    stmt = stmt.order_by(Collection.updated_at.desc(), Collection.id.desc())

    page = paginate(db, stmt, params)
    counts = _count_items(db, [c.id for c in page["items"]])
    page["items"] = [_to_out(c, counts.get(c.id, 0)) for c in page["items"]]
    return page


def get_collection_detail(db: Session, user_id: int, collection_id: int) -> dict:
    """The collection plus its repos (newest added first)."""
    collection = get_collection_or_404(db, user_id, collection_id)
    items = db.scalars(
        select(CollectionItem)
        .where(CollectionItem.collection_id == collection.id)
        .order_by(CollectionItem.added_at.desc(), CollectionItem.id.desc())
    ).all()

    # RepoBrief fields of each repo + the time it was added
    repos = [
        {**RepoBrief.model_validate(item.repo).model_dump(), "added_at": item.added_at}
        for item in items
    ]

    out = _to_out(collection, len(items))
    out["repos"] = repos
    return out


def create_collection(db: Session, user_id: int, body: CollectionCreate) -> dict:
    _check_name_is_free(db, user_id, body.name)
    collection = Collection(user_id=user_id, name=body.name, description=body.description)
    db.add(collection)
    db.commit()
    db.refresh(collection)
    return _to_out(collection, 0)


def update_collection(db: Session, user_id: int, collection_id: int, body: CollectionUpdate) -> dict:
    collection = get_collection_or_404(db, user_id, collection_id)
    if body.name is not None:
        _check_name_is_free(db, user_id, body.name, exclude_id=collection.id)
        collection.name = body.name
    # description may be sent as null on purpose to clear it
    if "description" in body.model_fields_set:
        collection.description = body.description
    collection.updated_at = utcnow()
    db.commit()
    db.refresh(collection)
    return _to_out(collection, len(collection.items))


def delete_collection(db: Session, user_id: int, collection_id: int) -> None:
    collection = get_collection_or_404(db, user_id, collection_id)
    db.delete(collection)  # items are deleted too (cascade on the relationship)
    db.commit()


def add_repo(db: Session, user_id: int, collection_id: int, repo_id: int) -> dict:
    collection = get_collection_or_404(db, user_id, collection_id)
    get_repo_or_404(db, repo_id)

    existing = db.scalar(
        select(CollectionItem).where(
            CollectionItem.collection_id == collection.id,
            CollectionItem.repo_id == repo_id,
        )
    )
    if existing is not None:
        raise AppError(409, ErrorCode.CONFLICT, "Repo is already in this collection")

    db.add(CollectionItem(collection_id=collection.id, repo_id=repo_id))
    collection.updated_at = utcnow()
    db.commit()
    return get_collection_detail(db, user_id, collection.id)


def remove_repo(db: Session, user_id: int, collection_id: int, repo_id: int) -> None:
    collection = get_collection_or_404(db, user_id, collection_id)
    item = db.scalar(
        select(CollectionItem).where(
            CollectionItem.collection_id == collection.id,
            CollectionItem.repo_id == repo_id,
        )
    )
    if item is None:
        raise AppError(404, ErrorCode.NOT_FOUND, "Repo is not in this collection")

    db.delete(item)
    collection.updated_at = utcnow()
    db.commit()
