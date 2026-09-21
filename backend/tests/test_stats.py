from datetime import date, datetime, timezone

import pytest

from app.core.security import hash_password
from app.models import Collection, Note, Repo, User, UserRepo
from app.services import stats_service

URL = "/api/v1/stats"

# Wednesday 2026-09-23 -> the current week starts on Monday 2026-09-21
NOW = datetime(2026, 9, 23, 12, 0, tzinfo=timezone.utc)


def assert_error(response, status_code: int, code: str):
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert body["error"]["code"] == code


def make_repo(db, n: int, language: str | None) -> Repo:
    repo = Repo(
        github_id=1000 + n,
        full_name=f"owner{n}/repo{n}",
        owner=f"owner{n}",
        name=f"repo{n}",
        html_url=f"https://github.com/owner{n}/repo{n}",
        language=language,
        stars=n,
    )
    db.add(repo)
    db.commit()
    return repo


def add_status(db, user_id, repo_id, status, started_at=None, completed_at=None):
    db.add(
        UserRepo(
            user_id=user_id,
            repo_id=repo_id,
            status=status,
            started_at=started_at,
            completed_at=completed_at,
        )
    )
    db.commit()


@pytest.fixture
def other_user(db) -> User:
    other = User(email="other@example.com", password_hash=hash_password("secret123"), display_name="B")
    db.add(other)
    db.commit()
    return other


@pytest.fixture
def data(db, user, other_user):
    """Repos + learning statuses for `user`, plus some rows of another user that must be ignored."""
    make_repo(db, 1, "Python")
    make_repo(db, 2, "Python")
    make_repo(db, 3, "Dart")
    make_repo(db, 4, None)
    make_repo(db, 5, None)

    # this week (Mon 21 Sep): repo 1 started + completed, repo 2 started
    add_status(db, user.id, 1, "used", datetime(2026, 9, 21, 8, 0), datetime(2026, 9, 22, 9, 0))
    add_status(db, user.id, 2, "learning", datetime(2026, 9, 23, 1, 0))
    # 2 weeks ago (Mon 7 Sep): repo 3 started; completed last week (Sun 20 Sep, just before Monday)
    add_status(db, user.id, 3, "used", datetime(2026, 9, 7, 0, 0), datetime(2026, 9, 20, 23, 59))
    # no dates
    add_status(db, user.id, 4, "want_to_try")
    add_status(db, user.id, 5, "want_to_try")

    # another user's rows and data: never counted
    add_status(db, other_user.id, 1, "used", datetime(2026, 9, 21), datetime(2026, 9, 22))
    db.add(Collection(user_id=other_user.id, name="theirs"))
    db.add(Note(user_id=other_user.id, repo_id=1, content="theirs"))

    db.add(Collection(user_id=user.id, name="A"))
    db.add(Collection(user_id=user.id, name="B"))
    db.add(Note(user_id=user.id, repo_id=1, content="mine"))
    db.commit()


# ---------- week_start ----------

@pytest.mark.parametrize(
    "value, expected",
    [
        (datetime(2026, 9, 21, 0, 0, tzinfo=timezone.utc), date(2026, 9, 21)),  # Monday itself
        (datetime(2026, 9, 27, 23, 59, tzinfo=timezone.utc), date(2026, 9, 21)),  # Sunday
        (datetime(2026, 9, 20, 23, 59), date(2026, 9, 14)),  # naive (SQLite) = UTC
    ],
)
def test_week_start(value, expected):
    assert stats_service.week_start(value) == expected


# ---------- overview ----------

def test_overview(db, user, data):
    result = stats_service.get_overview(db, user.id, now=NOW)
    assert result == {
        "total_repos": 5,
        "by_status": {"want_to_try": 2, "learning": 1, "used": 2},
        "collections_count": 2,
        "notes_count": 1,
        "completed_this_week": 1,  # repo 3 was completed last Sunday
    }


def test_overview_empty_has_all_status_keys(client, auth_headers):
    response = client.get(f"{URL}/overview", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == {
        "total_repos": 0,
        "by_status": {"want_to_try": 0, "learning": 0, "used": 0},
        "collections_count": 0,
        "notes_count": 0,
        "completed_this_week": 0,
    }


def test_overview_endpoint_uses_current_time(client, auth_headers, data, monkeypatch):
    monkeypatch.setattr(stats_service, "utcnow", lambda: NOW)
    body = client.get(f"{URL}/overview", headers=auth_headers).json()
    assert body["total_repos"] == 5
    assert body["completed_this_week"] == 1


# ---------- weekly ----------

def test_weekly_zero_fills_weeks(db, user, data):
    result = stats_service.get_weekly(db, user.id, weeks=4, now=NOW)
    assert result == [
        {"week_start": date(2026, 8, 31), "completed": 0, "started": 0},
        {"week_start": date(2026, 9, 7), "completed": 0, "started": 1},
        {"week_start": date(2026, 9, 14), "completed": 1, "started": 0},
        {"week_start": date(2026, 9, 21), "completed": 1, "started": 2},
    ]


def test_weekly_ignores_dates_outside_range(db, user, data):
    # 1 week = only the current week; repo 3 (started 7 Sep, completed 20 Sep) is outside
    result = stats_service.get_weekly(db, user.id, weeks=1, now=NOW)
    assert result == [{"week_start": date(2026, 9, 21), "completed": 1, "started": 2}]


def test_weekly_endpoint(client, auth_headers, data, monkeypatch):
    monkeypatch.setattr(stats_service, "utcnow", lambda: NOW)
    response = client.get(f"{URL}/weekly", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 8  # default
    assert body[0] == {"week_start": "2026-08-03", "completed": 0, "started": 0}
    assert body[-1] == {"week_start": "2026-09-21", "completed": 1, "started": 2}


@pytest.mark.parametrize("weeks", [0, 53, "abc"])
def test_weekly_invalid_weeks(client, auth_headers, weeks):
    response = client.get(f"{URL}/weekly", params={"weeks": weeks}, headers=auth_headers)
    assert_error(response, 422, "VALIDATION_ERROR")


# ---------- languages ----------

def test_languages_groups_missing_as_other(db, user, data):
    result = stats_service.get_languages(db, user.id)
    assert result == [
        {"language": "Other", "count": 2},
        {"language": "Python", "count": 2},
        {"language": "Dart", "count": 1},
    ]


def test_languages_endpoint(client, auth_headers, data):
    response = client.get(f"{URL}/languages", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()[2] == {"language": "Dart", "count": 1}


def test_languages_empty(client, auth_headers):
    assert client.get(f"{URL}/languages", headers=auth_headers).json() == []


def test_stats_require_login(client):
    for path in ("overview", "weekly", "languages"):
        assert_error(client.get(f"{URL}/{path}"), 401, "UNAUTHORIZED")
