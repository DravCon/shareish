"""OTP generation, storage, and SMS sending (e.g. Twilio)."""
import random
import string
from datetime import datetime, timezone, timedelta
from typing import Any

# In-memory store: phone -> { "code": str, "expires_at": datetime }
_otp_store: dict[str, dict[str, Any]] = {}
# Rate limit: phone -> list of request timestamps (prune older than window)
_otp_requests: dict[str, list[datetime]] = {}

OTP_LENGTH = 6
OTP_EXPIRY_SECONDS = 5 * 60  # 5 minutes
RATE_LIMIT_COUNT = 3
RATE_LIMIT_WINDOW_SECONDS = 15 * 60  # 15 minutes


def normalize_phone(phone: str) -> str:
    """Normalize to digits only with leading + for storage key."""
    digits = "".join(c for c in phone if c.isdigit())
    return f"+{digits}" if digits else phone


def _normalize_phone(phone: str) -> str:
    return normalize_phone(phone)


def generate_and_store_otp(phone: str) -> str:
    """Generate a numeric OTP, store it with expiry, return the code."""
    phone = _normalize_phone(phone)
    code = "".join(random.choices(string.digits, k=OTP_LENGTH))
    _otp_store[phone] = {
        "code": code,
        "expires_at": datetime.now(timezone.utc) + timedelta(seconds=OTP_EXPIRY_SECONDS),
    }
    return code


def consume_otp(phone: str, code: str) -> bool:
    """Verify and consume OTP. Returns True if valid."""
    phone = _normalize_phone(phone)
    entry = _otp_store.get(phone)
    if not entry:
        return False
    if datetime.now(timezone.utc) > entry["expires_at"]:
        del _otp_store[phone]
        return False
    if entry["code"] != code.strip():
        return False
    del _otp_store[phone]
    return True


def rate_limit_exceeded(phone: str) -> bool:
    """True if this phone has requested too many OTPs in the window."""
    phone = _normalize_phone(phone)
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=RATE_LIMIT_WINDOW_SECONDS)
    if phone not in _otp_requests:
        return False
    _otp_requests[phone] = [t for t in _otp_requests[phone] if t > cutoff]
    return len(_otp_requests[phone]) >= RATE_LIMIT_COUNT


def record_otp_request(phone: str) -> None:
    """Call after sending an OTP to record the request for rate limiting."""
    phone = _normalize_phone(phone)
    now = datetime.now(timezone.utc)
    _otp_requests.setdefault(phone, []).append(now)


def send_otp_sms(phone: str, code: str) -> bool:
    """
    Send OTP via Twilio if configured; otherwise log and return True so dev can use code from logs.
    Returns True if send succeeded or we're in dev mode (no Twilio).
    """
    from app.config import settings
    phone = _normalize_phone(phone)
    if settings.twilio_account_sid and settings.twilio_auth_token and settings.twilio_phone_number:
        try:
            from twilio.rest import Client
            client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
            client.messages.create(
                body=f"Your Shareish verification code is: {code}. Valid for 5 minutes.",
                from_=settings.twilio_phone_number,
                to=phone,
            )
            return True
        except Exception:
            return False
    # Dev: log code so you can use it (e.g. in Railway logs)
    import logging
    logging.getLogger("uvicorn.error").info(f"[Shareish OTP] phone={phone} code={code}")
    return True
