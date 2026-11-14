from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from ..auth import User, current_user
from ..config import settings
from ..deps import get_limiter, get_llm
from ..schemas.models import EnrichResult
from ..services.rate_limit import RateLimiter
from ..services.vision_llm import LLMUnavailable, VisionLLM

router = APIRouter(prefix="/api/identify", tags=["identify"])

_SIGNATURES = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
}


def sniff_image_type(data: bytes) -> str | None:
    for magic, media_type in _SIGNATURES.items():
        if data.startswith(magic):
            return media_type
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


@router.post("/enrich", response_model=EnrichResult)
async def enrich(
    image: UploadFile = File(...),
    user: User = Depends(current_user),
    llm: VisionLLM = Depends(get_llm),
    limiter: RateLimiter = Depends(get_limiter),
) -> EnrichResult:
    """Second opinion from a vision LLM. The image is processed in memory
    and never stored on the server."""
    allowed, retry_after = limiter.allow(user.uid)
    if not allowed:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Hourly limit reached", headers={"Retry-After": str(retry_after)})

    data = await image.read(settings.max_image_bytes + 1)
    if len(data) > settings.max_image_bytes:
        raise HTTPException(status.HTTP_413_CONTENT_TOO_LARGE, "Image larger than 5 MB")
    media_type = sniff_image_type(data)
    if media_type is None:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Send a JPEG, PNG or WebP image")

    try:
        return await llm.identify(data, media_type)
    except LLMUnavailable as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Second opinion unavailable: {e}") from None
