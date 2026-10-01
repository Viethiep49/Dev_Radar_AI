import logging
import threading
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, status
import httpx
from sqlalchemy import text

from app.api.v1 import router as v1_router
from app.core.database import ensure_schema, engine
from app.core.config import OLLAMA_URL, OLLAMA_MODEL
from app.services.embedder import get_model
from app.services.llm_client import call_ollama

logger = logging.getLogger(__name__)

def _warm_up():
    try:
        logger.info("Warming up embedding model...")
        get_model()
        logger.info("Warming up Ollama with a short prompt...")
        call_ollama("hello")
        logger.info("Warmup complete.")
    except Exception as e:
        logger.error(f"Warmup failed: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Make sure the ai-engine's own table (repo_embeddings) exists.
    # The backend's migration does not create it, and this table belongs to
    # the ai-engine schema (see docs/AI_ENGINE_CONTRACT.md).
    ensure_schema()
    
    # Run warmup in background
    threading.Thread(target=_warm_up, daemon=True).start()
    yield


app = FastAPI(title="Dev Radar AI - AI Engine", lifespan=lifespan)


@app.get("/health")
def health_check(response: Response):
    db_ok = False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            # Also check if table exists
            conn.execute(text("SELECT 1 FROM repo_embeddings LIMIT 1"))
        db_ok = True
    except Exception as e:
        logger.error(f"DB health check failed: {e}")
        
    ollama_ok = False
    try:
        base_url = OLLAMA_URL.replace("/api/generate", "")
        r = httpx.get(f"{base_url}/api/tags", timeout=5.0)
        r.raise_for_status()
        tags = r.json()
        models = [m.get("name") for m in tags.get("models", [])]
        if OLLAMA_MODEL in models or any(m.startswith(OLLAMA_MODEL) for m in models):
            ollama_ok = True
        else:
            logger.error(f"Ollama does not have model {OLLAMA_MODEL}. Available: {models}")
    except Exception as e:
        logger.error(f"Ollama health check failed: {e}")
        
    if db_ok and ollama_ok:
        return {"status": "ok", "db": "ok", "ollama": "ok"}
    
    response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return {"status": "degraded", "db": "ok" if db_ok else "error", "ollama": "ok" if ollama_ok else "error"}


app.include_router(v1_router)
