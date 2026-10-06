import subprocess
from pathlib import Path

from app.schemas.spec import HookSlide
from app.services.tts import TTSClient

def test_tts_client_synthesize_slide_shell_out(tmp_path, monkeypatch):
    run_called_with = []

    def fake_run(*args, **kwargs):
        called_args = args[0] if args else kwargs.get("args", [])
        run_called_with.append(called_args)
        # args[-3] is the output path
        Path(called_args[-3]).write_bytes(b"wav")
        return subprocess.CompletedProcess(args=called_args, returncode=0)

    monkeypatch.setattr(subprocess, "run", fake_run)
    client = TTSClient()
    slide = HookSlide(title="Lộ", narration="Xin chào")
    out = client.synthesize_slide(slide, tmp_path)
    
    assert out.exists()
    assert run_called_with[0][-1] == "Xin chào"
    assert "vi_VN-vais1000-medium" in run_called_with[0]
