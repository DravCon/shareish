# Shareish — Project Brief for AI Agent

## What This Project Is

Shareish is an iOS app that lets people give away things they no longer need to friends and family — completely free. The core idea is zero-friction listing powered by AI: the user snaps a photo of an item, Claude Vision identifies it and auto-fills all listing details (title, category, condition, description, tags), and the item appears in a shared feed for friends to claim.

This is a passion/learning project built by a single developer. Prioritize simplicity, clean code, and getting things working over enterprise patterns. No over-engineering.

## Core User Flow

1. **Sign up/Login**: Phone number + OTP via Firebase Auth. No email, no passwords.
2. **List an item**: Open camera → snap photo → AI auto-fills listing details → user reviews with one tap → item is live.
3. **Browse feed**: Single reverse-chronological feed of available items from friends. Filter by category.
4. **Claim an item**: Tap "I want this" → app generates a WhatsApp deep link with a pre-filled message → user chats directly with the owner to coordinate pickup.
5. **Complete exchange**: Owner marks item as "taken" after handoff.

## Tech Stack

### Backend (Python — already scaffolded)
- **Framework**: FastAPI (async)
- **Database**: PostgreSQL with SQLAlchemy (async via asyncpg) and Alembic for migrations
- **Auth**: Firebase Auth (Phone OTP). iOS app handles OTP entry using Firebase SDK. Backend verifies the Firebase ID token.
- **AI**: Anthropic Claude API (claude-sonnet-4-20250514) with Vision. Identifies items from photos and returns structured JSON.
- **Image Storage**: S3-compatible (AWS S3, Cloudflare R2, or MinIO for local dev)

### iOS App (Swift — to be built)
- **Language**: Swift 5.9+
- **UI**: SwiftUI (minimum target iOS 17)
- **Architecture**: MVVM with async/await
- **Auth**: Firebase Auth iOS SDK (phone number OTP)
- **Networking**: URLSession with async/await (no Alamofire needed for an app this simple)
- **Image Handling**: PhotosUI (PHPicker) for gallery, AVFoundation for camera
- **Dependencies**: Firebase iOS SDK (Auth only), managed via Swift Package Manager

## Project Structure

```
shareish/
├── backend/                          # Python FastAPI — already built
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── models.py
│   │   ├── schemas.py
│   │   ├── routers/
│   │   │   ├── auth.py
│   │   │   ├── items.py
│   │   │   └── claims.py
│   │   └── services/
│   │       └── ai_identifier.py     # Claude Vision integration (WORKING)
│   ├── requirements.txt
│   └── .env.example
│
├── ios/                              # SwiftUI iOS app — to be built
│   └── Shareish/
│       ├── Shareish.xcodeproj
│       ├── ShareishApp.swift         # App entry point
│       ├── ContentView.swift         # Root navigation
│       ├── Models/
│       │   ├── User.swift            # User model
│       │   ├── Item.swift            # Item model (matches backend schema)
│       │   └── Claim.swift           # Claim model
│       ├── Views/
│       │   ├── Auth/
│       │   │   └── LoginView.swift       # Phone number + OTP entry
│       │   ├── Feed/
│       │   │   ├── FeedView.swift        # Main scrollable feed
│       │   │   └── ItemCardView.swift    # Single item card in feed
│       │   ├── Upload/
│       │   │   ├── CameraView.swift      # Camera capture
│       │   │   └── ReviewListingView.swift  # AI-filled card, edit & confirm
│       │   ├── Detail/
│       │   │   └── ItemDetailView.swift  # Full item view + "I want this"
│       │   └── Profile/
│       │       └── MyListingsView.swift  # Items I've listed + their status
│       ├── ViewModels/
│       │   ├── AuthViewModel.swift       # Firebase OTP flow
│       │   ├── FeedViewModel.swift       # Fetch and filter feed
│       │   ├── UploadViewModel.swift     # Photo → AI identify → create item
│       │   └── ClaimViewModel.swift      # Claim flow + WhatsApp link
│       ├── Services/
│       │   ├── APIClient.swift           # Base HTTP client for backend
│       │   ├── AuthService.swift         # Firebase Auth wrapper
│       │   └── ImageService.swift        # Image upload to backend
│       ├── Utilities/
│       │   └── WhatsAppHelper.swift      # Generate and open WhatsApp links
│       └── Assets.xcassets
│
├── docs/
│   └── api-schema.md
└── README.md
```

## What Is Already Built

### Backend (ready to use)
- Full FastAPI app scaffold with routers, models, schemas
- **AI item identifier service** (`ai_identifier.py`): Takes image bytes, sends to Claude Vision, returns structured listing data. This is the core feature and it works.
- SQLAlchemy models for User, Item, Claim with relationships
- Pydantic schemas for all API request/response shapes
- API routers with endpoint signatures and validation (business logic is stubbed with TODO markers)

### iOS App (nothing yet)
- Everything below needs to be created from scratch

## What Needs To Be Built (in priority order)

### Phase 1: iOS App Shell + Camera Flow (build this first)
This gives the most satisfying demo loop: snap photo → see AI magic → listing created.

**1a. Xcode Project Setup**
- Create new SwiftUI project targeting iOS 17+
- Add Firebase iOS SDK via Swift Package Manager (Auth package only)
- Set up project structure (Models, Views, ViewModels, Services folders)
- Configure Info.plist: camera usage description, photo library usage

**1b. APIClient Service**
- Base HTTP client using URLSession async/await
- Base URL configurable (localhost for dev, production URL later)
- Methods: `GET`, `POST`, `PATCH` with JSON encoding/decoding
- Multipart form upload for images
- Auth token injection via stored JWT
- Error handling with custom error types

```swift
// Target API shape:
class APIClient {
    static let shared = APIClient()
    var authToken: String?
    
    func post<T: Decodable>(_ path: String, body: Encodable) async throws -> T
    func get<T: Decodable>(_ path: String, query: [String: String]?) async throws -> T
    func uploadImage(_ path: String, imageData: Data) async throws -> AIIdentification
}
```

**1c. Upload Flow (the hero feature)**
- `CameraView`: Use PHPicker for photo selection (simpler than AVFoundation for MVP, works in Simulator too). Option to open system camera.
- `UploadViewModel`: Take selected image → compress to JPEG → call `POST /items/upload/identify` → receive AI-generated listing data
- `ReviewListingView`: Show AI results in an editable card — title, description, category (picker), condition (segmented control), tags (editable chips). "Looks good!" button to confirm → calls `POST /items/` to create listing.
- Show a nice loading animation while Claude is thinking (this takes 2-3 seconds)

**1d. Models (matching backend schemas)**
```swift
struct AIIdentification: Codable {
    let title: String
    let description: String
    let category: String
    let condition: String
    let tags: [String]
    let confidence: Double
}

struct Item: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let category: String
    let condition: String?
    let tags: [String]
    let imageUrls: [String]
    let status: String
    let owner: User
    let createdAt: Date
}
```

### Phase 2: Feed + Item Detail
**2a. FeedView**
- Vertical scrollable list of `ItemCardView` components
- Each card shows: item image (AsyncImage), title, category badge, condition, owner name, time ago
- Pull-to-refresh
- Category filter (horizontal scrollable chips at top)
- Call `GET /items/feed` with pagination

**2b. ItemDetailView**
- Full-screen item view with larger image (support swipe for multiple images)
- All item details
- "I want this" button (prominent, bottom of screen)
- If own item: show status controls and list of claimers instead

### Phase 3: Auth
**3a. Firebase Phone Auth**
- `LoginView`: Phone number input field (with +91 India default), "Send OTP" button
- OTP entry view (6 digit code input)
- `AuthViewModel`: Wraps Firebase `PhoneAuthProvider.verifyPhoneNumber` and `signIn(with:)`
- On successful Firebase auth: call `POST /auth/login` with Firebase ID token → store returned JWT
- Persist auth state (Keychain for token, UserDefaults for user profile)

**3b. Auth Flow Integration**
- Root `ContentView` checks for stored auth token
- If not authenticated → show `LoginView`
- If authenticated → show main `TabView` (Feed, Upload, My Listings)

### Phase 4: Claims + WhatsApp
- "I want this" button calls `POST /claims/{item_id}`
- Response includes WhatsApp deep link
- Open WhatsApp via `UIApplication.shared.open(url)`
- `MyListingsView`: Show items I've listed with claim count badges

### Phase 5: Wire Up Backend (parallel with iOS)
- Complete the TODO stubs in the Python backend:
  - database.py (async engine + session)
  - Alembic migrations
  - Auth middleware (Firebase token verification)
  - Image storage service (S3/MinIO)
  - CRUD operations in all routers

## API Endpoints Reference

All endpoints are prefixed with `/api/v1`. Backend runs at `http://localhost:8000`.

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| POST | /auth/login | Verify Firebase token, return/create user | No |
| GET | /auth/me | Get current user profile | Yes |
| POST | /items/upload/identify | Upload photo → get AI listing details | Yes |
| POST | /items/ | Create item listing | Yes |
| GET | /items/feed | Browse available items | Yes |
| GET | /items/{id} | Get item details | Yes |
| PATCH | /items/{id}/status | Update item status | Yes (owner) |
| POST | /claims/{item_id} | Express interest in item | Yes |
| GET | /claims/my-claims | Items I have claimed | Yes |
| GET | /claims/my-items/{id}/claims | Who wants my item | Yes (owner) |

### Key Request/Response Shapes

**POST /items/upload/identify** — multipart/form-data with `photo` field
```json
// Response:
{
  "title": "Kids' Blue Bicycle with Training Wheels",
  "description": "Small bicycle suitable for ages 3-5, comes with training wheels attached.",
  "category": "Kids",
  "condition": "Good",
  "tags": ["bicycle", "kids", "blue", "training wheels", "outdoor"],
  "confidence": 0.92
}
```

**POST /claims/{item_id}**
```json
// Response:
{
  "whatsapp_link": "https://wa.me/91XXXXXXXXXX?text=Hey!%20I%20saw%20your...",
  "claim_status": "pending"
}
```

## iOS Design Guidelines

- **Minimal and warm**: Think WhatsApp simplicity meets a friendly marketplace
- **System components first**: Use native SwiftUI components (NavigationStack, TabView, List, AsyncImage) before reaching for custom UI
- **Camera-first UX**: The upload/camera button should be the most prominent element — a large FAB or center tab item
- **One-handed use**: Key actions (snap, confirm, claim) should be reachable with a thumb
- **Loading states**: The AI identification takes 2-3 seconds. Use a nice skeleton or animation. This is the moment where the magic happens — make it feel intentional, not slow.
- **System colors and Dark Mode**: Support both light and dark mode using semantic colors

## Environment Setup for iOS Dev

1. Open Xcode, create new SwiftUI project "Shareish" targeting iOS 17
2. Add Firebase via SPM: `https://github.com/firebase/firebase-ios-sdk` (add FirebaseAuth only)
3. Download `GoogleService-Info.plist` from Firebase Console, add to project
4. For backend: `cd backend && pip install -r requirements.txt && cp .env.example .env` → set API keys → `uvicorn app.main:app --reload`
5. iOS Simulator talks to `localhost:8000` by default — no extra config needed

## Coding Conventions (iOS)

- SwiftUI with MVVM: Views are dumb, ViewModels hold logic, Services handle API/storage
- Use async/await everywhere (no Combine unless needed for Firebase callbacks)
- `@MainActor` on all ViewModels
- Codable for all models, use `CodingKeys` with `convertFromSnakeCase` decoder strategy to match Python backend's snake_case
- Use Swift enums for fixed sets: `ItemCategory`, `ItemCondition`, `ItemStatus`
- Prefer `@StateObject` for ViewModel ownership, `@ObservedObject` for passing down
- No third-party dependencies beyond Firebase Auth — keep it lean

## What Success Looks Like

A working iOS app where I can:
1. Open the app on Simulator (or my iPhone via Xcode)
2. Take/select a photo of something I want to give away
3. See Claude AI auto-fill the listing details in ~3 seconds
4. Tap "Looks good" and see it appear in the feed
5. On another device: see that item, tap "I want this", and get a WhatsApp link

Keep it simple. Make it work. We can make it fancy later.
