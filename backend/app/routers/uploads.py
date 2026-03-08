"""Serve uploaded listing images. Uses the same directory as the upload endpoint."""
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.config import settings

router = APIRouter(prefix="/uploads", tags=["uploads"])

# Resolve once at import so it matches the upload handler (same settings.upload_dir)
_UPLOAD_DIR = Path(settings.upload_dir).resolve()


@router.get("/{filename}")
def get_uploaded_file(filename: str):
    """Serve an uploaded image. Filename must be a single path segment (no slashes)."""
    if "/" in filename or ".." in filename or not filename.strip():
        raise HTTPException(status_code=404, detail="Not found")
    _UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    file_path = _UPLOAD_DIR / filename
    if not file_path.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return FileResponse(
        path=str(file_path),
        media_type=None,  # let FileResponse guess from extension
        headers={"Cache-Control": "public, max-age=86400"},
    )
