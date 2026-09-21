"""GitHub repositories (shared data, refreshed by cron jobs)."""

from datetime import date as DateType  # alias: the snapshot column itself is called "date"
from datetime import datetime

from sqlalchemy import JSON, BigInteger, Date, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, utcnow


class Repo(Base):
    __tablename__ = "repos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    github_id: Mapped[int] = mapped_column(BigInteger, unique=True)  # GitHub ids can grow past 2^31
    full_name: Mapped[str] = mapped_column(String(255), unique=True)  # "owner/name"
    owner: Mapped[str] = mapped_column(String(100))
    name: Mapped[str] = mapped_column(String(150))
    description: Mapped[str | None] = mapped_column(Text)
    html_url: Mapped[str] = mapped_column(String(500))
    homepage: Mapped[str | None] = mapped_column(String(500))
    language: Mapped[str | None] = mapped_column(String(100), index=True)
    topics: Mapped[list[str]] = mapped_column(JSON, default=list)  # ["flutter", "dart"]
    stars: Mapped[int] = mapped_column(Integer, default=0, index=True)
    forks: Mapped[int] = mapped_column(Integer, default=0)
    open_issues: Mapped[int] = mapped_column(Integer, default=0)
    license: Mapped[str | None] = mapped_column(String(100))  # SPDX id, e.g. "MIT"
    owner_avatar_url: Mapped[str | None] = mapped_column(String(500))
    github_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    github_pushed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    readme: Mapped[str | None] = mapped_column(Text)

    summary: Mapped["RepoSummary | None"] = relationship(back_populates="repo")


class RepoSummary(Base):
    """AI summary + quickstart of a repo (one per repo)."""

    __tablename__ = "repo_summaries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    repo_id: Mapped[int] = mapped_column(ForeignKey("repos.id", ondelete="CASCADE"), unique=True)
    summary: Mapped[str] = mapped_column(Text)
    quickstart: Mapped[str | None] = mapped_column(Text)
    model: Mapped[str | None] = mapped_column(String(100))  # which LLM produced it
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    repo: Mapped["Repo"] = relationship(back_populates="summary")


class RepoStarSnapshot(Base):
    """Star count of a repo on one day (GitHub has no star history, so we record it)."""

    __tablename__ = "repo_star_snapshots"
    __table_args__ = (UniqueConstraint("repo_id", "date"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    repo_id: Mapped[int] = mapped_column(ForeignKey("repos.id", ondelete="CASCADE"), index=True)
    date: Mapped[DateType] = mapped_column(Date)
    stars: Mapped[int] = mapped_column(Integer)


class RepoRelease(Base):
    """Latest release seen for a repo, used to detect new releases."""

    __tablename__ = "repo_releases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    repo_id: Mapped[int] = mapped_column(ForeignKey("repos.id", ondelete="CASCADE"), unique=True)
    tag_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[str | None] = mapped_column(String(255))
    html_url: Mapped[str | None] = mapped_column(String(500))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    checked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
