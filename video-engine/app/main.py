import subprocess
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from app.core.config import settings

app = FastAPI()

@app.get('/health')
def health():
    try:
        res = subprocess.run([settings.ffmpeg_bin, '-version'], capture_output=True, timeout=10)
        ffmpeg_ok = res.returncode == 0
    except Exception:
        ffmpeg_ok = False

    fonts_ok = settings.font_regular.is_file() and settings.font_bold.is_file()
    voice_ok = (settings.models_dir / f'{settings.voice}.onnx').exists() and (settings.models_dir / f'{settings.voice}.onnx.json').exists()

    body = {
        'status': 'ok' if (ffmpeg_ok and fonts_ok and voice_ok) else 'degraded',
        'ffmpeg': 'ok' if ffmpeg_ok else 'error',
        'fonts': 'ok' if fonts_ok else 'error',
        'voice': 'ok' if voice_ok else 'error',
    }

    if body['status'] == 'ok':
        return JSONResponse(status_code=200, content=body)
    return JSONResponse(status_code=503, content=body)
