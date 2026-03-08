# Hosting the Shareish Backend

Ways to run the FastAPI backend on a server so your iOS app (and others) can use it over the internet.

---

## 1. What you need before deploying

- **Environment variables** (set on the server or in the platform’s dashboard):
  - `JWT_SECRET` – Use a long random string in production (e.g. `openssl rand -hex 32`).
  - `ANTHROPIC_API_KEY` – For “Identify with AI” **Required for "Identify with AI".** If unset, the app shows 503 when you tap it. Get a key at [console.anthropic.com](https://console.anthropic.com).
  - `DATABASE_URL` – Omit for SQLite (file on disk), or set for Postgres (recommended for production).
  - `UPLOAD_DIR` – Optional; default `./uploads`. On PaaS, use a path that persists or use object storage (see below).

- **Database**
  - **SQLite**: Fine for a single server and low traffic. Set a path that persists (e.g. a volume). No extra `DATABASE_URL` needed if you keep default.
  - **Postgres**: Better for production and scaling. Set `DATABASE_URL=postgresql://user:pass@host:5432/dbname` and add `psycopg2-binary` to `requirements.txt` and install it.

- **HTTPS** – Required for production (Firebase, App Store, etc.). Use the platform’s SSL or put the app behind a reverse proxy (e.g. Caddy, Nginx) with a certificate (Let’s Encrypt).

- **iOS app** – Set the Server URL in the app to your deployed API base, e.g. `https://your-api.example.com/api/v1` (no trailing slash is fine; the app normalizes it).

---

## 2. Option A: PaaS (easiest)

Deploy the backend as an app and let the platform handle process, HTTPS, and often DB.

### Railway (step-by-step)

1. **Create a project** at [railway.app](https://railway.app) and connect your GitHub repo (or use **Deploy from GitHub** and select the `shareish` repo).

2. **Add a new service** from the repo. In the new service:
   - **Settings → General**: leave **Root Directory blank** (use repo root). The repo has a **Dockerfile** and **railway.toml** at the top level so Railway detects Docker and skips Railpack (fixes “Script start.sh not found” / “Railpack could not determine how to build”).
   - **Settings → Build**: Railway should pick the Dockerfile automatically. If it still uses Railpack, set **Builder** to **Dockerfile**.
   - **Settings → Deploy**: Start command is in `railway.toml`. If needed, set **Custom Start Command** to:
     ```bash
     uvicorn app.main:app --host 0.0.0.0 --port $PORT
     ```

3. **Add Postgres** (recommended for production):
   - In the project, click **+ New** → **Database** → **PostgreSQL**.
   - In your **backend service** → **Variables** tab, add variables so the app can connect. You do **not** type the username/password yourself; you **reference** them from the Postgres service (replace `Postgres` with your database service name if different):
     - **Use internal URL (no proxy cost):** Railway’s private `DATABASE_URL` is often just the hostname. The app builds the full URL from these references. Add **all** of:
       - `DATABASE_URL` = `${{Postgres.DATABASE_URL}}` (internal host, e.g. postgres.railway.internal)
       - `PGUSER` = `${{Postgres.PGUSER}}`
       - `PGPASSWORD` = `${{Postgres.PGPASSWORD}}`
       - `PGDATABASE` = `${{Postgres.PGDATABASE}}`
       - `PGPORT` = `${{Postgres.PGPORT}}`
       The app will connect as `postgresql://PGUSER:PGPASSWORD@DATABASE_URL:PGPORT/PGDATABASE` (internal).
     - **Or use public URL (simpler, uses proxy):** `DATABASE_URL` = `${{Postgres.DATABASE_PUBLIC_URL}}` only (full URL in one variable).
   - **Reference syntax:** Use a leading `$`, e.g. `${{shareishdb.DATABASE_URL}}` (replace `shareishdb` with your Postgres service name).
   - **If tables still don’t appear in Postgres:** In deploy logs look for `[Shareish] Using database: ...`. If it says `sqlite (local file)`, the `DATABASE_URL` reference didn’t resolve or is empty—add all five variables above with the `${{ServiceName.Variable}}` form and redeploy.
   - Add `psycopg2-binary` to `backend/requirements.txt` so the app can use Postgres (sync driver).

4. **Set variables** for the backend service (Variables tab):
   - `JWT_SECRET` – Generate with e.g. `openssl rand -hex 32`.
   - `ANTHROPIC_API_KEY` – Your Anthropic key (for “Identify with AI”).
   - `PUBLIC_ORIGIN` – Your public app URL without `/api/v1`, e.g. `https://shareish-production.up.railway.app`. Required for listing images to load in the app.
   - (Optional) `UPLOAD_DIR` – e.g. `./uploads`; note the filesystem is ephemeral, so uploads are lost on redeploy unless you add a volume or object storage. See **[Persistent image storage](PERSISTENT_IMAGES.md)** for Railway volume or S3/R2 setup.

5. **Public URL**: In the backend service, open **Settings → Networking** → **Generate Domain**. You’ll get a URL like `https://shareish-backend-production-xxxx.up.railway.app`.

6. **iOS app**: On the login screen, set **Server URL** to your Railway URL with `/api/v1`, e.g. `https://shareish-backend-production-xxxx.up.railway.app/api/v1` (no trailing slash needed).

7. **Check**: Open `https://your-railway-url/docs` to confirm the API and try **POST /api/v1/auth/dev-login**.

**“Application failed to respond”:** Check the service **Deployments** tab → click the latest deployment → **View Logs**. Common causes: (1) App crashes on startup (e.g. database connection error) – fix `DATABASE_URL` or the `postgres://` → `postgresql://` conversion in `app/database.py`; (2) Wrong port – the repo uses `start.sh` so the app listens on Railway’s `PORT`. If you use Postgres, ensure the backend service has `DATABASE_URL` set (reference from the Postgres plugin) and that `psycopg2-binary` is in `requirements.txt`.

### Render

1. New **Web Service**, connect repo, set **Root Directory** to `backend`.
2. **Build**: `pip install -r requirements.txt`
3. **Start**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. Add **PostgreSQL** from the dashboard; set `DATABASE_URL` in Environment.
5. Set `JWT_SECRET`, `ANTHROPIC_API_KEY`. Use the Render URL (e.g. `https://shareish-api.onrender.com`) as base; in the app use `https://shareish-api.onrender.com/api/v1`.

### Fly.io

1. In `backend/`, run `fly launch`, choose app name and region.
2. Use a `Dockerfile` (see Option C below) or a `fly.toml` with a `build` section and run command: `uvicorn app.main:app --host 0.0.0.0 --port 8080`.
3. Add Postgres: `fly postgres create` then set `DATABASE_URL`.
4. Secrets: `fly secrets set JWT_SECRET=... ANTHROPIC_API_KEY=...`
5. App URL will be like `https://your-app.fly.dev`; in the app use `https://your-app.fly.dev/api/v1`.

**Note:** On PaaS, the filesystem is often ephemeral. For uploads you can: (1) keep using a local `UPLOAD_DIR` and accept that files disappear on redeploy, or (2) add S3/R2 and change the code to store and serve images from there (and optionally serve `/uploads/` via a redirect or proxy).

---

## 3. Option B: VPS (e.g. Ubuntu on DigitalOcean, Linode, EC2)

Full control; you manage process, HTTPS, and DB.

1. **Server**: Create an Ubuntu 22.04 (or similar) VM. SSH in.

2. **Install Python and deps**:
   ```bash
   sudo apt update && sudo apt install -y python3 python3-pip python3-venv
   ```

3. **Clone/copy your app** (e.g. clone repo or rsync):
   ```bash
   cd /opt
   sudo git clone https://github.com/yourusername/shareish.git
   cd shareish/backend
   ```

4. **Virtual env and install**:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   # If using Postgres:
   pip install psycopg2-binary
   ```

5. **Environment**:
   ```bash
   cp .env.example .env
   nano .env   # set JWT_SECRET, ANTHROPIC_API_KEY, DATABASE_URL if Postgres, UPLOAD_DIR if needed
   ```

6. **Run with a process manager** (so it restarts and survives reboots). Example with systemd:
   - Create `/etc/systemd/system/shareish-api.service`:
   ```ini
   [Unit]
   Description=Shareish FastAPI
   After=network.target

   [Service]
   Type=simple
   User=www-data
   WorkingDirectory=/opt/shareish/backend
   Environment="PATH=/opt/shareish/backend/.venv/bin"
   ExecStart=/opt/shareish/backend/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```
   - Load env from file (optional): add `EnvironmentFile=/opt/shareish/backend/.env` (and ensure `.env` is not world-readable).
   - Then: `sudo systemctl daemon-reload && sudo systemctl enable --now shareish-api`.

7. **HTTPS**: Put Nginx (or Caddy) in front and use Let’s Encrypt.
   - **Caddy** (auto HTTPS): install Caddy, then in Caddyfile: `your-api.example.com { reverse_proxy localhost:8000 }`.
   - **Nginx**: proxy `https://your-api.example.com` to `http://127.0.0.1:8000` and use `certbot` for SSL.

8. **iOS app**: Set Server URL to `https://your-api.example.com/api/v1`.

---

## 4. Option C: Docker

Useful for PaaS that expect a container or for consistent runs anywhere.

Example **Dockerfile** in `backend/`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Create uploads dir if the app expects it
RUN mkdir -p uploads

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run locally:

```bash
cd backend
docker build -t shareish-api .
docker run -p 8000:8000 --env-file .env -v $(pwd)/uploads:/app/uploads shareish-api
```

For production, use a real database (Postgres in another container or managed DB) and set `DATABASE_URL`. Use Docker Compose or your host’s orchestration; put a reverse proxy in front for HTTPS.

---

## 5. Checklist

- [ ] Set a strong `JWT_SECRET` (e.g. `openssl rand -hex 32`).
- [ ] Use HTTPS for the API URL.
- [ ] In the iOS app, set Server URL to `https://your-host/api/v1`.
- [ ] Prefer Postgres for production (`DATABASE_URL` + `psycopg2-binary`).
- [ ] (Optional) Restrict or remove `POST /api/v1/auth/dev-login` in production (e.g. env flag and conditional router).
- [ ] If you keep uploads on disk, ensure `UPLOAD_DIR` is persistent and that you serve `/uploads` (e.g. add `app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")` in `main.py` and ensure URLs in responses use your public base URL).

Once deployed, open `https://your-api-url/docs` to confirm the API and test from the iOS app.
