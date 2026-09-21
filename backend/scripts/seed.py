"""Seed demo data. Safe to run many times (idempotent).

Run from the backend/ folder:
    python -m scripts.seed
or inside Docker:
    docker compose exec backend python -m scripts.seed
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models import User, UserPreference

DEMO_EMAIL = "demo@devradar.dev"
DEMO_PASSWORD = "demo1234"
DEMO_LANGUAGES = ["Dart", "Python", "TypeScript"]
DEMO_TOPICS = ["flutter", "ai", "web"]


def seed_demo_user(db: Session) -> User:
    user = db.scalar(select(User).where(User.email == DEMO_EMAIL))
    if user is None:
        user = User(
            email=DEMO_EMAIL,
            password_hash=hash_password(DEMO_PASSWORD),
            display_name="Demo User",
        )
        db.add(user)
        db.flush()  # get user.id without committing yet
        print(f"Created user {DEMO_EMAIL}")
    else:
        print(f"User {DEMO_EMAIL} already exists")
    return user


def seed_preferences(db: Session, user: User) -> None:
    wanted = [("language", value) for value in DEMO_LANGUAGES] + [("topic", value) for value in DEMO_TOPICS]
    for kind, value in wanted:
        exists = db.scalar(
            select(UserPreference).where(
                UserPreference.user_id == user.id,
                UserPreference.kind == kind,
                UserPreference.value == value,
            )
        )
        if exists is None:
            db.add(UserPreference(user_id=user.id, kind=kind, value=value))


# ---------------------------------------------------------------------------
# TODO(repos feature): insert demo repos (+ star snapshots) here.
# Must stay idempotent: look a repo up by github_id / full_name before adding it.
# ---------------------------------------------------------------------------
def seed_repos(db: Session) -> None:
    pass


def main() -> None:
    with SessionLocal() as db:
        user = seed_demo_user(db)
        seed_preferences(db, user)
        seed_repos(db)
        db.commit()
    print("Seed done.")


if __name__ == "__main__":
    main()
