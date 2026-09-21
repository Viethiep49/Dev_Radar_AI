"""Schemas for /learning (personal feature)."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

from app.schemas.repo_brief import RepoBrief

# Same values as app.models.personal.LEARNING_STATUSES
LearningStatus = Literal["want_to_try", "learning", "used"]


class LearningStatusUpdate(BaseModel):
    status: LearningStatus


class LearningOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    repo_id: int
    status: LearningStatus
    started_at: datetime | None
    completed_at: datetime | None
    updated_at: datetime
    repo: RepoBrief
