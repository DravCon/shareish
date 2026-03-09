from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", env_ignore_empty=True)

    # API
    api_v1_prefix: str = "/api/v1"

    # Database (SQLite for dev; set DATABASE_URL for Postgres on Railway)
    # With env_ignore_empty=True, empty DATABASE_URL is ignored and this default is used
    database_url: str = "sqlite:///./shareish.db"

    # JWT we issue after Firebase login
    jwt_secret: str = "change-me-in-production-use-long-random-string"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 7 days

    # Firebase (optional: for verifying ID tokens)
    firebase_project_id: str = ""

    # Anthropic (for AI identify)
    anthropic_api_key: str = ""

    # Uploaded images stored under this directory; URLs will be /uploads/...
    upload_dir: str = "./uploads"


settings = Settings()
