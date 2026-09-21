"""Small repo card used inside other responses (collections, notes, learning, watchlist)."""

from pydantic import BaseModel, ConfigDict


class RepoBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    owner: str
    name: str
    description: str | None
    language: str | None
    stars: int
    owner_avatar_url: str | None
