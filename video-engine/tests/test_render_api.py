from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

def test_health_reports_all_dependencies_ok(monkeypatch):
    import subprocess
    from pathlib import Path
    
    monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: type("CP", (), {"returncode": 0})())
    original_is_file = Path.is_file
    monkeypatch.setattr(Path, "is_file", lambda self: True if "/app/fonts" in str(self) or "/usr/share" in str(self) else original_is_file(self))
    original_exists = Path.exists
    monkeypatch.setattr(Path, "exists", lambda self: True if "/app/models" in str(self) else original_exists(self))
    
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json() == {
        'status': 'ok',
        'ffmpeg': 'ok',
        'fonts': 'ok',
        'voice': 'ok',
    }
