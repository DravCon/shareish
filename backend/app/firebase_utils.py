"""Verify Firebase ID tokens (e.g. from Firebase Phone Auth on iOS)."""
import json
import os
from typing import Any

_firebase_initialized = False


def _ensure_firebase() -> bool:
    """Initialize Firebase app if credentials are available. Returns True if ready."""
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials
        if not firebase_admin._apps:
            # Prefer JSON string in env (e.g. Railway secret) then ApplicationDefault (file path)
            json_str = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
            if json_str:
                cred = credentials.Certificate(json.loads(json_str))
            else:
                cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        return True
    except Exception:
        return False


def verify_firebase_id_token(id_token: str) -> dict[str, Any] | None:
    """
    Verify a Firebase ID token and return the decoded claims, or None if invalid.
    Claims include 'phone_number' for phone sign-in and 'uid'.
    """
    if not id_token or not id_token.strip():
        return None
    if not _ensure_firebase():
        return None
    try:
        from firebase_admin import auth
        return auth.verify_id_token(id_token.strip())
    except Exception:
        return None
