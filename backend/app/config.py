"""Settings from environment variables. Secrets never live in the app or repo."""

from __future__ import annotations

import os
from dataclasses import dataclass, field


def _list(name: str, default: str) -> list[str]:
    return [v.strip() for v in os.getenv(name, default).split(",") if v.strip()]


@dataclass(frozen=True)
class Settings:
    # ANTHROPIC_API_KEY is read by the Anthropic SDK itself.
    llm_model: str = os.getenv("ENRICH_MODEL", "claude-opus-5-5")
    llm_timeout_s: float = float(os.getenv("ENRICH_TIMEOUT_S", "20"))
    enrich_per_hour: int = int(os.getenv("ENRICH_PER_HOUR", "30"))
    max_image_bytes: int = int(os.getenv("MAX_IMAGE_BYTES", str(5 * 1024 * 1024)))
    # Firebase Admin uses GOOGLE_APPLICATION_CREDENTIALS (service-account JSON
    # path) or the runtime's default credentials on Cloud Run.
    firebase_project: str = os.getenv("FIREBASE_PROJECT", "plasticlens-61083")
    cors_origins: list[str] = field(default_factory=lambda: _list("CORS_ORIGINS", "https://plasticlens-61083.web.app"))


settings = Settings()
