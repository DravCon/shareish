import asyncio
import base64
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


def _to_absolute_image_url(url: str) -> str:
    """Return a loadable absolute URL. If url is already absolute, return as-is; else prepend public_origin."""
    s = (url or "").strip()
    if not s:
        return s
    if s.lower().startswith("http://") or s.lower().startswith("https://"):
        return s
    origin = (settings.public_origin or "").strip().rstrip("/")
    path = s if s.startswith("/") else f"/{s}"
    return f"{origin}{path}" if origin else url


def _first_upload_filename(url: str) -> Optional[str]:
    """If url is our upload path (e.g. .../uploads/xyz.jpg), return the filename (xyz.jpg)."""
    s = (url or "").strip()
    if not s:
        return None
    prefix = f"{settings.api_v1_prefix}/uploads/"
    if prefix in s:
        part = s.split(prefix, 1)[-1].split("?")[0].strip()
        if part and "/" not in part and ".." not in part:
            return part
    if s.startswith("/uploads/") or s.endswith("/uploads/"):
        part = s.split("/uploads/")[-1].split("?")[0].strip()
        if part and "/" not in part and ".." not in part:
            return part
    return None


def _read_first_image_as_base64(raw_urls: List[str]) -> Optional[str]:
    """If the first image URL points to a local upload file that exists, return its base64 content."""
    if not raw_urls:
        return None
    filename = _first_upload_filename(raw_urls[0])
    if not filename:
        return None
    upload_dir = Path(settings.upload_dir).resolve()
    file_path = upload_dir / filename
    try:
        if file_path.is_file():
            return base64.b64encode(file_path.read_bytes()).decode("ascii")
    except Exception:
        pass
    return None


def _upload_to_s3(data: bytes, filename: str, content_type: str) -> Optional[str]:
    """Upload bytes to S3/R2; return public URL if configured and successful, else None."""
    bucket = (settings.s3_bucket or "").strip()
    if not bucket or not (settings.aws_access_key_id and settings.aws_secret_access_key):
        return None
    key = f"uploads/{filename}"
    try:
        import boto3
        from botocore.config import Config
        client = boto3.client(
            "s3",
            region_name=settings.s3_region or "us-east-1",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            endpoint_url=settings.s3_endpoint_url or None,
            config=Config(signature_version="s3v4"),
        )
        client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
        )
        base = (settings.s3_public_base_url or "").strip().rstrip("/")
        if base:
            return f"{base}/{key}"
        region = settings.s3_region or "us-east-1"
        return f"https://{bucket}.s3.{region}.amazonaws.com/{key}"
    except Exception:
        return None


def _item_to_response(item: Item) -> ItemResponse:
    raw_urls = _urls_to_list(item.image_urls)
    image_urls = [ _to_absolute_image_url(u) for u in raw_urls ] if raw_urls else []
    first_image_base64 = _read_first_image_as_base64(raw_urls)
    return ItemResponse(
        id=item.id,
        title=item.title,
        description=item.description,
        category=item.category,
        condition=item.condition,
        tags=_tags_to_list(item.tags),
        image_urls=image_urls,
        status=item.status,
        owner=UserResponse(
            id=item.owner.id,
            phone_number=item.owner.phone_number,
            display_name=item.owner.display_name,
            created_at=item.owner.created_at,
        ),
        created_at=item.created_at,
        first_image_base64=first_image_base64,
    )


@router.post("/upload", response_model=ImageUploadResponse)
async def upload_image(
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Upload an image for a listing. Returns URL (S3/R2 if configured, else local /api/v1/uploads/...)."""
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
    content_type = photo.content_type or "image/jpeg"

    # Prefer S3/R2 when configured (persistent across redeploys)
    s3_url = _upload_to_s3(data, name, content_type)
    if s3_url:
        return ImageUploadResponse(url=s3_url)

    # Fall back to local disk
    upload_path = Path(settings.upload_dir).resolve()
    upload_path.mkdir(parents=True, exist_ok=True)
    file_path = upload_path / name
    file_path.write_bytes(data)
    path = f"{settings.api_v1_prefix}/uploads/{name}"
    if settings.public_origin:
        origin = settings.public_origin.strip().rstrip("/")
        path = f"{origin}{path}" if path.startswith("/") else f"{origin}/{path}"
    return ImageUploadResponse(url=path)


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
