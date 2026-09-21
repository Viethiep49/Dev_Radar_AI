"""Import every model here so Alembic and the tests see all tables in Base.metadata."""

from app.models.chat import ChatMessage
from app.models.notification import Notification
from app.models.personal import Collection, CollectionItem, Note, UserRepo, Watchlist
from app.models.repo import Repo, RepoRelease, RepoStarSnapshot, RepoSummary
from app.models.user import DeviceToken, User, UserPreference

__all__ = [
    "ChatMessage",
    "Collection",
    "CollectionItem",
    "DeviceToken",
    "Note",
    "Notification",
    "Repo",
    "RepoRelease",
    "RepoStarSnapshot",
    "RepoSummary",
    "User",
    "UserPreference",
    "UserRepo",
    "Watchlist",
]
