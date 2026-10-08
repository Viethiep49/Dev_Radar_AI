import pytest
import sys
from pathlib import Path
import subprocess
import wave

from unittest.mock import MagicMock
sys.modules['cairosvg'] = MagicMock()
sys.modules['cairosvg'].svg2png.return_value = b"\x89PNG\r\n\x1a\n"

from app.schemas.spec import VideoSpec, HookSlide
from app.services.render import render_job


def _write_wav(path: Path, seconds: float, rate: int = 22050) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(b"\x00\x00" * int(rate * seconds))


def _stub_pipeline(monkeypatch, calls: list) -> None:
    """Stub piper, wav parsing and ffmpeg so render_job runs without real tools.

    `calls` collects the argv of every ffmpeg invocation; its last element is the
    file ffmpeg was told to write, i.e. the one render_job then moves into out_dir.
    """

    def fake_synthesize(text, voice, cache_dir):
        cache_dir.mkdir(parents=True, exist_ok=True)
        p = cache_dir / f"test_{hash(text)}.wav"
        _write_wav(p, 1.0)
        return p

    def fake_wav_duration(path):
        return 1.0

    monkeypatch.setattr("app.services.render.synthesize", fake_synthesize)
    monkeypatch.setattr("app.services.render.wav_duration", fake_wav_duration)

    def fake_run(*args, **kwargs):
        called_args = args[0] if args else kwargs.get("args", [])
        calls.append(called_args)
        out = Path(called_args[-1])
        out.write_bytes(b"dummy_mp4_content")
        return subprocess.CompletedProcess(args=called_args, returncode=0)

    monkeypatch.setattr(subprocess, "run", fake_run)


def _spec(job_id: str = "test_render_01") -> VideoSpec:
    return VideoSpec(
        job_id=job_id,
        title="Test Video",
        quality="720p",
        slides=[
            HookSlide(title="A", narration="B"),
            HookSlide(title="C", narration="D"),
        ],
    )


def test_render_job_orchestrates_a_spec_into_a_video_file_and_result(tmp_path, monkeypatch):
    calls = []
    _stub_pipeline(monkeypatch, calls)

    res = render_job(_spec(), tmp_path)

    assert res.path.endswith("test_render_01.mp4")
    assert res.size_bytes == len(b"dummy_mp4_content")
    assert res.duration_seconds > 2.0
    assert calls[0][0] == "ffmpeg"


def test_stages_the_video_on_the_output_filesystem(tmp_path, monkeypatch):
    """os.replace is rename(2) and cannot cross filesystems.

    In Docker the scratch dir (/tmp) and the video volume (/data/videos) are
    different mounts, so staging in the system temp dir raised
    OSError(EXDEV) only after a full render. Staging must happen under out_dir.
    """
    calls = []
    _stub_pipeline(monkeypatch, calls)
    out_dir = tmp_path / "videos"
    out_dir.mkdir()

    render_job(_spec(), out_dir)

    staged = Path(calls[0][-1])
    assert out_dir in staged.parents
