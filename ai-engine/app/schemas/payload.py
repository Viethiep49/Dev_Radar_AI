from typing import Literal
from pydantic import BaseModel, Field


class Document(BaseModel):
    path: str = Field(max_length=1000)
    content: str = Field(max_length=1000000)


class IndexRequest(BaseModel):
    repo_id: int
    full_name: str = Field(max_length=200)
    documents: list[Document] = Field(max_length=10000)


class SummarizeRequest(BaseModel):
    repo_id: int
    full_name: str = Field(max_length=200)
    readme: str = Field(max_length=100000)


class Message(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=100000)


class ChatRequest(BaseModel):
    repo_id: int
    full_name: str = Field(max_length=200)
    question: str = Field(max_length=2000)
    history: list[Message] = Field(max_length=50)
