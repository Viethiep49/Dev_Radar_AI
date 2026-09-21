"""Tests for release checking (baseline, new tag -> notifications) and the demo script."""

import sys

from sqlalchemy import select

from app.jobs import release_jobs
from app.models import Notification, Repo, RepoRelease, User, Watchlist
from app.services import github_client, release_service


def make_repo(db, n):
    repo = Repo(
        github_id=n,
        full_name=f"owner/repo{n}",
        owner="owner",
        name=f"repo{n}",
        html_url=f"https://github.com/owner/repo{n}",
    )
    db.add(repo)
    db.commit()
    return repo


def make_user(db, email):
    user = User(email=email, password_hash="x", display_name=email)
    db.add(user)
    db.commit()
    return user


def watch(db, user, repo):
    db.add(Watchlist(user_id=user.id, repo_id=repo.id))
    db.commit()


def fake_github(monkeypatch, releases: dict):
    """github_client.get_latest_release answers from `releases` ({full_name: release or exception})."""

    def get_latest_release(full_name):
        value = releases.get(full_name)
        if isinstance(value, Exception):
            raise value
        return value

    monkeypatch.setattr(github_client, "get_latest_release", get_latest_release, raising=False)


def release(tag, name=None):
    return {
        "tag_name": tag,
        "name": name,
        "html_url": f"https://github.com/x/releases/tag/{tag}",
        "published_at": "2026-09-21T10:00:00Z",
    }


def test_baseline_then_new_tag(db, user, monkeypatch):
    repo = make_repo(db, 1)
    other = make_user(db, "other@example.com")
    watch(db, user, repo)
    watch(db, other, repo)
    make_repo(db, 2)  # not watched: must not be checked

    checked = []
    releases = {"owner/repo1": release("v1.0")}

    def get_latest_release(full_name):
        checked.append(full_name)
        return releases[full_name]

    monkeypatch.setattr(github_client, "get_latest_release", get_latest_release, raising=False)

    # First run: baseline only, no notification.
    assert release_service.check_releases(db, sleep_seconds=0) == 0
    assert db.scalar(select(RepoRelease)).tag_name == "v1.0"
    assert db.scalars(select(Notification)).all() == []
    assert checked == ["owner/repo1"]

    # Same tag again: still nothing.
    assert release_service.check_releases(db, sleep_seconds=0) == 0

    # New tag: one notification per watcher.
    releases["owner/repo1"] = release("v2.0", name="Big release")
    assert release_service.check_releases(db, sleep_seconds=0) == 2

    notifications = db.scalars(select(Notification).order_by(Notification.user_id)).all()
    assert [n.user_id for n in notifications] == [user.id, other.id]
    first = notifications[0]
    assert first.type == "release"
    assert first.title == "owner/repo1 vừa phát hành v2.0"
    assert first.body == "Big release"
    assert first.repo_id == repo.id
    assert first.data == {"tag_name": "v2.0", "html_url": "https://github.com/x/releases/tag/v2.0"}
    assert db.scalar(select(RepoRelease)).tag_name == "v2.0"


def test_release_without_name_uses_default_body(db, user, monkeypatch):
    repo = make_repo(db, 1)
    watch(db, user, repo)
    db.add(RepoRelease(repo_id=repo.id, tag_name="v1.0"))
    db.commit()
    fake_github(monkeypatch, {"owner/repo1": release("v1.1")})

    assert release_service.check_releases(db, sleep_seconds=0) == 1
    assert db.scalar(select(Notification)).body == "Có phiên bản mới"


def test_github_error_and_no_release_are_skipped(db, user, monkeypatch):
    broken = make_repo(db, 1)
    no_release = make_repo(db, 2)
    ok = make_repo(db, 3)
    for repo in (broken, no_release, ok):
        watch(db, user, repo)
    db.add(RepoRelease(repo_id=ok.id, tag_name="v1.0"))
    db.commit()

    fake_github(
        monkeypatch,
        {
            "owner/repo1": github_client.GitHubError("rate limited"),
            "owner/repo2": None,
            "owner/repo3": release("v1.1"),
        },
    )
    assert release_service.check_releases(db, sleep_seconds=0) == 1
    assert [r.repo_id for r in db.scalars(select(RepoRelease)).all()] == [ok.id]


def test_send_push_is_called(db, user, monkeypatch):
    from app.services import notification_service

    repo = make_repo(db, 1)
    watch(db, user, repo)
    pushed = []
    monkeypatch.setattr(notification_service, "send_push", lambda n: pushed.append(n.title))

    release_service.notify_new_release(db, repo, release("v3.0"))
    assert pushed == ["owner/repo1 vừa phát hành v3.0"]


def test_job_never_raises(monkeypatch):
    def boom(db):
        raise RuntimeError("DB down")

    monkeypatch.setattr(release_service, "check_releases", boom)
    release_jobs.check_releases_job()  # must not raise
    assert [job["id"] for job in release_jobs.JOBS] == ["check_releases"]


def test_simulate_release_script(db, user, monkeypatch, capsys):
    from scripts import simulate_release

    repo = make_repo(db, 1)
    watch(db, user, repo)

    class SessionFactory:
        """Stand-in for SessionLocal that hands out the test session."""

        def __call__(self):
            return self

        def __enter__(self):
            return db

        def __exit__(self, *args):
            return False

    monkeypatch.setattr(simulate_release, "SessionLocal", SessionFactory())
    monkeypatch.setattr(sys, "argv", ["simulate_release", "owner/repo1", "v9.9.9"])
    simulate_release.main()

    notification = db.scalar(select(Notification))
    assert notification.title == "owner/repo1 vừa phát hành v9.9.9"
    assert db.scalar(select(RepoRelease)).tag_name == "v9.9.9"
    assert "created 1 notification" in capsys.readouterr().out
