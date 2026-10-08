import os

_raw_ollama_url = os.getenv("OLLAMA_URL", "http://ollama:11434")
OLLAMA_URL = _raw_ollama_url.rstrip("/")
if not OLLAMA_URL.endswith("/api/generate"):
    OLLAMA_URL = f"{OLLAMA_URL}/api/generate"

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:7b")

# Keep this below the backend's AI_TIMEOUT_SECONDS (30s by default) so the
# backend gets a proper error instead of timing out first.
OLLAMA_TIMEOUT_SECONDS = float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "25"))

# First load of the model in Ollama (only used by the start-up warm-up).
WARMUP_TIMEOUT_SECONDS = float(os.getenv("WARMUP_TIMEOUT_SECONDS", "300"))

# /summarize reads a whole README and is the slowest call by far, so it gets its
# own budget. Chat keeps OLLAMA_TIMEOUT_SECONDS above so a stuck Ollama fails
# fast there (the Flutter client waits 30s for chat).
SUMMARIZE_TIMEOUT_SECONDS = float(os.getenv("SUMMARIZE_TIMEOUT_SECONDS", "120"))

DATABASE_URL = os.environ["DATABASE_URL"]

# Floor on cosine similarity (1 - cosine distance) for a chunk to be used as
# context. Off by default (0.0 = keep every chunk that is not opposite in
# meaning): measured on paraphrase-multilingual-MiniLM-L12-v2 the relevant and
# irrelevant groups overlap, so any higher floor drops chunks that do answer the
# question. An unrelated question scored 0.354 on one repo while a question the
# README answers scored 0.037. The chat prompt is what makes the model say
# "Không tìm thấy trong tài liệu" when the retrieved text does not cover it.
MIN_SIMILARITY = float(os.getenv("MIN_SIMILARITY", "0"))
