# Firebase OTP setup – checklist

Use this to confirm everything is in place for phone login via Firebase (no backend SMS/Twilio needed).

---

## 1. Firebase Console

- [ ] Project created in [Firebase Console](https://console.firebase.google.com)
- [ ] **Authentication** → **Sign-in method** → **Phone** is **Enabled**
- [ ] Under **Project settings** → **General**, your iOS app is added (bundle ID matches your app, e.g. `com.yourcompany.Shareish`)

---

## 2. iOS app

- [ ] **GoogleService-Info.plist** is in the project (downloaded from Firebase Console → Project settings → Your apps → iOS app).
- [ ] **GoogleService-Info.plist** is added to the app target (select the file in Xcode → Target Membership → Shareish checked).
- [ ] **Firebase SDK** is linked:
  - Via **Swift Package Manager**: add `https://github.com/firebase/firebase-ios-sdk`, then add **FirebaseAuth** and **FirebaseCore** to the Shareish target.
  - Or via CocoaPods: `pod 'Firebase/Auth'` (and run `pod install`).
- [ ] **GoogleService-Info.plist** has real values (not placeholders): replace `PROJECT_ID`, `API_KEY`, and **REVERSED_CLIENT_ID** with values from Firebase Console. The app only calls `FirebaseApp.configure()` when the plist has a valid-looking `PROJECT_ID` (avoids crash with placeholder plist).
- [ ] **Phone Auth flow** is in `LoginView.swift` / `AuthViewModel` (Firebase `verifyPhoneNumber` → enter code → `signIn` → get ID token → `POST /auth/login`). An **AuthUIDelegate** is used so reCAPTCHA can be presented when needed (simulator or when APNs is not used).

- [ ] **URL scheme for reCAPTCHA:** In Xcode → Target → **Info** → **URL Types**, add a type with **URL Scheme** = the value of **REVERSED_CLIENT_ID** from your `GoogleService-Info.plist`. Required for Phone Auth reCAPTCHA redirect on iOS.
- [ ] **Test phone number (optional):** In Firebase Console → **Authentication** → **Sign-in method** → **Phone** → **Phone numbers for testing**, add a test number and fixed verification code (e.g. `123456`). Use that number in the app to sign in without SMS.

<!-- AuthUIDelegate is now implemented in app. -->

---

## 3. Backend (Railway / your host)

- [ ] **firebase-admin** is in `requirements.txt` (already added).
- [ ] **Firebase service account** for **server-side verification**:
  - In Firebase Console → Project settings → **Service accounts** → **Generate new private key**.
  - Put the JSON contents in a **single env var** on your backend, e.g. `FIREBASE_SERVICE_ACCOUNT_JSON` (paste the whole JSON string; Railway allows multi-line secrets).
  - Or upload the JSON file and set `GOOGLE_APPLICATION_CREDENTIALS` to its path (e.g. in the container).
- [ ] Endpoint **POST /api/v1/auth/firebase_login** is deployed (accepts `{"id_token": "..."}`, verifies with Firebase, returns your app’s JWT and user).

---

## 4. Quick test

1. Run the app → Log in with phone number.
2. Enter a phone number (e.g. +1 …) → Send code.
3. If reCAPTCHA appears, complete it; Firebase sends an SMS with the code.
4. Enter the code → Verify. You should be logged in and the backend logs should show a successful `firebase_login` (no “Invalid or expired Firebase token”).

If “Invalid or expired Firebase token” appears, the backend is not verifying the token correctly: check that `FIREBASE_SERVICE_ACCOUNT_JSON` (or `GOOGLE_APPLICATION_CREDENTIALS`) is set and that the Firebase project matches the one used by the iOS app (same project as in `GoogleService-Info.plist`).
