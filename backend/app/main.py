import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import settings
from app.database import Base, engine, get_db, get_database_description
from app.routers import auth, claims, items, uploads

logger = logging.getLogger("uvicorn.error")

# Create tables (SQLite/Postgres)
try:
    Base.metadata.create_all(bind=engine)
    logger.info(f"Shareish using database: {get_database_description()}")
except Exception as e:
    logger.exception("Database create_all failed")
    raise


def _ensure_image_urls_column():
    """Add image_urls to items if the table existed from before this column was added."""
    try:
        with engine.connect() as conn:
            dialect_name = engine.dialect.name
            if dialect_name == "sqlite":
                cursor = conn.execute(text("PRAGMA table_info(items)"))
                rows = cursor.fetchall()
                if not rows:
                    return  # table doesn't exist yet; create_all will have created it with all columns
                if any(r[1] == "image_urls" for r in rows):
                    return
                conn.execute(text("ALTER TABLE items ADD COLUMN image_urls TEXT"))
            else:
                conn.execute(
                    text("ALTER TABLE items ADD COLUMN IF NOT EXISTS image_urls TEXT")
                )
            conn.commit()
    except Exception:
        pass  # Don't crash app; table may not exist or column already added


_ensure_image_urls_column()


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(
    title="Shareish API",
    version="1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(items.router, prefix=settings.api_v1_prefix)
app.include_router(claims.router, prefix=settings.api_v1_prefix)
app.include_router(uploads.router, prefix=settings.api_v1_prefix)


@app.get("/")
def root():
    return {"message": "Shareish API", "docs": "/docs"}


@app.get(settings.api_v1_prefix)
def api_v1_root():
    return {"message": "Shareish API v1", "endpoints": ["auth/login", "auth/dev-login", "auth/me", "items/feed", "items/", "claims/"]}
