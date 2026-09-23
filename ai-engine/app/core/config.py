import os

_raw_ollama_url = os.getenv("OLLAMA_URL", "http://ollama:11434/api/generate")
OLLAMA_URL = _raw_ollama_url.rstrip("/")
if not OLLAMA_URL.endswith("/api/generate"):
    OLLAMA_URL = f"{OLLAMA_URL}/api/generate"
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://devradar:change_me@db:5432/devradar")
