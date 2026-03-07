import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, ForeignKey, DateTime, Enum as SQLEnum
from sqlalchemy.dialects.sqlite import CHAR
from sqlalchemy.orm import relationship

from app.database import Base


def uuid_str():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(CHAR(36), primary_key=True, default=uuid_str)
    firebase_uid = Column(String(128), unique=True, nullable=True, index=True)
    phone_number = Column(String(32), nullable=False, index=True)
    display_name = Column(String(128), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    items = relationship("Item", back_populates="owner", foreign_keys="Item.owner_id")
    claims_made = relationship("Claim", back_populates="claimant", foreign_keys="Claim.claimant_id")


class Item(Base):
    __tablename__ = "items"

    id = Column(CHAR(36), primary_key=True, default=uuid_str)
    title = Column(String(256), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(64), nullable=False)
    condition = Column(String(64), nullable=True)
    tags = Column(Text, nullable=True)  # JSON array as string
    image_urls = Column(Text, nullable=True)  # JSON array as string
    status = Column(String(32), default="available")  # available, taken, reserved
    owner_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="items", foreign_keys=[owner_id])
    claims = relationship("Claim", back_populates="item", foreign_keys="Claim.item_id")


class Claim(Base):
    __tablename__ = "claims"

    id = Column(CHAR(36), primary_key=True, default=uuid_str)
    item_id = Column(CHAR(36), ForeignKey("items.id"), nullable=False)
    claimant_id = Column(CHAR(36), ForeignKey("users.id"), nullable=False)
    status = Column(String(32), default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

    item = relationship("Item", back_populates="claims", foreign_keys=[item_id])
    claimant = relationship("User", back_populates="claims_made", foreign_keys=[claimant_id])
