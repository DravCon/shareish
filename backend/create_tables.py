#!/usr/bin/env python3
"""
One-off: create DB tables. Safe to run multiple times (idempotent).
Run on Railway: deploy this file, then use Railway SSH and run:
  cd /app && python create_tables.py
"""
import os
from app.database import engine, Base
from app import models  # noqa: F401 - register User, Item, Claim with Base

if __name__ == "__main__":
    raw = (os.environ.get("DATABASE_URL") or "").strip()
    if not raw:
        print("DATABASE_URL is empty or not set in this container.")
        print("Tables will be created in SQLite (not Postgres). Fix Variables in Railway and redeploy.")
    else:
        # Redact password for safety
        if "://" in raw and "@" in raw:
            try:
                pre, rest = raw.split("@", 1)
                user_part = pre.split("://", 1)[-1]
                if ":" in user_part:
                    user = user_part.split(":")[0]
                    print(f"DATABASE_URL is set (user={user}, host=...).")
                else:
                    print("DATABASE_URL is set.")
            except Exception:
                print("DATABASE_URL is set.")
        else:
            print(f"DATABASE_URL looks like a hostname: {raw[:50]}...")
    drivername = getattr(engine.url, "drivername", "unknown")
    print(f"Using database: {drivername}")
    Base.metadata.create_all(bind=engine)
    print("Done. Tables created (or already existed).")
