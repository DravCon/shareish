#!/usr/bin/env bash
set -e
# Railway sets PORT; use 8080 if unset
export PORT="${PORT:-8080}"
exec uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
