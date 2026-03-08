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

    # Public origin for absolute image URLs (e.g. https://shareish-production.up.railway.app).
    # When set, item responses and upload response return full image URLs so clients always get loadable URLs.
    public_origin: str = ""

    # Optional S3 (or R2) for persistent image storage. If set, uploads go to the bucket instead of disk.
    s3_bucket: str = ""
    s3_region: str = "us-east-1"
    # Base URL for public object access (e.g. https://bucket.s3.us-east-1.amazonaws.com or R2 public URL).
    s3_public_base_url: str = ""
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    # Optional custom endpoint (e.g. for Cloudflare R2: https://<account_id>.r2.cloudflarestorage.com).
    s3_endpoint_url: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
