# Shareish backend - build from repo root so Railway always uses Docker (no Railpack)
FROM python:3.11-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .

RUN mkdir -p uploads && chmod +x start.sh

EXPOSE 8000
CMD ["./start.sh"]
