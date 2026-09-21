"""Chat about a repo: save the question, ask the AI, save the answer."""

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models import ChatMessage, Repo, User
from app.services import ai_client, fallback_ai

HISTORY_SIZE = 6  # previous messages sent to the AI as context


def history_query(user_id: int, repo_id: int):
    """All messages of one user about one repo, oldest first."""
    return (
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id, ChatMessage.repo_id == repo_id)
        .order_by(ChatMessage.id)
    )


def recent_history(db: Session, user_id: int, repo_id: int, before_id: int) -> list[dict]:
    """The last HISTORY_SIZE messages before message `before_id`, oldest first."""
    stmt = (
        select(ChatMessage)
        .where(
            ChatMessage.user_id == user_id,
            ChatMessage.repo_id == repo_id,
            ChatMessage.id < before_id,
        )
        .order_by(ChatMessage.id.desc())
        .limit(HISTORY_SIZE)
    )
    messages = list(reversed(db.scalars(stmt).all()))
    return [{"role": m.role, "content": m.content} for m in messages]


def ask(db: Session, user: User, repo: Repo, question: str) -> tuple[ChatMessage, ChatMessage]:
    """Return (user message, assistant message).

    The user message is committed BEFORE calling the AI, so it stays saved even
    if the AI call raises an AppError (the router then returns the error).
    """
    user_message = ChatMessage(user_id=user.id, repo_id=repo.id, role="user", content=question)
    db.add(user_message)
    db.commit()
    db.refresh(user_message)

    history = recent_history(db, user.id, repo.id, before_id=user_message.id)
    if repo.readme:
        result = ai_client.chat(repo.id, repo.full_name, question, history, readme=repo.readme)
    else:
        # No documentation to search: answer directly, no need to call the AI engine.
        result = fallback_ai.chat(repo.id, repo.full_name, question, history, readme=None)

    assistant_message = ChatMessage(
        user_id=user.id,
        repo_id=repo.id,
        role="assistant",
        content=result.get("answer") or fallback_ai.NO_ANSWER,
        sources=result.get("sources") or [],
    )
    db.add(assistant_message)
    db.commit()
    db.refresh(assistant_message)
    return user_message, assistant_message


def clear_history(db: Session, user_id: int, repo_id: int) -> None:
    db.execute(delete(ChatMessage).where(ChatMessage.user_id == user_id, ChatMessage.repo_id == repo_id))
    db.commit()
