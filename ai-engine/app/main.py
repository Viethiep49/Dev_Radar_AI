from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.v1 import router as v1_router
from app.core.database import ensure_schema


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Make sure the ai-engine's own table (repo_embeddings) exists.
    # The backend's migration does not create it, and this table belongs to
    # the ai-engine schema (see docs/AI_ENGINE_CONTRACT.md).
    ensure_schema()
    yield


app = FastAPI(title="Dev Radar AI - AI Engine", lifespan=lifespan)


@app.get("/health")
def health_check():
    return {"status": "ok"}


app.include_router(v1_router)
