"""Application settings, read from environment variables (or a local .env file)."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Env var names are the upper-case field names: DATABASE_URL, JWT_SECRET, ...
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://devradar:change_me@localhost:5432/devradar"

    jwt_secret: str = "dev-secret-change-me-in-production-please"
    jwt_access_minutes: int = 30
    jwt_refresh_days: int = 7

    github_token: str = ""

    ai_engine_url: str = ""
    ai_timeout_seconds: int = 30

    enable_scheduler: bool = False


settings = Settings()
