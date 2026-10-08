"""The generated_videos table exists, is unique per job_id, and cascades from users."""

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models import GeneratedVideo


def test_row_persists_with_defaults(db, user):
    video = GeneratedVideo(
        job_id="abc123",
        user_id=user.id,
        duration_seconds=12.4,
        size_bytes=1024,
    )
    db.add(video)
    db.commit()

    saved = db.scalars(select(GeneratedVideo).where(GeneratedVideo.job_id == "abc123")).one()
    assert saved.user_id == user.id
    assert saved.duration_seconds == pytest.approx(12.4)
    assert saved.size_bytes == 1024
    assert saved.created_at is not None


def test_job_id_is_unique(db, user):
    for _ in range(2):
        db.add(
            GeneratedVideo(
                job_id="dupe", user_id=user.id, duration_seconds=1.0, size_bytes=1
            )
        )

    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_deleting_the_user_deletes_the_video(db, user):
    db.add(
        GeneratedVideo(
            job_id="cascade", user_id=user.id, duration_seconds=1.0, size_bytes=1
        )
    )
    db.commit()

    db.delete(user)
    db.commit()

    assert db.scalars(select(GeneratedVideo)).all() == []
