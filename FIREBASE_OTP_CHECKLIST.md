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
- [ ] **FirebaseApp.configure()** is called at app launch (already added in `ShareishApp.swift`).
- [ ] **Phone Auth flow** is implemented in `AuthView.swift` (Firebase `verifyPhoneNumber` → user enters code → `signIn` → get ID token → call backend `firebase_login`).

**Optional for production:** If Firebase prompts for reCAPTCHA on iOS, you may need to implement a `AuthUIDelegate` (e.g. present a `SFSafariViewController` or Firebase’s reCAPTCHA view). For testing, nil `uiDelegate` can work when the device is allowed in Firebase.

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
