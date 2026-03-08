import asyncio
import json
import os
import uuid
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import ValidationError
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Item, User
from app.routers.auth import get_current_user
from app.schemas import AIIdentificationResponse, ImageUploadResponse, ItemCreate, ItemResponse, ItemUpdateStatus, UserResponse
from app.services.ai_identifier import identify_item_from_image

router = APIRouter(prefix="/items", tags=["items"])


def _tags_to_list(tags_str: Optional[str]) -> List[str]:
    if not tags_str:
        return []
    try:
        return json.loads(tags_str)
    except Exception:
        return []


def _urls_to_list(urls_str: Optional[str]) -> List[str]:
    if not urls_str:
        return []
    try:
        return json.loads(urls_str)
    except Exception:
        return []


def _item_to_response(item: Item) -> ItemResponse:
    return ItemResponse(
        id=item.id,
        title=item.title,
        description=item.description,
        category=item.category,
        condition=item.condition,
        tags=_tags_to_list(item.tags),
        image_urls=_urls_to_list(item.image_urls),
        status=item.status,
        owner=UserResponse(
            id=item.owner.id,
            phone_number=item.owner.phone_number,
            display_name=item.owner.display_name,
            created_at=item.owner.created_at,
        ),
        created_at=item.created_at,
    )


@router.post("/upload", response_model=ImageUploadResponse)
async def upload_image(
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Upload an image for a listing. Returns URL path (e.g. /uploads/xyz.jpg) to use in image_urls when creating the item."""
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    data = await photo.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    ext = "jpg"
    if photo.filename and "." in photo.filename:
        ext = photo.filename.rsplit(".", 1)[-1].lower()
    if ext not in ("jpg", "jpeg", "png", "gif", "webp"):
        ext = "jpg"
    name = f"{uuid.uuid4().hex}.{ext}"
    upload_path = Path(settings.upload_dir).resolve()
    upload_path.mkdir(parents=True, exist_ok=True)
    file_path = upload_path / name
    file_path.write_bytes(data)
    # Path under API prefix so GET /api/v1/uploads/xyz works (proxies forward /api/v1)
    return ImageUploadResponse(url=f"{settings.api_v1_prefix}/uploads/{name}")


@router.post("/upload/identify", response_model=AIIdentificationResponse)
async def upload_identify(
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    data = await photo.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    try:
        result = await asyncio.to_thread(identify_item_from_image, data)
        return AIIdentificationResponse(
            title=result["title"],
            description=result["description"],
            category=result["category"],
            condition=result["condition"],
            tags=result["tags"],
            confidence=result["confidence"],
        )
    except ValueError as e:
        msg = str(e)
        if "ANTHROPIC_API_KEY" in msg or "not set" in msg:
            raise HTTPException(
                status_code=503,
                detail="AI identification is not configured. Set ANTHROPIC_API_KEY on the server.",
            ) from e
        raise HTTPException(status_code=503, detail=f"AI identification failed: {msg}") from e
    except ValidationError as e:
        raise HTTPException(
            status_code=503,
            detail=f"AI returned invalid format: {e}",
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"AI identification failed: {str(e)}",
        ) from e


@router.post("/", response_model=ItemResponse)
def create_item(
    body: ItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = Item(
        title=body.title,
        description=body.description,
        category=body.category,
        condition=body.condition,
        tags=json.dumps(body.tags),
        image_urls=json.dumps(body.image_urls or []),
        status="available",
        owner_id=current_user.id,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return _item_to_response(item)


@router.get("/feed", response_model=List[ItemResponse])
def get_feed(
    category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(Item).filter(Item.status == "available").order_by(Item.created_at.desc())
    if category:
        q = q.filter(Item.category == category)
    items = q.limit(100).all()
    return [_item_to_response(i) for i in items]


@router.get("/{item_id}", response_model=ItemResponse)
def get_item(
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Case-insensitive lookup (client may send UUID in different casing)
    item_id_clean = (item_id or "").strip().lower()
    if not item_id_clean or len(item_id_clean) != 36:
        raise HTTPException(status_code=404, detail="Item not found")
    item = db.query(Item).filter(func.lower(Item.id) == item_id_clean).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return _item_to_response(item)


@router.patch("/{item_id}/status", response_model=ItemResponse)
def update_item_status(
    item_id: str,
    body: ItemUpdateStatus,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item_id_clean = (item_id or "").strip().lower()
    item = db.query(Item).filter(func.lower(Item.id) == item_id_clean).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not the owner")
    item.status = body.status
    db.commit()
    db.refresh(item)
    return _item_to_response(item)
