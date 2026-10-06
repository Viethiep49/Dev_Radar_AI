import pytest
import sys
from unittest.mock import MagicMock
sys.modules['cairosvg'] = MagicMock()
sys.modules['cairosvg'].svg2png.return_value = b"\x89PNG\r\n\x1a\n"

from fastapi.testclient import TestClient

from app.main import app
from app.schemas.spec import RenderResult

client = TestClient(app)

def test_post_render_delegates_to_render_job(monkeypatch):
    def fake_render_job(spec, out_dir):
        return RenderResult(path=str(out_dir / f"{spec.job_id}.mp4"), duration_seconds=5.5, size_bytes=1000)
        
    monkeypatch.setattr("app.main.render_job", fake_render_job)
    
    payload = {
        "job_id": "test_123",
        "title": "My Video",
        "quality": "720p",
        "slides": [
            {"kind": "hook", "title": "Welcome", "narration": "Hello"},
            {"kind": "outro", "title": "Bye", "narration": "Goodbye"}
        ]
    }
    
    resp = client.post("/render", json=payload)
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    
    assert data["path"].endswith("test_123.mp4")
    assert data["duration_seconds"] == 5.5
    assert data["size_bytes"] == 1000
