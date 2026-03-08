from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine, get_db
from app.routers import auth, claims, items, uploads

# Create tables (SQLite/DB)
Base.metadata.create_all(bind=engine)


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
