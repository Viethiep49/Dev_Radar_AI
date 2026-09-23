from pydantic import BaseModel
from typing import List, Optional

class Source(BaseModel):
    path: str
    excerpt: str

class ChatResponse(BaseModel):
    answer: str
    sources: List[Source]

class SummarizeResponse(BaseModel):
    summary: str
    quickstart: str
    model: str
