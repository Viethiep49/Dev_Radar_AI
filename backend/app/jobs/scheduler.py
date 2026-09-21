"""Background scheduler (APScheduler) that runs the cron jobs inside the backend.

Each feature adds its jobs to the JOBS list of its own module
(repo_jobs.py, ai_jobs.py, release_jobs.py). One job is a dict:

    {
        "id": "snapshot_stars",            # unique name
        "func": snapshot_stars,            # function without arguments
        "trigger": "cron",                 # "interval" or "cron"
        "kwargs": {"hour": 1, "minute": 0} # passed to scheduler.add_job, e.g. {"hours": 6} for interval
    }

A job must open its own DB session (`with SessionLocal() as db: ...`),
because it does not run inside an HTTP request.
"""

import functools
import logging

from apscheduler.schedulers.background import BackgroundScheduler

from app.jobs import ai_jobs, release_jobs, repo_jobs

logger = logging.getLogger(__name__)


def all_jobs() -> list[dict]:
    return repo_jobs.JOBS + ai_jobs.JOBS + release_jobs.JOBS


def safe_job(func):
    """Wrap a job so an exception is logged instead of breaking the scheduler."""

    @functools.wraps(func)
    def wrapper():
        try:
            func()
        except Exception:
            logger.exception("Job %s failed", func.__name__)

    return wrapper


def build_scheduler() -> BackgroundScheduler:
    scheduler = BackgroundScheduler(timezone="UTC")
    for job in all_jobs():
        scheduler.add_job(
            safe_job(job["func"]),
            trigger=job["trigger"],
            id=job["id"],
            replace_existing=True,
            max_instances=1,  # never run the same job twice at the same time
            coalesce=True,  # if several runs were missed, run only once
            **job.get("kwargs", {}),
        )
        logger.info("Registered job %s (%s %s)", job["id"], job["trigger"], job.get("kwargs", {}))
    return scheduler
