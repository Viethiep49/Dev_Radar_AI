"""Business logic for user preferences (languages and topics chosen at onboarding)."""

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models import User, UserPreference


def get_preferences(db: Session, user: User) -> dict:
    rows = db.scalars(
        select(UserPreference).where(UserPreference.user_id == user.id).order_by(UserPreference.id)
    ).all()
    return {
        "languages": [row.value for row in rows if row.kind == "language"],
        "topics": [row.value for row in rows if row.kind == "topic"],
    }


def clean_values(values: list[str], lowercase: bool) -> list[str]:
    """Trim, drop empty values and duplicates (case-insensitive), keep the first spelling."""
    result = []
    seen = set()
    for value in values:
        value = value.strip()
        if lowercase:
            value = value.lower()
        if value and value.lower() not in seen:
            seen.add(value.lower())
            result.append(value)
    return result


def replace_preferences(db: Session, user: User, languages: list[str], topics: list[str]) -> dict:
    """Replace all preferences of the user. Languages keep their case ("Python"), topics are lower-case."""
    db.execute(delete(UserPreference).where(UserPreference.user_id == user.id))
    for value in clean_values(languages, lowercase=False):
        db.add(UserPreference(user_id=user.id, kind="language", value=value))
    for value in clean_values(topics, lowercase=True):
        db.add(UserPreference(user_id=user.id, kind="topic", value=value))
    db.commit()
    return get_preferences(db, user)
