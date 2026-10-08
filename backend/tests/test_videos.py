"""The /videos routes: on-demand render and public MP4 serving."""

import httpx
import pytest

from app.core.config import settings
from app.models import GeneratedVideo, Repo, UserRepo
from app.services import video_client

URL = "/api/v1/videos"

RESULT = {"path": "/data/videos/whatever.mp4", "duration_seconds": 12.4, "size_bytes": 1024}


def assert_error(response, status_code: int, code: str):
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert body["error"]["code"] == code


@pytest.fixture
def roadmap(db, user) -> list[UserRepo]:
    """Two repos in the user's roadmap, with language and stars."""
    rows = []
    for n, (language, stars, status) in enumerate(
        [("Go", 900, "learning"), ("Python", 10, "used")], start=1
    ):
        repo = Repo(
            github_id=2000 + n,
            full_name=f"owner{n}/repo{n}",
            owner=f"owner{n}",
            name=f"repo{n}",
            html_url=f"https://github.com/owner{n}/repo{n}",
            language=language,
            stars=stars,
        )
        db.add(repo)
        db.commit()
        row = UserRepo(user_id=user.id, repo_id=repo.id, status=status)
        db.add(row)
        db.commit()
        rows.append(row)
    return rows


@pytest.fixture
def engine(monkeypatch):
    monkeypatch.setattr(settings, "video_engine_url", "http://video-engine:9000")

    def install(handler):
        transport = httpx.MockTransport(handler)
        monkeypatch.setattr(
            video_client,
            "_make_client",
            lambda: httpx.Client(transport=transport, base_url="http://video-engine:9000"),
        )

    return install


def test_post_roadmap_renders_and_returns_a_relative_url(client, auth_headers, db, roadmap, engine):
    engine(lambda request: httpx.Response(200, json=RESULT))

    response = client.post(f"{URL}/roadmap", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["url"] == f"{URL}/{body['job_id']}"
    assert body["url"].startswith("/")
    assert body["duration_seconds"] == pytest.approx(12.4)
    assert body["size_bytes"] == 1024

    saved = db.query(GeneratedVideo).filter_by(job_id=body["job_id"]).one()
    assert saved.duration_seconds == pytest.approx(12.4)


def test_post_roadmap_requires_auth(client, roadmap, engine):
    engine(lambda request: httpx.Response(200, json=RESULT))

    assert client.post(f"{URL}/roadmap").status_code == 401


def test_post_roadmap_with_empty_roadmap_is_400(client, auth_headers):
    response = client.post(f"{URL}/roadmap", headers=auth_headers)

    assert_error(response, 400, "BAD_REQUEST")


def test_post_roadmap_engine_timeout_is_504(client, auth_headers, roadmap, engine):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("too slow", request=request)

    engine(handler)

    assert_error(client.post(f"{URL}/roadmap", headers=auth_headers), 504, "UPSTREAM_TIMEOUT")


def test_post_roadmap_engine_error_is_502(client, auth_headers, roadmap, engine):
    engine(lambda request: httpx.Response(500, json={"detail": "boom"}))

    assert_error(client.post(f"{URL}/roadmap", headers=auth_headers), 502, "UPSTREAM_ERROR")


def test_get_serves_file_without_auth(client, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))
    (tmp_path / "jobabc.mp4").write_bytes(b"fake mp4 bytes")

    response = client.get(f"{URL}/jobabc")

    assert response.status_code == 200
    assert response.headers["content-type"] == "video/mp4"
    assert response.content == b"fake mp4 bytes"


def test_get_unknown_job_is_404(client, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))

    assert_error(client.get(f"{URL}/missing"), 404, "NOT_FOUND")


@pytest.mark.parametrize("job_id", ["x" * 65, "bad.id"])
def test_get_malformed_job_id_is_404(client, tmp_path, monkeypatch, job_id):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))
    # A file that WOULD match if the guard were missing.
    (tmp_path / f"{job_id}.mp4").write_bytes(b"nope")

    assert_error(client.get(f"{URL}/{job_id}"), 404, "NOT_FOUND")
