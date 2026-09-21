"""Cron jobs of the notifications feature: check new releases of watched repos.

Append jobs to JOBS, see app/jobs/scheduler.py for the format.
"""

JOBS: list[dict] = []
