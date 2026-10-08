"""Cron jobs of the AI feature: generate summaries and index READMEs of repos.

Append jobs to JOBS, see app/jobs/scheduler.py for the format.
"""

import logging

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.session import SessionLocal
from app.models import Repo, RepoSummary
from app.services import ai_client

logger = logging.getLogger(__name__)

BATCH_SIZE = 10  # repos per run, keeps each run short


def repos_without_summary(db: Session, limit: int = BATCH_SIZE) -> list[Repo]:
    """Repos that have a README but no summary yet, most stars first."""
    stmt = (
        select(Repo)
        .outerjoin(RepoSummary, RepoSummary.repo_id == Repo.id)
        .where(RepoSummary.id.is_(None), Repo.readme.is_not(None), Repo.readme != "")
        .order_by(Repo.stars.desc(), Repo.id)
        .limit(limit)
    )
    return list(db.scalars(stmt).all())


def summarize_repo(db: Session, repo_id: int, full_name: str, readme: str) -> RepoSummary:
    """Ask the AI for a summary, save it, then index the README for the chat.

    Takes plain values rather than the Repo object on purpose: callers release
    their pooled connection before this call, and a rollback expires ORM objects,
    so reading an attribute off one afterwards would silently re-open the
    transaction and hold the connection for the whole AI call.
    """
    result = ai_client.summarize(repo_id, full_name, readme)

    summary = RepoSummary(
        repo_id=repo_id,
        summary=result["summary"],
        quickstart=result.get("quickstart"),
        model=result.get("model"),
    )
    db.add(summary)
    try:
        db.commit()
    except IntegrityError:
        # The 30-minute cron and an on-demand request can pick the same repo at
        # the same moment. Whoever loses the race hands back the winner's row.
        db.rollback()
        summary = db.scalar(select(RepoSummary).where(RepoSummary.repo_id == repo_id))

    # Indexing replaces the repo's chunks, so running it for both the winner and
    # the loser is harmless and covers a winner that died before indexing.
    ai_client.index(repo_id, full_name, [{"path": "README.md", "content": readme}])
    return summary


def generate_summaries(db: Session) -> int:
    """Summarize up to BATCH_SIZE repos. Returns how many summaries were created.

    A failing repo is logged and skipped, the others still run.
    """
    # Read everything first, then release the connection for the whole batch of
    # slow AI calls (see summarize_repo for why the values are read up front).
    pending = [(repo.id, repo.full_name, repo.readme) for repo in repos_without_summary(db)]
    db.rollback()

    created = 0
    for repo_id, full_name, readme in pending:
        try:
            summarize_repo(db, repo_id, full_name, readme)
            created += 1
        except (AppError, KeyError, TypeError) as exc:
            # KeyError / TypeError: the AI engine answered with an unexpected JSON shape.
            db.rollback()
            logger.warning("Could not summarize/index %s: %s", full_name, exc)
    return created


def generate_summaries_job() -> None:
    # Never raises: the scheduler must keep running.
    try:
        with SessionLocal() as db:
            created = generate_summaries(db)
            logger.info("generate_summaries: %d new summaries", created)
    except Exception:
        logger.exception("generate_summaries job failed")


JOBS: list[dict] = [
    {"id": "generate_summaries", "func": generate_summaries_job, "trigger": "interval", "kwargs": {"minutes": 30}},
]
