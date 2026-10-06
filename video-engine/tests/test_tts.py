import wave
from pathlib import Path
import pytest

from app.services.tts import cache_key, synthesize, wav_duration

def test_cache_key_is_stable_and_voice_scoped():
    assert cache_key("xin chào", "vi_VN-vais1000-medium") == cache_key("xin chào", "vi_VN-vais1000-medium")
    assert cache_key("xin chào", "vi_VN-vais1000-medium") != cache_key("xin chào", "khác")
    assert len(cache_key("xin chào", "vi_VN-vais1000-medium")) == 64

def test_wav_duration_reads_the_real_length(tmp_path):
    path = tmp_path / "a.wav"
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(22050)
        handle.writeframes(b"\x00\x00" * 22050)
    assert wav_duration(path) == pytest.approx(1.0, abs=0.01)

def test_synthesize_spells_numbers_before_speaking(tmp_path, monkeypatch):
    seen: list[str] = []

    def fake_run(text, voice, out_path):
        seen.append(text)
        with wave.open(str(out_path), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(22050)
            handle.writeframes(b"\x00\x00" * 2205)

    monkeypatch.setattr("app.services.tts._run_piper", fake_run)
    synthesize("Hoàn thành 12 repo", "vi_VN-vais1000-medium", tmp_path)
    assert seen == ["Hoàn thành mười hai repo"]

def test_synthesize_reuses_the_cached_file_on_a_second_call(tmp_path, monkeypatch):
    calls = {"n": 0}

    def fake_run(text, voice, out_path):
        calls["n"] += 1
        with wave.open(str(out_path), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(22050)
            handle.writeframes(b"\x00\x00" * 2205)

    monkeypatch.setattr("app.services.tts._run_piper", fake_run)
    first = synthesize("xin chào", "vi_VN-vais1000-medium", tmp_path)
    second = synthesize("xin chào", "vi_VN-vais1000-medium", tmp_path)
    assert first == second
    assert calls["n"] == 1
