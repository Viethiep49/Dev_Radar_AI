"""Run one cron job right now (handy for demos), without waiting for the scheduler.

Run from the backend/ folder:
    python -m scripts.run_job --list            # show the job ids
    python -m scripts.run_job fetch_trending    # run one job
or inside Docker:
    docker compose exec backend python -m scripts.run_job snapshot_stars
"""

import logging
import sys

from app.jobs.scheduler import all_jobs  # JOBS of repo_jobs, ai_jobs and release_jobs


def main(argv: list[str]) -> int:
    jobs = {job["id"]: job for job in all_jobs()}

    if len(argv) != 1 or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 1
    if argv[0] == "--list":
        for job_id in jobs:
            print(job_id)
        return 0

    job = jobs.get(argv[0])
    if job is None:
        print(f"Unknown job {argv[0]!r}. Available: {', '.join(jobs) or '(none)'}")
        return 1

    print(f"Running job {job['id']} ...")
    job["func"]()
    print("Done.")
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    sys.exit(main(sys.argv[1:]))
