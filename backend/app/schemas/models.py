from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Polymer = Literal["PET", "HDPE", "PVC", "LDPE", "PP", "PS"]


class EnrichResult(BaseModel):
    """Validated vision-LLM output returned to the app (README §6).

    Strict: no coercion ("yes" is not a bool, "5" is not an int)."""

    model_config = ConfigDict(extra="forbid", strict=True)

    object_name: str = Field(min_length=1, max_length=80)
    contains_plastic: bool
    resin_code_visible: Optional[int] = Field(default=None, ge=1, le=7)
    likely_polymer: Optional[Polymer] = None
    notes: Optional[str] = Field(default=None, max_length=300)


# JSON schema sent to the model (structured outputs). Range limits are
# enforced afterwards by EnrichResult, which is the source of truth.
ENRICH_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "object_name": {"type": "string", "description": "Short everyday name, e.g. 'Water bottle'"},
        "contains_plastic": {"type": "boolean"},
        "resin_code_visible": {
            "anyOf": [{"type": "integer", "enum": [1, 2, 3, 4, 5, 6, 7]}, {"type": "null"}],
            "description": "Number inside a printed resin-code triangle if clearly readable, else null",
        },
        "likely_polymer": {
            "anyOf": [{"type": "string", "enum": ["PET", "HDPE", "PVC", "LDPE", "PP", "PS"]}, {"type": "null"}],
        },
        "notes": {"anyOf": [{"type": "string"}, {"type": "null"}]},
    },
    "required": ["object_name", "contains_plastic", "resin_code_visible", "likely_polymer", "notes"],
    "additionalProperties": False,
}


class PlasticType(BaseModel):
    material: Polymer
    full_name: str = Field(max_length=80)
    resin_code: int = Field(ge=1, le=6)
    description: str = Field(max_length=600)
    properties: list[str]
    common_items: list[str]
    other_materials: list[str] = []
    recycling_guidance: list[str]
    recyclability_rating: int = Field(ge=1, le=5)
    recyclability_note: str = Field(max_length=400)
    fact: str = Field(max_length=400)
    eco_tip: str = Field(max_length=300)
    sources: list[str] = []


class FeedbackIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scan_id: str = Field(min_length=1, max_length=64)
    predicted: Optional[str] = Field(default=None, max_length=20)
    corrected: Literal["PET", "HDPE", "PVC", "LDPE", "PP", "PS", "non_plastic"]
    confidence: Optional[float] = Field(default=None, ge=0, le=1)
    model_version: Optional[str] = Field(default=None, max_length=40)


class Feedback(FeedbackIn):
    model_config = ConfigDict(extra="ignore")

    id: str
    user_id: str
    status: Literal["new", "reviewed", "applied", "rejected"] = "new"
    created_at: Optional[str] = None
