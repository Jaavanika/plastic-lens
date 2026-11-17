"""Reuse / recycling suitability checker (PLAN Section 15; README §4.4, §7.3).

Turns the evidence about one item or batch into a status per recovery
pathway, with reasons. It never ranks pathways (that is the optimizer,
Section 16) and never invents thresholds: requirements without a cited
source can only make a pathway *less* certain, never feasible.

Statuses:
  feasible          all requirements met by sourced rules
  needs_inspection  plausible, but evidence is missing, uncertain or unsourced
  infeasible        a hard rule excludes it
  unavailable       no confirmed facility offers it
"""

from __future__ import annotations

from enum import Enum
from functools import lru_cache
from pathlib import Path
from typing import Literal, Optional

import yaml
from pydantic import BaseModel, ConfigDict, Field

CATALOGUE = Path(__file__).with_name("pathways.yaml")

Polymer = Literal["PET", "HDPE", "PVC", "LDPE", "PP", "PS"]
Provenance = Literal["measured", "user_entered", "ai_estimated", "unknown"]


class Contamination(str, Enum):
    clean = "clean"
    light = "light"            # removable by normal washing
    heavy = "heavy"            # e.g. food or oil residue that may not wash out
    hazardous = "hazardous"    # chemicals, medical, unknown hazardous contents
    unknown = "unknown"


class Condition(str, Enum):
    low = "low"                # low degradation
    moderate = "moderate"
    high = "high"
    unknown = "unknown"


class IntendedUse(str, Enum):
    general = "general"
    food_contact = "food_contact"
    medical = "medical"
    structural = "structural"
    child_product = "child_product"
    none = "none"              # no reuse planned


class Status(str, Enum):
    feasible = "feasible"
    needs_inspection = "needs_inspection"
    infeasible = "infeasible"
    unavailable = "unavailable"


class Evidence(BaseModel):
    """What is known about the item, with provenance (README §4.1)."""

    model_config = ConfigDict(extra="forbid")

    polymer: Optional[Polymer] = None
    polymer_provenance: Provenance = "unknown"
    polymer_confidence: Optional[float] = Field(default=None, ge=0, le=1)
    condition: Condition = Condition.unknown
    condition_provenance: Provenance = "unknown"
    condition_uncertain: bool = True
    contamination: Contamination = Contamination.unknown
    visible_cracks: Optional[bool] = None
    brittleness: Optional[bool] = None
    deformation: Optional[bool] = None
    intended_use: IntendedUse = IntendedUse.general
    permitted_locally: Optional[bool] = None


class PathwayResult(BaseModel):
    pathway: str
    label: str
    status: Status
    reasons: list[str]


class Assessment(BaseModel):
    pathways: list[PathwayResult]
    next_steps: list[str]      # process steps such as "verify material"


VERIFIED_POLYMER_CONFIDENCE = 0.70  # app's "High" threshold, chosen on validation data (model card §3)


@lru_cache(maxsize=1)
def catalogue() -> dict:
    data = yaml.safe_load(CATALOGUE.read_text(encoding="utf-8"))
    for key, p in data["pathways"].items():
        if not p.get("source"):
            raise ValueError(f"pathway {key} has no source")
    return data


def polymer_is_verified(e: Evidence) -> bool:
    if e.polymer is None:
        return False
    if e.polymer_provenance in ("measured", "user_entered"):
        return True
    return e.polymer_provenance == "ai_estimated" and (e.polymer_confidence or 0) >= VERIFIED_POLYMER_CONFIDENCE


def _damaged(e: Evidence) -> Optional[bool]:
    flags = [e.visible_cracks, e.brittleness, e.deformation]
    if any(f is True for f in flags):
        return True
    if all(f is False for f in flags):
        return False
    return None  # not (fully) checked


def _check(req: str, e: Evidence, cat: dict) -> tuple[Status, str | None]:
    """Status implied by one requirement (feasible = satisfied)."""
    ok, insp, no = Status.feasible, Status.needs_inspection, Status.infeasible
    if req == "not_safety_critical_use":
        if e.intended_use.value in cat["safety_critical_uses"]:
            return no, (f"Reuse for {e.intended_use.value.replace('_', ' ')} needs applicable standards and testing; "
                        "it is never decided from an AI estimate (README §4.4).")
        return ok, None
    if req == "no_visible_damage":
        d = _damaged(e)
        if d is True:
            return no, "Visible cracks, brittleness or deformation make the item unsuitable for reuse."
        if d is None:
            return insp, "Check the item for cracks, brittleness and deformation."
        return ok, None
    if req == "contamination_clean":
        if e.contamination == Contamination.clean:
            return ok, None
        if e.contamination == Contamination.unknown:
            return insp, "Contamination has not been checked."
        return no, "Direct reuse needs a clean item."
    if req == "contamination_removable":
        if e.contamination in (Contamination.clean, Contamination.light):
            return ok, None
        if e.contamination == Contamination.hazardous:
            return no, "Hazardous contamination rules out reuse."
        if e.contamination == Contamination.heavy:
            return insp, "Heavy contamination: confirm it can be cleaned before reuse."
        return insp, "Contamination has not been checked."
    if req == "contamination_not_hazardous":
        if e.contamination == Contamination.hazardous:
            return insp, "Hazardous contents need specialised handling before any recycling."
        if e.contamination == Contamination.unknown:
            return insp, "Contamination has not been checked."
        return ok, None
    if req in ("condition_low", "condition_low_or_moderate"):
        allowed = {Condition.low} if req == "condition_low" else {Condition.low, Condition.moderate}
        if cat["condition_cutpoints"].get("source") in (None, "TODO") and e.condition_provenance != "measured":
            return insp, "Degradation categories are not yet approved; inspect or test the material."
        if e.condition == Condition.unknown or e.condition_uncertain:
            return insp, "Degradation condition is uncertain; inspect or test before reuse."
        if e.condition in allowed:
            return ok, None
        return no, f"Degradation is {e.condition.value}, too high for this pathway."
    if req == "polymer_verified":
        if e.polymer is None:
            return insp, "Polymer unknown: identify or check the resin code first."
        if not polymer_is_verified(e):
            return insp, "Polymer identification is not confident: verify the resin code."
        return ok, None
    if req == "facility_confirmed":
        return Status.unavailable, "No facility for this treatment is confirmed locally yet."
    if req == "permitted_locally":
        if e.permitted_locally is None:
            return insp, "Check local regulations before energy recovery or disposal."
        return (ok, None) if e.permitted_locally else (no, "Not permitted locally.")
    raise ValueError(f"unknown requirement {req!r}")


_SEVERITY = [Status.feasible, Status.needs_inspection, Status.unavailable, Status.infeasible]


def assess(e: Evidence) -> Assessment:
    cat = catalogue()
    results = []
    for key, p in sorted(cat["pathways"].items(), key=lambda kv: kv[1]["order"]):
        status, reasons = Status.feasible, []
        if e.polymer is not None and e.polymer not in p["accepted_polymers"]:
            status, reasons = Status.infeasible, [f"{e.polymer} is not accepted by this pathway."]
        for req in p["requires"]:
            s, why = _check(req, e, cat)
            if _SEVERITY.index(s) > _SEVERITY.index(status):
                status = s
            if why:
                reasons.append(why)
        if p.get("last_resort") and status == Status.feasible:
            reasons.append("Last resort: use only if no higher-value pathway is suitable.")
        results.append(PathwayResult(pathway=key, label=p["label"], status=status, reasons=reasons))

    steps = []
    if not polymer_is_verified(e):
        steps.append("verify_material")
    if e.condition == Condition.unknown or e.condition_uncertain:
        steps.append("inspect_or_test_condition")
    if e.contamination == Contamination.unknown:
        steps.append("check_contamination")
    return Assessment(pathways=results, next_steps=steps)
