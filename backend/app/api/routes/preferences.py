"""User preferences (languages/topics) endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import User
from app.schemas.preferences import PreferencesIn, PreferencesOut
from app.services import preference_service

router = APIRouter(prefix="/preferences", tags=["preferences"])


@router.get("", response_model=PreferencesOut)
def get_preferences(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return preference_service.get_preferences(db, current_user)


@router.put("", response_model=PreferencesOut)
def replace_preferences(
    body: PreferencesIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Replace the whole list of languages and topics of the current user."""
    return preference_service.replace_preferences(db, current_user, body.languages, body.topics)
