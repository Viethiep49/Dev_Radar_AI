"""FastAPI application: routers, error handlers, CORS and the cron scheduler."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    auth,
    chat,
    collections,
    learning,
    notes,
    notifications,
    preferences,
    repos,
    stats,
    watchlist,
)
from app.core.config import settings
from app.core.errors import register_error_handlers
from app.jobs.scheduler import build_scheduler

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: start the cron jobs (disabled by default, e.g. in tests).
    scheduler = None
    if settings.enable_scheduler:
        scheduler = build_scheduler()
        scheduler.start()
    yield
    # Shutdown
    if scheduler is not None:
        scheduler.shutdown(wait=False)


def create_app() -> FastAPI:
    app = FastAPI(title="DevRadar AI API", version="0.1.0", lifespan=lifespan)

    # Allow every origin while developing (the mobile app does not need CORS, Swagger/web does).
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_error_handlers(app)

    for module in (
        auth,
        preferences,
        repos,
        collections,
        notes,
        learning,
        stats,
        watchlist,
        notifications,
        chat,
    ):
        app.include_router(module.router, prefix=API_PREFIX)

    @app.get("/health", tags=["health"])
    def health():
        return {"status": "ok"}

    return app


app = create_app()
