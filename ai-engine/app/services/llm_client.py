import httpx
from fastapi import HTTPException
from app.core.config import OLLAMA_URL

def call_ollama(prompt: str, json_format: bool = False):
    payload = {
        "model": "qwen2.5:7b",
        "prompt": prompt,
        "stream": False
    }
    if json_format:
        payload["format"] = "json"
        
    try:
        resp = httpx.post(OLLAMA_URL, json=payload, timeout=120.0)
        resp.raise_for_status()
        return resp.json()["response"]
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Lỗi kết nối Ollama: {str(e)}")
