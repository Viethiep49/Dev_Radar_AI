"""Cron jobs of the AI feature: generate summaries and index READMEs of repos.

Append jobs to JOBS, see app/jobs/scheduler.py for the format.
"""

import logging

from sqlalchemy import select
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


def summarize_repo(db: Session, repo: Repo) -> None:
    """Ask the AI for a summary, save it, then index the README for the chat."""
    result = ai_client.summarize(repo.id, repo.full_name, repo.readme)
    db.add(
        RepoSummary(
            repo_id=repo.id,
            summary=result["summary"],
            quickstart=result.get("quickstart"),
            model=result.get("model"),
        )
    )
    db.commit()

    documents = [{"path": "README.md", "content": repo.readme}]
    ai_client.index(repo.id, repo.full_name, documents)


def generate_summaries(db: Session) -> int:
    """Summarize up to BATCH_SIZE repos. Returns how many summaries were created.

    A failing repo is logged and skipped, the others still run.
    """
    created = 0
    for repo in repos_without_summary(db):
        try:
            summarize_repo(db, repo)
            created += 1
        except (AppError, KeyError, TypeError) as exc:
            # KeyError / TypeError: the AI engine answered with an unexpected JSON shape.
            db.rollback()
            logger.warning("Could not summarize/index %s: %s", repo.full_name, exc)
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
