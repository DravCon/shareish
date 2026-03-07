from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # API
    api_v1_prefix: str = "/api/v1"

    # Database (SQLite for dev; set DATABASE_URL for Postgres)
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

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
