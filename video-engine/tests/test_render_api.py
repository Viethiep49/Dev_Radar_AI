from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

def test_health_reports_all_dependencies_ok():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json() == {
        'status': 'ok',
        'ffmpeg': 'ok',
        'fonts': 'ok',
        'voice': 'ok',
    }
