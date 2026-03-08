import base64
from typing import Optional

from anthropic import Anthropic

from app.config import settings

_client: Optional[Anthropic] = None


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        if not settings.anthropic_api_key:
            raise ValueError("ANTHROPIC_API_KEY is not set")
        _client = Anthropic(api_key=settings.anthropic_api_key)
    return _client


SYSTEM_PROMPT = """You are an assistant that identifies physical items from a photo for a give-away marketplace.
Given an image, respond with a JSON object only (no markdown, no explanation) with these exact keys:
- title: string (short, clear item name)
- description: string (1-3 sentences describing the item and its condition)
- category: string (exactly one of: Electronics, Furniture, Kids, Clothing, Books, Outdoor, Other)
- condition: string (exactly one of: Like New, Good, Fair, Used, Other)
- tags: array of strings (lowercase keywords, 3-8 tags)
- confidence: number between 0 and 1

Be concise and accurate. If the image is unclear or not a single item, guess the most likely item."""


def identify_item_from_image(image_bytes: bytes) -> dict:
    client = _get_client()
    image_b64 = base64.standard_b64encode(image_bytes).decode("ascii")
    media_type = "image/jpeg"

    try:
        # Use an active model; claude-3-5-sonnet-20241022 was retired Oct 2025
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                    ],
                },
            ],
        )
    except Exception as e:
        raise ValueError(f"Anthropic API error: {e}") from e

    if not response.content:
        raise ValueError("AI returned no content")
    first_block = response.content[0]
    text = getattr(first_block, "text", None) or "{}"
    # Parse JSON from response (handle optional markdown code block)
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1]) if len(lines) > 2 else text
    import json
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI returned invalid JSON: {e}") from e

    # Normalize so Pydantic never gets wrong types (avoids 500)
    raw_tags = data.get("tags")
    if isinstance(raw_tags, list):
        tags = [str(t) for t in raw_tags]
    else:
        tags = []
    try:
        confidence = float(data.get("confidence", 0.9))
    except (TypeError, ValueError):
        confidence = 0.9
    confidence = max(0.0, min(1.0, confidence))

    return {
        "title": str(data.get("title") or "Item")[:200],
        "description": str(data.get("description") or "")[:2000],
        "category": str(data.get("category") or "Other")[:64],
        "condition": str(data.get("condition") or "Used")[:64],
        "tags": tags[:20],
        "confidence": confidence,
    }
