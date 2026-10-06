from typing import Literal, Annotated
from pydantic import BaseModel, Field


class SlideBase(BaseModel):
    narration: str = Field(min_length=1, max_length=300)


class HookSlide(SlideBase):
    kind: Literal["hook"] = "hook"
    title: str = Field(min_length=1, max_length=60)
    subtitle: str | None = Field(default=None, max_length=90)


class StatSlide(SlideBase):
    kind: Literal["stat"] = "stat"
    label: str = Field(min_length=1, max_length=40)
    value: str = Field(min_length=1, max_length=12)
    unit: str | None = Field(default=None, max_length=16)


class ListSlide(SlideBase):
    kind: Literal["list"] = "list"
    title: str = Field(min_length=1, max_length=50)
    items: list[str] = Field(min_length=2, max_length=4)


class RepoSlide(SlideBase):
    kind: Literal["repo"] = "repo"
    full_name: str = Field(min_length=1, max_length=120, pattern=r"^[^/\s]+/[^/\s]+$")
    description: str | None = Field(default=None, max_length=300)
    language: str | None = Field(default=None, max_length=40)
    stars: int = Field(ge=0)
    stars_gained: int | None = None


class OutroSlide(SlideBase):
    kind: Literal["outro"] = "outro"
    title: str = Field(min_length=1, max_length=60)
    subtitle: str | None = Field(default=None, max_length=90)


Slide = Annotated[
    HookSlide | StatSlide | ListSlide | RepoSlide | OutroSlide,
    Field(discriminator="kind"),
]


class VideoSpec(BaseModel):
    job_id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,64}$")
    title: str = Field(min_length=1, max_length=80)
    quality: Literal["720p", "1080p"] = "720p"
    slides: list[Slide] = Field(min_length=2, max_length=8)


class RenderResult(BaseModel):
    path: str
    duration_seconds: float
    size_bytes: int
