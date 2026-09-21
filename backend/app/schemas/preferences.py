"""Schemas for /preferences (repos feature)."""

from typing import Annotated

from pydantic import BaseModel, Field

# One language/topic name; the DB column is String(100).
PreferenceValue = Annotated[str, Field(max_length=100)]


class PreferencesIn(BaseModel):
    languages: list[PreferenceValue] = Field(default_factory=list, max_length=50)  # e.g. ["Python", "Dart"]
    topics: list[PreferenceValue] = Field(default_factory=list, max_length=50)  # e.g. ["flutter", "ai"]


class PreferencesOut(BaseModel):
    languages: list[str]
    topics: list[str]
