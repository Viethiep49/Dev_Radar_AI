"""Fake a new release of a repo, for the live demo "bấm theo dõi -> có thông báo".

Run from the backend/ folder:
    python -m scripts.simulate_release <owner/name> [tag]
or inside Docker:
    docker compose exec backend python -m scripts.simulate_release flutter/flutter v9.9.9

It updates repo_releases and creates one notification per watcher of the repo,
using the same code as the hourly check_releases job.
"""

import sys
from datetime import datetime, timezone

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models import Repo
from app.services import release_service


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python -m scripts.simulate_release <owner/name> [tag]")
        sys.exit(1)

    full_name = sys.argv[1]
    tag = sys.argv[2] if len(sys.argv) > 2 else "demo-" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")

    with SessionLocal() as db:
        repo = db.scalar(select(Repo).where(Repo.full_name == full_name))
        if repo is None:
            print(f"Repo {full_name} not found in the database")
            sys.exit(1)

        release = {
            "tag_name": tag,
            "name": f"Bản phát hành thử {tag}",
            "html_url": f"{repo.html_url}/releases/tag/{tag}",
            "published_at": datetime.now(timezone.utc).isoformat(),
        }
        notifications = release_service.notify_new_release(db, repo, release)
        print(f"{full_name} -> {tag}: created {len(notifications)} notification(s)")
        if not notifications:
            print("Nobody watches this repo yet: follow it in the app first.")


if __name__ == "__main__":
    main()
