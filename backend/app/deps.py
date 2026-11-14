"""Shared singletons, injected with FastAPI Depends so tests can override them."""

from __future__ import annotations

from functools import lru_cache

from .config import settings
from .services.rate_limit import RateLimiter
from .services.store import FirestoreStore, Store
from .services.vision_llm import VisionLLM


@lru_cache(maxsize=1)
def get_llm() -> VisionLLM:
    return VisionLLM()


@lru_cache(maxsize=1)
def get_store() -> Store:
    return FirestoreStore()


@lru_cache(maxsize=1)
def get_limiter() -> RateLimiter:
    return RateLimiter(settings.enrich_per_hour)
