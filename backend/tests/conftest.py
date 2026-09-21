"""Shared test fixtures: in-memory SQLite DB, TestClient, a logged-in user.

Fixtures other test files can use:
    db            -> SQLAlchemy session (empty DB, all tables created)
    client        -> TestClient for the app, using `db`
    user          -> a saved User (email "user@example.com", password "secret123")
    auth_headers  -> {"Authorization": "Bearer <access token of user>"}
"""

import os

# Never start the cron scheduler during tests, even if a local .env enables it.
os.environ["ENABLE_SCHEDULER"] = "false"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401  (registers all tables in Base.metadata)
from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import create_app
from app.models import User

# StaticPool keeps ONE connection, so the in-memory DB lives for the whole test.
engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)


@event.listens_for(engine, "connect")
def _enable_sqlite_foreign_keys(dbapi_connection, connection_record):
    # SQLite ignores ON DELETE CASCADE unless this is turned on.
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


TestingSessionLocal = sessionmaker(bind=engine, autoflush=False)


@pytest.fixture
def db():
    Base.metadata.create_all(engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)


@pytest.fixture
def app(db):
    application = create_app()

    def override_get_db():
        yield db

    application.dependency_overrides[get_db] = override_get_db
    return application


@pytest.fixture
def client(app):
    return TestClient(app)


@pytest.fixture
def user(db) -> User:
    user = User(
        email="user@example.com",
        password_hash=hash_password("secret123"),
        display_name="Test User",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_headers(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}
