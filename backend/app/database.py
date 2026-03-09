from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

from app.config import settings

# Use default SQLite if DATABASE_URL is missing or empty (e.g. Railway env not set)
_database_url = (settings.database_url or "").strip() or "sqlite:///./shareish.db"

# SQLite needs check_same_thread=False for FastAPI
connect_args = {}
if _database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(
    _database_url,
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
