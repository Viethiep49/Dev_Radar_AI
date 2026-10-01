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

    # ---- Login with Google / GitHub (leave empty = that login is disabled) ----
    # Google: OAuth client IDs whose ID tokens we accept, comma separated.
    # Put the *Web* client ID first (the Flutter app passes it as serverClientId);
    # add the Android/iOS client IDs too if tokens are issued for them.
    google_client_ids: str = ""
    # GitHub OAuth App (github.com/settings/developers). The secret stays on the server.
    github_client_id: str = ""
    github_client_secret: str = ""
    # Must equal the "Authorization callback URL" of the GitHub OAuth App,
    # e.g. a custom scheme the app catches: devradar://oauth/github
    github_redirect_uri: str = ""
    oauth_timeout_seconds: int = 10

    @property
    def google_client_id_list(self) -> list[str]:
        return [value.strip() for value in self.google_client_ids.split(",") if value.strip()]

    ai_engine_url: str = ""
    ai_timeout_seconds: int = 30

    enable_scheduler: bool = False


settings = Settings()
