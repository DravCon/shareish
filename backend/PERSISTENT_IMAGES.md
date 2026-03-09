# Persistent image storage

By default, listing images are stored on the server’s local disk. On platforms like Railway the filesystem is **ephemeral**, so uploads are lost on redeploy. To make images survive redeploys, use one of the options below.

---

## Option A: Railway volume (simplest on Railway)

Railway doesn’t have a separate “Volumes” page. You **attach** a volume to your existing backend service:

1. In the [Railway](https://railway.app) dashboard, open your **project** so you see the service tiles (e.g. your backend app).
2. **Attach a volume to your backend service** using one of these:
   - **Right‑click** the **backend service tile** (the card for your app) → **Attach Volume**, or
   - Click the **⋯** (three dots) on the service tile → **Attach Volume**, or
   - Press **⌘K** (Mac) or **Ctrl+K** (Windows) to open the **Command Palette**, type **volume**, and choose the option to create/attach a volume (then select your backend service when asked).
3. When prompted, set **Mount Path** to **`/app/uploads`** (the app already uses this path for uploads; no need to set `UPLOAD_DIR`).
4. Save and **redeploy** the backend service.

New uploads are written to the volume and persist across redeploys. The app continues to serve images from `/api/v1/uploads/...` and to inline the first image in API responses when the file exists.

**Note:** With a single replica, one volume is enough. If you scale to multiple instances, each has its own volume; for shared storage use Option B (S3/R2).

---

## Option B: S3 or Cloudflare R2 (works with multiple instances)

Images are uploaded to an object-storage bucket. The app returns the bucket URL; the iOS app loads images from that URL. No second request to your API is needed, and images persist regardless of redeploys or replicas.

### 1. Create a bucket and make it public read

- **AWS S3:** Create a bucket and add a bucket policy so objects are publicly readable (e.g. `s3:GetObject` for `*`), or use a CloudFront distribution.
- **Cloudflare R2:** Create a bucket and enable **Public access** (or attach a custom domain and make it public).

### 2. Get credentials

- **AWS:** Create an IAM user with at least `s3:PutObject` (and `s3:GetObject` if you need to read back). Create an access key and note the **Access Key ID** and **Secret Access Key**.
- **R2:** In the R2 dashboard, go to **Manage R2 API Tokens** and create a token with **Object Read & Write**. Note the **Access Key ID** and **Secret Access Key**.

### 3. Set environment variables

In your backend service (e.g. Railway **Variables**), set:

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_BUCKET` | Bucket name | `shareish-uploads` |
| `S3_REGION` | AWS region (S3) or `auto` (R2) | `us-east-1` |
| `S3_PUBLIC_BASE_URL` | Base URL for public object access | See below |
| `AWS_ACCESS_KEY_ID` | Access key | (from step 2) |
| `AWS_SECRET_ACCESS_KEY` | Secret key | (from step 2) |
| `S3_ENDPOINT_URL` | **R2 only:** R2 S3-compatible endpoint | `https://<account_id>.r2.cloudflarestorage.com` |

**S3_PUBLIC_BASE_URL examples:**

- **S3:** `https://your-bucket.s3.us-east-1.amazonaws.com` (replace bucket and region), or your CloudFront/custom domain.
- **R2:** Your R2 public bucket URL (e.g. `https://pub-xxxx.r2.dev`) or your custom domain.

### 4. Redeploy

Redeploy the backend. New uploads go to S3/R2; the API returns the object URL in `image_urls`. The iOS app already loads images from full URLs (and uses `first_image_base64` when the server inlines it for local files), so no app change is needed.

### Optional: .env.example

Your `backend/.env.example` includes commented placeholders for these variables. Uncomment and fill them when you use S3/R2.
