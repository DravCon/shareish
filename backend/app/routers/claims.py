import urllib.parse
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Claim, Item, User
from app.routers.auth import get_current_user
from app.schemas import ClaimItemResponse, ClaimResponse

router = APIRouter(prefix="/claims", tags=["claims"])


@router.post("/{item_id}", response_model=ClaimResponse)
def create_claim(
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item.status != "available":
        raise HTTPException(status_code=400, detail="Item is not available")
    if item.owner_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot claim your own item")

    existing = db.query(Claim).filter(Claim.item_id == item_id, Claim.claimant_id == current_user.id).first()
    if existing:
        # Return existing claim with WhatsApp link
        link = _whatsapp_link(item.owner.phone_number, item.title)
        return ClaimResponse(whatsapp_link=link, claim_status=existing.status)

    claim = Claim(item_id=item_id, claimant_id=current_user.id, status="pending")
    db.add(claim)
    db.commit()

    link = _whatsapp_link(item.owner.phone_number, item.title)
    return ClaimResponse(whatsapp_link=link, claim_status="pending")


def _whatsapp_link(owner_phone: str, item_title: str) -> str:
    """Build WhatsApp deep link: wa.me/<number>?text=..."""
    phone = "".join(c for c in owner_phone if c.isdigit() or c == "+")
    if not phone.startswith("+"):
        phone = "+91" + phone[-10:] if len(phone) >= 10 else "+91" + phone
    text = f"Hey! I saw your listing \"{item_title}\" on Shareish and I'd like to take it. When can I pick it up?"
    return f"https://wa.me/{phone.lstrip('+')}?text={urllib.parse.quote(text)}"


@router.get("/my-claims", response_model=List[ClaimItemResponse])
def my_claims(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    claims = db.query(Claim).filter(Claim.claimant_id == current_user.id).order_by(Claim.created_at.desc()).all()
    return [
        ClaimItemResponse(
            id=c.id,
            item_id=c.item_id,
            claimant_id=c.claimant_id,
            status=c.status,
            created_at=c.created_at,
        )
        for c in claims
    ]


@router.get("/my-items/{item_id}/claims", response_model=List[ClaimItemResponse])
def get_claims_for_my_item(
    item_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if item.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not the owner")
    claims = db.query(Claim).filter(Claim.item_id == item_id).all()
    return [
        ClaimItemResponse(
            id=c.id,
            item_id=c.item_id,
            claimant_id=c.claimant_id,
            status=c.status,
            created_at=c.created_at,
        )
        for c in claims
    ]
