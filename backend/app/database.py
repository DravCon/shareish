import os
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

from app.config import settings

# Resolve database URL: full URL, or build from PG* vars, or fall back to SQLite
def _resolve_database_url() -> str:
    raw = (settings.database_url or "").strip()
    if not raw:
        return "sqlite:///./shareish.db"
    # If DATABASE_URL is only a hostname (e.g. postgres.railway.internal), build URL from PG* env vars
    if "://" not in raw:
        host = (raw or os.environ.get("PGHOST", "") or getattr(settings, "pg_host", "")).strip()
        port = (os.environ.get("PGPORT", "") or getattr(settings, "pg_port", "5432")).strip() or "5432"
        user = (os.environ.get("PGUSER", "") or getattr(settings, "pg_user", "postgres")).strip() or "postgres"
        password = (os.environ.get("PGPASSWORD", "") or getattr(settings, "pg_password", "")).strip()
        dbname = (os.environ.get("PGDATABASE", "") or getattr(settings, "pg_database", "railway")).strip() or "railway"
        if host:
            safe_password = quote_plus(password) if password else ""
            return f"postgresql://{user}:{safe_password}@{host}:{port}/{dbname}"
        return "sqlite:///./shareish.db"
    return raw


database_url = _resolve_database_url()
# Never pass empty URL to create_engine (e.g. if env reference resolved to empty)
if not (database_url and database_url.strip()):
    database_url = "sqlite:///./shareish.db"

# Railway Postgres often gives postgres://; SQLAlchemy needs postgresql://
if database_url.startswith("postgres://"):
    database_url = "postgresql://" + database_url[9:]


def get_database_description() -> str:
    """Safe description for logs (no passwords)."""
    if database_url.startswith("sqlite"):
        return "sqlite (local file)"
    if database_url.startswith("postgresql://"):
        try:
            # postgresql://user:pass@host:port/dbname -> show host
            rest = database_url.split("@", 1)[-1].split("/")[0]
            return f"postgresql at {rest}"
        except Exception:
            return "postgresql"
    return "unknown"


# SQLite needs check_same_thread=False for FastAPI
connect_args = {}
if database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(
    database_url,
    connect_args=connect_args,
    echo=False,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
