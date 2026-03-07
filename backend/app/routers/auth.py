import json
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User
from app.schemas import LoginRequest, LoginResponse, UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)


def _decode_firebase_token(id_token: str) -> Optional[dict]:
    """Verify Firebase ID token. Without firebase-admin we decode and trust (dev only)."""
    if not id_token:
        return None
    try:
        # Option: use firebase_admin.auth().verify_id_token(id_token) when configured
        # For dev: decode without verification (do not use in production)
        payload = jwt.decode(
            id_token,
            options={"verify_signature": False},
            algorithms=["RS256"],
        )
        return payload
    except Exception:
        return None


def create_access_token(user_id: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expire_minutes)
    to_encode = {"sub": user_id, "exp": expire}
    return jwt.encode(
        to_encode,
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def get_current_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> str:
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


def get_current_user(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    payload = _decode_firebase_token(request.id_token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid Firebase token")

    firebase_uid = payload.get("user_id") or payload.get("sub")
    phone = payload.get("firebase", {}).get("identities", {}).get("phone", [])
    phone_number = phone[0] if isinstance(phone, list) and phone else (payload.get("phone_number") or "unknown")

    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if not user:
        user = db.query(User).filter(User.phone_number == phone_number).first()
    if not user:
        user = User(
            firebase_uid=firebase_uid,
            phone_number=phone_number,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user.id)
    return LoginResponse(
        token=token,
        user=UserResponse(
            id=user.id,
            phone_number=user.phone_number,
            display_name=user.display_name,
            created_at=user.created_at,
        ),
    )


@router.post("/dev-login", response_model=LoginResponse)
def dev_login(phone_number: str = "+911234567890", db: Session = Depends(get_db)):
    """Dev only: get a token without Firebase. POST /api/v1/auth/dev-login or ?phone_number=+91..."""
    user = db.query(User).filter(User.phone_number == phone_number).first()
    if not user:
        user = User(phone_number=phone_number, firebase_uid=None)
        db.add(user)
        db.commit()
        db.refresh(user)
    token = create_access_token(user.id)
    return LoginResponse(
        token=token,
        user=UserResponse(
            id=user.id,
            phone_number=user.phone_number,
            display_name=user.display_name,
            created_at=user.created_at,
        ),
    )


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        phone_number=current_user.phone_number,
        display_name=current_user.display_name,
        created_at=current_user.created_at,
    )
