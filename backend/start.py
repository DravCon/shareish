#!/usr/bin/env python3
"""Run uvicorn with PORT from environment (Railway sets PORT; no shell expansion in their runner)."""
import os

port = os.environ.get("PORT", "8000")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(port),
        factory=False,
    )
