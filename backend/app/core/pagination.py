"""Pagination with ?page=&limit=.

Usage in a route:

    @router.get("", response_model=Page[RepoOut])
    def list_repos(params: PageParams = Depends(), db: Session = Depends(get_db)):
        stmt = select(Repo).order_by(Repo.stars.desc())
        return paginate(db, stmt, params)
"""

from typing import Generic, TypeVar

from fastapi import Query
from pydantic import BaseModel
from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

T = TypeVar("T")


class PageParams:
    """Query parameters: page >= 1 (default 1), 1 <= limit <= 100 (default 20)."""

    def __init__(
        self,
        page: int = Query(1, ge=1, description="Page number, starting at 1"),
        limit: int = Query(20, ge=1, le=100, description="Items per page"),
    ):
        self.page = page
        self.limit = limit

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.limit


class Page(BaseModel, Generic[T]):
    items: list[T]
    page: int
    limit: int
    total: int


def paginate(db: Session, stmt: Select, params: PageParams) -> dict:
    """Run a select of ONE model (e.g. select(Repo)) and return one page of it.

    Returns a dict shaped like Page; FastAPI converts the items with the route's
    response_model (the item schema needs from_attributes=True).
    Always add an order_by to stmt, otherwise the page order is random.
    """
    count_stmt = select(func.count()).select_from(stmt.order_by(None).subquery())
    total = db.scalar(count_stmt)
    items = db.scalars(stmt.offset(params.offset).limit(params.limit)).all()
    return {"items": items, "page": params.page, "limit": params.limit, "total": total}
