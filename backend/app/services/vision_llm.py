"""Vision-LLM "second opinion" via the Anthropic API (README §6, §11).

The API key is read by the SDK from ANTHROPIC_API_KEY on the server; it is
never sent to, or stored in, the Android app. Images are passed in memory
only and are not written anywhere.
"""

from __future__ import annotations

import base64
import json
import logging

import anthropic
from pydantic import ValidationError

from ..config import settings
from ..schemas.models import ENRICH_JSON_SCHEMA, EnrichResult

log = logging.getLogger(__name__)

SYSTEM_PROMPT = """You help a recycling app identify plastic items from a single photo.
Return JSON only, matching the schema.
- object_name: a short everyday name for the main object (e.g. "Yoghurt pot", "Shampoo bottle").
- contains_plastic: whether the main object is mostly plastic.
- resin_code_visible: the number inside a printed resin identification code triangle (1-7) ONLY if you can clearly read it in this photo; otherwise null. Never guess this from the object type.
- likely_polymer: your best visual guess among PET, HDPE, PVC, LDPE, PP, PS, or null if it is not plastic or you cannot tell.
- notes: one short sentence on visual evidence (colour, transparency, shape, markings), or null."""


class LLMUnavailable(Exception):
    """The model call failed, was refused, or returned unusable output."""


class VisionLLM:
    def __init__(self, client: anthropic.AsyncAnthropic | None = None):
        self._client = client or anthropic.AsyncAnthropic(timeout=settings.llm_timeout_s, max_retries=1)

    async def identify(self, image: bytes, media_type: str) -> EnrichResult:
        try:
            response = await self._client.beta.messages.create(
                model=settings.llm_model,
                max_tokens=2048,
                # Refusal safety net: on a policy decline the API re-runs the
                # request on a suitable fallback model inside the same call.
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
                output_config={
                    "effort": "low",  # quick visual classification; latency matters
                    "format": {"type": "json_schema", "schema": ENRICH_JSON_SCHEMA},
                },
                system=SYSTEM_PROMPT,
                messages=[{
                    "role": "user",
                    "content": [
                        {"type": "image", "source": {"type": "base64", "media_type": media_type,
                                                     "data": base64.standard_b64encode(image).decode()}},
                        {"type": "text", "text": "Identify the main object in this photo."},
                    ],
                }],
            )
        except anthropic.RateLimitError as e:
            raise LLMUnavailable("upstream rate limit") from e
        except anthropic.APIStatusError as e:
            log.warning("LLM API error %s", e.status_code)
            raise LLMUnavailable(f"upstream error {e.status_code}") from e
        except anthropic.APIConnectionError as e:
            raise LLMUnavailable("upstream unreachable") from e

        if response.stop_reason == "refusal":
            raise LLMUnavailable("request declined")
        if response.stop_reason == "max_tokens":
            raise LLMUnavailable("output truncated")
        text = next((b.text for b in response.content if b.type == "text"), None)
        if text is None:
            raise LLMUnavailable("no text in response")
        return parse_result(text)


def parse_result(text: str) -> EnrichResult:
    """Validate model output; anything malformed becomes LLMUnavailable."""
    try:
        return EnrichResult.model_validate(json.loads(text))
    except (json.JSONDecodeError, ValidationError, TypeError) as e:
        log.warning("Invalid LLM output rejected: %s", e)
        raise LLMUnavailable("invalid model output") from e
