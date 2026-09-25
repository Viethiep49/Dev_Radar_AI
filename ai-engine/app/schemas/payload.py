from pydantic import BaseModel
from typing import List, Dict, Any

class Document(BaseModel):
    path: str
    content: str

class IndexRequest(BaseModel):
    repo_id: int
    full_name: str
    documents: List[Document]

class SummarizeRequest(BaseModel):
    repo_id: int
    full_name: str
    readme: str

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    repo_id: int
    full_name: str
    question: str
    history: List[Message]
