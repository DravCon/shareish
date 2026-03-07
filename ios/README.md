# Shareish iOS App

SwiftUI app (iOS 17+) for the Shareish give-away marketplace. See the [project brief](../CURSOR_PROJECT_BRIEF.md) for full spec.

## Setup

1. **Open in Xcode**  
   Open `Shareish.xcodeproj` (or the `ios` folder) in Xcode.

2. **Add Firebase (required for phone auth)**  
   In Xcode: **File → Add Package Dependencies** → enter URL `https://github.com/firebase/firebase-ios-sdk`.

   **Important:** Do **not** use the `main` branch or a local clone of the repo—that can fail with dependency resolution errors (e.g. `google-ads-on-device-conversion-ios-sdk`). Use a **released version** instead:
   - Set the dependency rule to **"Up to Next Major Version"** and choose **10.24.0** (or **11.0.0**), then Add Package.
   - On the product list, select **FirebaseAuth** and **FirebaseCore** only (leave others unchecked) and add them to the Shareish target.

   The app uses `#if canImport(FirebaseAuth)` so it builds without Firebase; add the package to enable sign-in.

3. **GoogleService-Info.plist**  
   A placeholder plist is included so the app builds. For real Firebase Auth (phone sign-in):
   - In [Firebase Console](https://console.firebase.google.com), add an iOS app with bundle ID `com.shareish.Shareish` and download `GoogleService-Info.plist`.
   - Replace `Shareish/GoogleService-Info.plist` in the project with your downloaded file (or drag it in and remove the placeholder).

4. **Backend**  
   - Default API base URL is `http://localhost:8000/api/v1`.  
   - Run the backend (see repo root / backend README) and use the Simulator or a device on the same network (or change the base URL in `APIClient.swift` for a deployed backend).

## Run

- Select the Shareish scheme and an iOS 17+ simulator (e.g. iPhone 16).  
- Build and run (⌘R).  
- Without Firebase: you’ll see the login screen; sign-in will fail until the Firebase SDK and `GoogleService-Info.plist` are added.

## Structure

- **Models/** – `User`, `Item`, `Claim`, `AIIdentification`, `LoginResponse`  
- **Views/** – Auth, Feed, Upload, Detail, Profile  
- **ViewModels/** – Auth, Feed, Upload, Claim  
- **Services/** – `APIClient`, `AuthService`, `KeychainHelper`, `ImageService`  
- **Utilities/** – `WhatsAppHelper`
