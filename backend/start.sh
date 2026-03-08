#!/bin/sh
# Use PORT from Railway (or default 8000)
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
