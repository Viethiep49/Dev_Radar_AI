"""Tests for the pure VideoSpec builder (no DB, no HTTP)."""

import re

import pytest

from app.core.errors import AppError
from app.models import Repo, UserRepo
from app.services.video_spec import build_roadmap_spec

FULL_NAME_PATTERN = re.compile(r"^[^/\s]+/[^/\s]+$")


def make_repo(n: int, language: str | None = "Go", stars: int = 10, description: str | None = None) -> Repo:
    return Repo(
        id=n,
        github_id=1000 + n,
        full_name=f"owner{n}/repo{n}",
        owner=f"owner{n}",
        name=f"repo{n}",
        html_url=f"https://github.com/owner{n}/repo{n}",
        language=language,
        stars=stars,
        description=description,
    )


def make_row(repo: Repo, status: str) -> UserRepo:
    return UserRepo(user_id=1, repo_id=repo.id, repo=repo, status=status)


def test_builds_six_slides_for_a_full_roadmap():
    rows = [
        make_row(make_repo(1, language="Go", stars=100), "learning"),
        make_row(make_repo(2, language="Python", stars=50), "used"),
        make_row(make_repo(3, language="Go", stars=10), "used"),
    ]

    spec = build_roadmap_spec("job1", "An", rows)

    assert [slide["kind"] for slide in spec["slides"]] == [
        "hook", "stat", "stat", "list", "repo", "outro",
    ]
    assert spec["job_id"] == "job1"
    assert spec["quality"] == "720p"
    assert len(spec["title"]) <= 80


def test_stat_values_are_strings_within_twelve_chars():
    rows = [
        make_row(make_repo(1), "learning"),
        make_row(make_repo(2), "used"),
        make_row(make_repo(3), "used"),
    ]

    spec = build_roadmap_spec("job1", "An", rows)
    stats = [slide for slide in spec["slides"] if slide["kind"] == "stat"]

    assert [slide["value"] for slide in stats] == ["1", "2"]
    assert all(isinstance(slide["value"], str) for slide in stats)
    assert all(len(slide["value"]) <= 12 for slide in stats)


def test_list_slide_ranks_languages_by_count():
    rows = [
        make_row(make_repo(1, language="Go"), "learning"),
        make_row(make_repo(2, language="Go"), "used"),
        make_row(make_repo(3, language="Python"), "used"),
        make_row(make_repo(4, language="Rust"), "want_to_try"),
    ]

    spec = build_roadmap_spec("job1", "An", rows)
    list_slides = [slide for slide in spec["slides"] if slide["kind"] == "list"]

    assert len(list_slides) == 1
    assert list_slides[0]["items"] == ["Go", "Python", "Rust"]


def test_list_slide_falls_back_to_repo_names_then_is_dropped():
    # No languages at all -> repo names.
    rows = [
        make_row(make_repo(1, language=None), "learning"),
        make_row(make_repo(2, language=None), "used"),
    ]
    spec = build_roadmap_spec("job1", "An", rows)
    list_slides = [slide for slide in spec["slides"] if slide["kind"] == "list"]
    assert list_slides[0]["items"] == ["owner1/repo1", "owner2/repo2"]

    # A single repo cannot fill a 2-item list -> slide dropped entirely.
    spec = build_roadmap_spec("job1", "An", [make_row(make_repo(1, language=None), "learning")])
    assert all(slide["kind"] != "list" for slide in spec["slides"])
    assert len(spec["slides"]) >= 2


def test_repo_slide_picks_the_most_starred_repo():
    rows = [
        make_row(make_repo(1, stars=5), "learning"),
        make_row(make_repo(2, stars=900), "used"),
    ]

    spec = build_roadmap_spec("job1", "An", rows)
    repo_slides = [slide for slide in spec["slides"] if slide["kind"] == "repo"]

    assert len(repo_slides) == 1
    assert repo_slides[0]["full_name"] == "owner2/repo2"
    assert repo_slides[0]["stars"] == 900


def test_skips_repos_with_invalid_full_name():
    bad = make_repo(1)
    bad.full_name = "no-slash-here"
    rows = [make_row(bad, "learning"), make_row(make_repo(2), "used")]

    spec = build_roadmap_spec("job1", "An", rows)
    repo_slides = [slide for slide in spec["slides"] if slide["kind"] == "repo"]

    assert repo_slides[0]["full_name"] == "owner2/repo2"


def test_raises_bad_request_when_nothing_is_renderable():
    with pytest.raises(AppError) as exc:
        build_roadmap_spec("job1", "An", [])
    assert exc.value.status_code == 400
    assert exc.value.code == "BAD_REQUEST"


def test_clips_every_bounded_field():
    long_description = "x" * 500
    rows = [
        make_row(make_repo(1, description=long_description), "learning"),
        make_row(make_repo(2, description=long_description), "used"),
    ]

    spec = build_roadmap_spec("job1", "N" * 200, rows)

    assert len(spec["title"]) <= 80
    for slide in spec["slides"]:
        assert 1 <= len(slide["narration"]) <= 300
        if slide["kind"] == "repo":
            assert len(slide["full_name"]) <= 120
            assert FULL_NAME_PATTERN.match(slide["full_name"])
            assert len(slide["description"]) <= 300
        if slide["kind"] in ("hook", "outro"):
            assert len(slide["title"]) <= 60
            assert len(slide["subtitle"]) <= 90
