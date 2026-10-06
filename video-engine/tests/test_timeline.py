import wave
from pathlib import Path

import pytest

from app.services.timeline import (
    GAP_SECONDS,
    MIN_SLIDE_SECONDS,
    build_ffconcat,
    concat_wavs,
    ffmpeg_args,
    slide_durations,
)


def _write_wav(path: Path, seconds: float, rate: int = 22050) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(b"\x00\x00" * int(rate * seconds))


def test_slide_durations_adds_gap_and_enforces_a_floor():
    assert slide_durations([3.0, 0.1]) == pytest.approx([3.0 + GAP_SECONDS, MIN_SLIDE_SECONDS])


def test_concat_wavs_writes_one_track_and_returns_total_seconds(tmp_path):
    first, second = tmp_path / "a.wav", tmp_path / "b.wav"
    _write_wav(first, 1.0)
    _write_wav(second, 2.0)
    out = tmp_path / "joined.wav"

    total = concat_wavs([(first, 1.0), (second, 2.0)], out, gap_seconds=0.35)

    assert total == pytest.approx(3.35, abs=0.05)
    with wave.open(str(out), "rb") as handle:
        assert handle.getnchannels() == 1
        assert handle.getframerate() == 22050
        assert handle.getnframes() == pytest.approx(22050 * 3.35, abs=2000)


def test_concat_wavs_rejects_mismatched_sample_rates(tmp_path):
    first, second = tmp_path / "a.wav", tmp_path / "b.wav"
    _write_wav(first, 1.0, rate=22050)
    _write_wav(second, 1.0, rate=44100)
    with pytest.raises(ValueError):
        concat_wavs([(first, 1.0), (second, 1.0)], tmp_path / "joined.wav", gap_seconds=0.0)


def test_build_ffconcat_repeats_the_last_image_without_a_duration():
    body = build_ffconcat([(Path("/tmp/s0.png"), 3.0), (Path("/tmp/s1.png"), 2.0)])
    lines = body.strip().splitlines()
    assert lines[0] == "ffconcat version 1.0"
    assert "file '/tmp/s0.png'" in lines
    assert "duration 3.0" in lines
    assert lines[-1] == "file '/tmp/s1.png'"


def test_ffmpeg_args_target_h264_aac_and_faststart():
    args = ffmpeg_args(Path("/tmp/s.ffconcat"), Path("/tmp/a.wav"), Path("/tmp/o.mp4"), (720, 1280), 30)
    assert args[0] == "-y"
    assert "-safe" in args and args[args.index("-safe") + 1] == "0"
    assert "-pix_fmt" in args and args[args.index("-pix_fmt") + 1] == "yuv420p"
    assert "libx264" in args
    assert "aac" in args
    assert "-movflags" in args and args[args.index("-movflags") + 1] == "+faststart"
    assert "-shortest" in args
    assert args[-1] == "/tmp/o.mp4"
