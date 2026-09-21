"""Chat with AI about a repo: ask, history, clear history."""

from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.pagination import Page, PageParams, paginate
from app.db.session import get_db
from app.models import User
from app.schemas.chat import ChatAnswerOut, ChatAskRequest, ChatMessageOut
from app.services import chat_service
from app.services.repo_service import get_repo_or_404

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("/{repo_id}", response_model=ChatAnswerOut)
def ask_question(
    repo_id: int,
    body: ChatAskRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = get_repo_or_404(db, repo_id)
    question, answer = chat_service.ask(db, current_user, repo, body.question)
    return {"question": question, "answer": answer}


@router.get("/{repo_id}", response_model=Page[ChatMessageOut])
def get_history(
    repo_id: int,
    params: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Chat history of the current user for this repo, oldest first."""
    get_repo_or_404(db, repo_id)
    return paginate(db, chat_service.history_query(current_user.id, repo_id), params)


@router.delete("/{repo_id}", status_code=204)
def clear_history(
    repo_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    get_repo_or_404(db, repo_id)
    chat_service.clear_history(db, current_user.id, repo_id)
    return Response(status_code=204)
