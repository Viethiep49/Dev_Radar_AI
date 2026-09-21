"""Schemas for /chat (AI feature)."""

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, StringConstraints


class ChatAskRequest(BaseModel):
    question: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=1000)]


class ChatSource(BaseModel):
    path: str
    excerpt: str


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    repo_id: int
    role: str  # "user" | "assistant"
    content: str
    sources: list[ChatSource] | None = None  # only for "assistant" messages
    created_at: datetime


class ChatAnswerOut(BaseModel):
    question: ChatMessageOut  # the saved user message
    answer: ChatMessageOut  # the saved assistant message
