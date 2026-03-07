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
    # Detect media type; JPEG is common from phones
    media_type = "image/jpeg"

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
    text = response.content[0].text if response.content else "{}"
    # Parse JSON from response (handle optional markdown code block)
    text = text.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1]) if len(lines) > 2 else text
    import json
    data = json.loads(text)
    return {
        "title": data.get("title", "Item"),
        "description": data.get("description", ""),
        "category": data.get("category", "Other"),
        "condition": data.get("condition", "Used"),
        "tags": data.get("tags", []),
        "confidence": float(data.get("confidence", 0.9)),
    }
