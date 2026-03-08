from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import settings
from app.database import Base, engine, get_db
from app.routers import auth, claims, items, uploads

# Create tables (SQLite/DB)
Base.metadata.create_all(bind=engine)


def _ensure_image_urls_column():
    """Add image_urls to items if the table existed from before this column was added."""
    with engine.connect() as conn:
        if conn.get_bind().dialect.name == "sqlite":
            cursor = conn.execute(text("PRAGMA table_info(items)"))
            rows = cursor.fetchall()
            # PRAGMA table_info: (cid, name, type, notnull, default_value, pk)
            if not any(r[1] == "image_urls" for r in rows):
                conn.execute(text("ALTER TABLE items ADD COLUMN image_urls TEXT"))
        else:
            conn.execute(
                text("ALTER TABLE items ADD COLUMN IF NOT EXISTS image_urls TEXT")
            )
        conn.commit()


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
