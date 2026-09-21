"""Cron jobs of the notifications feature: check new releases of watched repos.

Append jobs to JOBS, see app/jobs/scheduler.py for the format.
"""

import logging

from app.db.session import SessionLocal
from app.services import release_service

logger = logging.getLogger(__name__)


def check_releases_job() -> None:
    # Never raises: the scheduler must keep running.
    try:
        with SessionLocal() as db:
            created = release_service.check_releases(db)
            logger.info("check_releases: %d new notifications", created)
    except Exception:
        logger.exception("check_releases job failed")


JOBS: list[dict] = [
    {"id": "check_releases", "func": check_releases_job, "trigger": "interval", "kwargs": {"minutes": 60}},
]
