"""Tests for the generate_summaries job."""

from sqlalchemy import select

from app.core.config import settings
from app.core.errors import AppError, ErrorCode
from app.jobs import ai_jobs
from app.models import Repo, RepoSummary
from app.services import ai_client


def make_repo(db, n, readme="Some README text for this repo.", stars=0):
    repo = Repo(
        github_id=n,
        full_name=f"owner/repo{n}",
        owner="owner",
        name=f"repo{n}",
        html_url=f"https://github.com/owner/repo{n}",
        readme=readme,
        stars=stars,
    )
    db.add(repo)
    db.commit()
    return repo


def test_generate_summaries_creates_and_skips_failures(db, monkeypatch):
    ok = make_repo(db, 1, stars=10)
    broken = make_repo(db, 2, stars=50)
    no_readme = make_repo(db, 3, readme=None, stars=100)
    indexed = []

    def fake_summarize(repo_id, full_name, readme):
        if repo_id == broken.id:
            raise AppError(502, ErrorCode.UPSTREAM_ERROR, "boom")
        return {"summary": f"Tóm tắt {full_name}", "quickstart": "pip install x", "model": "test-llm"}

    def fake_index(repo_id, full_name, documents):
        indexed.append((repo_id, documents))
        return {"chunks": 1}

    monkeypatch.setattr(ai_client, "summarize", fake_summarize)
    monkeypatch.setattr(ai_client, "index", fake_index)

    assert ai_jobs.generate_summaries(db) == 1

    summaries = db.scalars(select(RepoSummary)).all()
    assert [(s.repo_id, s.summary, s.model) for s in summaries] == [(ok.id, "Tóm tắt owner/repo1", "test-llm")]
    assert indexed == [(ok.id, [{"path": "README.md", "content": ok.readme}])]
    assert no_readme.id not in [s.repo_id for s in summaries]

    # Next run: only the broken repo is left to try.
    assert [r.id for r in ai_jobs.repos_without_summary(db)] == [broken.id]


def test_generate_summaries_most_stars_first_and_limited(db):
    for n in range(1, 13):
        make_repo(db, n, stars=n)
    picked = ai_jobs.repos_without_summary(db)
    assert len(picked) == ai_jobs.BATCH_SIZE
    assert picked[0].stars == 12


def test_generate_summaries_with_fallback(db, monkeypatch):
    monkeypatch.setattr(settings, "ai_engine_url", "")
    make_repo(db, 1, readme="# X\n\nX is a small library that makes HTTP requests simple and fun.")
    assert ai_jobs.generate_summaries(db) == 1
    summary = db.scalar(select(RepoSummary))
    assert summary.model == "fallback"
    assert summary.summary.startswith("X is a small library")


def test_jobs_registered():
    assert [job["id"] for job in ai_jobs.JOBS] == ["generate_summaries"]
