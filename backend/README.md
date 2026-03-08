# Shareish Backend

FastAPI backend for the Shareish iOS app. Uses SQLite by default so you can run it without installing PostgreSQL.

**Deploying to a server?** See [HOSTING.md](HOSTING.md) for PaaS (Railway, Render, Fly.io), VPS, and Docker.

## Setup

1. **Create a virtual environment (recommended)**

   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate   # On Windows: .venv\Scripts\activate
   ```

2. **Install dependencies**

   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set at least:

   - **ANTHROPIC_API_KEY** – Required for “Identify with AI”. Get one at [console.anthropic.com](https://console.anthropic.com).

   Optional:

   - **JWT_SECRET** – Change for production.
   - **DATABASE_URL** – Default is SQLite (`./shareish.db`). For Postgres use e.g. `postgresql://user:pass@localhost/shareish` (and install `psycopg2-binary`).

4. **Run the server**

   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0
   ```

   Use `--host 0.0.0.0` so the iOS Simulator can reach the API at `http://localhost:8000` (or your Mac’s IP). API: **http://localhost:8000**  
   Docs: **http://localhost:8000/docs**

## Auth

- **Production:** iOS app sends Firebase ID token to `POST /api/v1/auth/login`. Backend decodes it and creates/returns a user and a JWT.
- **Testing without Firebase:** Call `POST /api/v1/auth/dev-login` (optionally `?phone_number=+911234567890`). Use the returned `token` in the iOS app (e.g. set it in APIClient or via a temporary dev login screen).

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/auth/login | Login with Firebase ID token |
| POST | /api/v1/auth/dev-login | Dev login (no Firebase) |
| GET | /api/v1/auth/me | Current user (requires Bearer token) |
| POST | /api/v1/items/upload/identify | Upload photo → AI returns title, description, etc. |
| POST | /api/v1/items/ | Create item (requires auth) |
| GET | /api/v1/items/feed | List items (optional ?category=) |
| GET | /api/v1/items/{id} | Item detail |
| PATCH | /api/v1/items/{id}/status | Update status (owner) |
| POST | /api/v1/claims/{item_id} | Claim item → get WhatsApp link |
| GET | /api/v1/claims/my-claims | My claims |
| GET | /api/v1/claims/my-items/{id}/claims | Claims on my item (owner) |
