#!/usr/bin/env python3
"""
One-off: create DB tables. Safe to run multiple times (idempotent).
Run on Railway: deploy this file, then use Railway SSH and run:
  cd /app && python create_tables.py
Or locally with Railway env: railway run python create_tables.py (from backend/)
"""
from app.database import engine, Base
from app import models  # noqa: F401 - register User, Item, Claim with Base

if __name__ == "__main__":
    drivername = getattr(engine.url, "drivername", "unknown")
    print(f"Using database: {drivername}")
    Base.metadata.create_all(bind=engine)
    print("Done. Tables created (or already existed).")
