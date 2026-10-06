import hashlib
import os
import subprocess
import sys
import wave
from pathlib import Path

from app.core.config import settings
from app.services.numbers import spell_text

def cache_key(text: str, voice: str) -> str:
    return hashlib.sha256(f"{voice}\x00{text}".encode("utf-8")).hexdigest()

def synthesize(text: str, voice: str, cache_dir: Path) -> Path:
    spelled_text = spell_text(text)
    key = cache_key(spelled_text, voice)
    
    cache_dir.mkdir(parents=True, exist_ok=True)
    out_path = cache_dir / f"{key}.wav"
    
    if out_path.exists():
        return out_path
        
    tmp_path = out_path.with_suffix('.tmp.wav')
    _run_piper(spelled_text, voice, tmp_path)
    
    os.replace(tmp_path, out_path)
    return out_path

def _run_piper(text: str, voice: str, out_path: Path):
    subprocess.run(
        [
            sys.executable, "-m", settings.piper_bin,
            "--data-dir", str(settings.models_dir),
            "-m", voice,
            "-f", str(out_path),
            "--", text,
        ],
        capture_output=True, check=True, timeout=120,
    )

def wav_duration(path: Path) -> float:
    with wave.open(str(path), 'rb') as w:
        return w.getnframes() / w.getframerate()
