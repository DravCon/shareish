# Shareish backend - use this if Railpack/Nixpacks fails to create a build plan
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# So the app can write uploads if needed (ephemeral on Railway)
RUN mkdir -p uploads

EXPOSE 8000
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
