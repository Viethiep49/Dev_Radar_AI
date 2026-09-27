import os

_raw_ollama_url = os.getenv("OLLAMA_URL", "http://ollama:11434")
OLLAMA_URL = _raw_ollama_url.rstrip("/")
if not OLLAMA_URL.endswith("/api/generate"):
    OLLAMA_URL = f"{OLLAMA_URL}/api/generate"

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:7b")

# Keep this below the backend's AI_TIMEOUT_SECONDS (30s by default) so the
# backend gets a proper error instead of timing out first.
OLLAMA_TIMEOUT_SECONDS = float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "25"))

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://devradar:change_me@db:5432/devradar")

# Minimum cosine similarity (1 - cosine distance) for a chunk to be used as
# context. Chunks below it are ignored, so the model can answer "not found".
MIN_SIMILARITY = float(os.getenv("MIN_SIMILARITY", "0.35"))
