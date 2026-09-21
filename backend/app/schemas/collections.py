"""Schemas for /collections (personal feature)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.repo_brief import RepoBrief


class CollectionCreate(BaseModel):
    # Strip spaces so "   " counts as an empty name.
    model_config = ConfigDict(str_strip_whitespace=True)

    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)


class CollectionUpdate(BaseModel):
    """PATCH body: only the fields that are sent are changed."""

    model_config = ConfigDict(str_strip_whitespace=True)

    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)


class CollectionItemCreate(BaseModel):
    repo_id: int


class CollectionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None
    item_count: int
    created_at: datetime
    updated_at: datetime


class CollectionRepoOut(RepoBrief):
    """A repo inside a collection, with the time it was added."""

    added_at: datetime


class CollectionDetailOut(CollectionOut):
    repos: list[CollectionRepoOut]
