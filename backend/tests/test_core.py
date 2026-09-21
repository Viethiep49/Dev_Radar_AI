"""Tests for shared building blocks: pagination and the scheduler."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.pagination import Page, PageParams, paginate
from app.db.session import get_db
from app.jobs import repo_jobs, scheduler
from app.models import User
from app.schemas.auth import UserOut


def test_paginate(app, client, db):
    for i in range(25):
        db.add(User(email=f"u{i}@example.com", password_hash="x", display_name=f"U{i}"))
    db.commit()

    router = APIRouter()

    @router.get("/test-users", response_model=Page[UserOut])
    def list_users(params: PageParams = Depends(), session: Session = Depends(get_db)):
        return paginate(session, select(User).order_by(User.id), params)

    app.include_router(router)

    body = client.get("/test-users?page=2&limit=10").json()
    assert body["page"] == 2
    assert body["limit"] == 10
    assert body["total"] == 25
    assert [u["email"] for u in body["items"]][0] == "u10@example.com"
    assert len(body["items"]) == 10

    last = client.get("/test-users?page=3&limit=10").json()
    assert len(last["items"]) == 5

    bad = client.get("/test-users?limit=500")
    assert bad.status_code == 422
    assert bad.json()["error"]["code"] == "VALIDATION_ERROR"


def test_scheduler_registers_jobs(monkeypatch):
    def dummy_job():
        pass

    monkeypatch.setattr(
        repo_jobs,
        "JOBS",
        [{"id": "dummy", "func": dummy_job, "trigger": "interval", "kwargs": {"hours": 6}}],
    )
    sched = scheduler.build_scheduler()
    assert [job.id for job in sched.get_jobs()] == ["dummy"]


def test_safe_job_does_not_raise():
    def broken_job():
        raise RuntimeError("GitHub is down")

    scheduler.safe_job(broken_job)()  # must not raise
