# Shareish — Project Overview

This document gives a high-level picture of what Shareish is, what its main parts are, and how they work together. It’s aimed at readers who are comfortable with technical concepts but don’t need implementation details.

---

## What Shareish Is

**Shareish** is a small full-stack app where people can:

- **List items** they want to give away (e.g. furniture, books).
- **Browse listings** and **claim** items they want.
- **Log in** (for now, a simple dev login; no real auth).

So: a “give away / claim” marketplace driven by an **iOS app** talking to a **backend API**, with data stored in a **database**.

---

## The Big Pieces

There are four main parts:

| Component | What it is | Where it runs |
|-----------|------------|----------------|
| **iOS app** | The app users see on their phone (SwiftUI). It shows listings, lets users claim items, and talks to the API. | User’s device (iPhone). |
| **Backend API** | A web service that handles login, listings, claims, and image uploads. It’s the only part that talks to the database. | Your server (e.g. Railway). |
| **Database** | Stores users, items, and claims. Can be SQLite (local/dev) or PostgreSQL (e.g. on Railway). | Same machine as the backend, or a managed DB service. |
| **File storage (optional)** | Uploaded images. Can be stored on the server’s disk or in cloud storage (e.g. S3). | Server filesystem or cloud. |

Nothing else talks to the database: the iOS app only talks to the backend; the backend talks to the database and to file storage.

---

## How They Connect

```
┌─────────────────┐         HTTPS          ┌─────────────────┐
│   iOS app       │ ◄───────────────────► │   Backend API   │
│   (SwiftUI)     │    requests/JSON       │   (FastAPI)      │
└─────────────────┘                       └────────┬────────┘
                                                  │
                    ┌─────────────────────────────┼─────────────────────────────┐
                    │                             │                             │
                    ▼                             ▼                             ▼
            ┌───────────────┐             ┌───────────────┐             ┌───────────────┐
            │   Database    │             │  Image files   │             │  (Optional)   │
            │  (Postgres or │             │  (server disk  │             │  S3 / cloud   │
            │   SQLite)     │             │   or volume)   │             │  storage     │
            └───────────────┘             └───────────────┘             └───────────────┘
```

- **User** uses the **iOS app**.
- The app sends **HTTP requests** (e.g. “get listings”, “create claim”) to the **Backend API**.
- The **Backend** reads/writes the **database** (users, items, claims) and serves or stores **images** (disk or S3).
- The app gets **JSON** back and shows screens accordingly.

So: one direction of trust — **app → API → database/files**. The app never talks to the database directly.

---

## What Lives Where

### In the repo

- **`ios/`** — Xcode project and SwiftUI source for the iPhone app.
- **`backend/`** — Python FastAPI app (API routes, database models, image handling). This is what you deploy as the “backend”.

### On the server (e.g. Railway)

- The **backend** runs as a single process (e.g. in Docker). It’s configured with environment variables (database URL, API keys, etc.).
- **Database**: either a file-based SQLite next to the app or a **PostgreSQL** instance (Railway’s Postgres, internal URL to avoid proxy cost).
- **Images**: stored on a volume or in S3, depending on config.

### On the phone

- The **iOS app** is installed from Xcode (or TestFlight). It’s configured with the backend’s **base URL** (e.g. `https://your-app.railway.app`) so all API calls go to your server.

---

## Main Concepts (from the API’s point of view)

- **Users** — Who is “logged in”. Right now there’s a simple dev login; the backend still tracks a user per session.
- **Items (listings)** — Something someone is giving away: title, description, optional images. Stored in the database; images in files (or S3).
- **Claims** — “I want this item.” A claim links a user to an item. The backend records who claimed what.

The backend exposes endpoints such as: login, list/create items, claim an item, and upload or fetch images. The iOS app calls these and updates the UI.

---

## Data and Request Flow (example)

1. **User opens the app**  
   App may call something like “get my profile” or “get listings” using the backend base URL.

2. **User browses listings**  
   App calls “list items” → backend reads from **database** → returns JSON → app shows the list.

3. **User claims an item**  
   App sends “create claim for item X” (with user identity) → backend writes to **database** → returns success/failure.

4. **Images**  
   When listing an item, the app may upload image bytes to the backend; the backend saves them to disk (or S3) and stores a reference in the database. When showing a listing, the app may get an image URL or base64 from the API and display it.

So in one sentence: **the iOS app is the UI; the backend is the brain and the only thing that touches the database and files.**

---

## Summary

| Question | Answer |
|----------|--------|
| What is Shareish? | A small “give away / claim” app: iOS front end + backend API + database (+ optional image storage). |
| What are the main components? | iOS app (SwiftUI), Backend API (FastAPI), Database (Postgres or SQLite), optional S3. |
| How do they interact? | App → HTTPS → Backend → Database and files. Only the backend talks to the DB and storage. |
| Where does the code live? | `ios/` for the app, `backend/` for the API. |
| Where does it run? | App on the device; backend (and DB, images) on your host (e.g. Railway). |

For deployment and environment details (e.g. Railway, env vars, internal DB URL), see `backend/HOSTING.md`. For image storage and upload behavior, see `backend/PERSISTENT_IMAGES.md`.
