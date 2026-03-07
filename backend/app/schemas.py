from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


# ----- User -----
class UserBase(BaseModel):
    phone_number: str
    display_name: Optional[str] = None


class UserCreate(UserBase):
    firebase_uid: Optional[str] = None


class UserResponse(BaseModel):
    id: str
    phone_number: str
    display_name: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ----- Auth -----
class LoginRequest(BaseModel):
    id_token: str

    model_config = {"populate_by_name": True}


class LoginResponse(BaseModel):
    token: str
    user: UserResponse


# ----- Item -----
class AIIdentificationResponse(BaseModel):
    title: str
    description: str
    category: str
    condition: str
    tags: List[str]
    confidence: float


class ItemCreate(BaseModel):
    title: str
    description: str
    category: str
    condition: str
    tags: List[str]
    image_urls: List[str] = []


class ItemUpdateStatus(BaseModel):
    status: str  # available, taken, reserved


class ItemResponse(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    category: str
    condition: Optional[str] = None
    tags: List[str]
    image_urls: List[str]
    status: str
    owner: UserResponse
    created_at: datetime

    class Config:
        from_attributes = True


# ----- Claim -----
class ClaimResponse(BaseModel):
    whatsapp_link: str
    claim_status: str


class ClaimItemResponse(BaseModel):
    id: str
    item_id: str
    claimant_id: Optional[str] = None
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
