# Phone + OTP Login

The app supports login (and registration) via phone number and a one-time code (OTP).

## Flow

1. User enters phone number → app calls `POST /api/v1/auth/send_otp` with `{"phone_number": "+..."}`.
2. Backend generates a 6-digit code, stores it for 5 minutes, and sends it via SMS (or logs it in dev).
3. User enters the code → app calls `POST /api/v1/auth/verify_otp` with `{"phone_number": "+...", "code": "123456"}`.
4. Backend verifies the code, finds or creates the user by phone, and returns `{ "user": {...}, "token": "<JWT>" }`.
5. App stores the token and uses it in the `Authorization: Bearer <token>` header for subsequent requests.

## Backend env vars (optional for SMS)

To actually send SMS, set:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER` (the Twilio “from” number)

If these are not set, the backend still generates and stores OTPs but **logs the code** to the server log (e.g. in Railway deploy logs) so you can use it for testing. No SMS is sent.

## Rate limiting

- Up to 3 OTP requests per phone per 15 minutes (in-memory; resets on restart).

## Database

- The `User` model has an optional `phone` field (unique). Existing users keep `username`; new phone-only users have `username=null` and `phone` set.
- If you already have a `users` table without a `phone` column, add it (e.g. `ALTER TABLE users ADD COLUMN phone VARCHAR(20) UNIQUE;`) or run a migration. New deploys with `create_all` will create the table with `phone` if the table is created from scratch.
