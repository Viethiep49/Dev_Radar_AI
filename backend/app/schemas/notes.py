"""Schemas for /notes (personal feature)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.repo_brief import RepoBrief


class NoteCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    repo_id: int
    content: str = Field(min_length=1, max_length=5000)


class NoteUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    content: str = Field(min_length=1, max_length=5000)


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    repo_id: int
    content: str
    created_at: datetime
    updated_at: datetime
    repo: RepoBrief
