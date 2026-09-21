"""Statistics endpoints (overview, by week, by language) for the app's charts."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import User
from app.schemas.stats import LanguageOut, OverviewOut, WeeklyOut
from app.services import stats_service

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/overview", response_model=OverviewOut)
def overview(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return stats_service.get_overview(db, current_user.id)


@router.get("/weekly", response_model=list[WeeklyOut])
def weekly(
    weeks: int = Query(8, ge=1, le=52, description="How many weeks, ending with the current week"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return stats_service.get_weekly(db, current_user.id, weeks)


@router.get("/languages", response_model=list[LanguageOut])
def languages(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return stats_service.get_languages(db, current_user.id)
