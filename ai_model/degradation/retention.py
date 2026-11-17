"""Elongation-at-break retention model (PLAN Section 12, Option A; provisional).

ER(D) = eps_b(D) / eps_b(0) as a function of cumulative outdoor UV dose D
(MJ/m^2), from measured, cited retention curves in sources.yaml.

Design rules (README §4.3, §16):
- Only polymers with a cited curve get an estimate; others return
  "insufficient_evidence" rather than a guess.
- With one source per polymer the spread due to unknown additives cannot be
  quantified, so the result says so instead of inventing an interval. With
  two or more sources the band is the min-max across source curves.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path

import yaml

REGISTRY = Path(__file__).with_name("sources.yaml")


@dataclass(frozen=True)
class Curve:
    source: str
    polymer: str
    p_max: float
    p_min: float
    k: float
    d0: float

    def __call__(self, dose: float) -> float:
        """Logistic retention (S1 Eq. 4): decreases from ~Pmax to Pmin."""
        return self.p_min + (self.p_max - self.p_min) / (1.0 + math.exp(self.k * (dose - self.d0)))

    def dose_at(self, retention: float) -> float | None:
        """Dose at which retention falls to `retention`; None if never reached."""
        if not self.p_min < retention < self.p_max:
            return None
        return self.d0 + math.log((self.p_max - self.p_min) / (retention - self.p_min) - 1.0) / self.k


@dataclass
class RetentionEstimate:
    polymer: str
    dose_mj_m2: float | None
    status: str  # ok | insufficient_evidence | unknown_dose
    estimate: float | None = None
    low: float | None = None
    high: float | None = None
    uncertainty_quantified: bool = False
    sources: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def load_registry(path: Path = REGISTRY) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def load_curves(registry: dict | None = None) -> dict[str, list[Curve]]:
    registry = registry or load_registry()
    curves: dict[str, list[Curve]] = {}
    for sid, src in registry["sources"].items():
        for polymer, c in (src.get("curves") or {}).items():
            curves.setdefault(polymer, []).append(
                Curve(sid, polymer, c["Pmax"], c["Pmin"], c["k"], c["D0"]))
    return curves


def dose_from_exposure(years_outdoors: float | None, region: str | None, registry: dict | None = None) -> float | None:
    """Cumulative UV dose from time outdoors and a sourced regional annual UV."""
    if years_outdoors is None:
        return None
    if years_outdoors <= 0:
        return 0.0
    registry = registry or load_registry()
    r = (registry.get("regions") or {}).get(region or "")
    return None if r is None else years_outdoors * r["annual_uv_mj_m2"]


def estimate(polymer: str, dose_mj_m2: float | None, curves: dict[str, list[Curve]] | None = None) -> RetentionEstimate:
    curves = curves if curves is not None else load_curves()
    available = curves.get(polymer, [])
    if not available:
        return RetentionEstimate(polymer, dose_mj_m2, "insufficient_evidence",
                                 notes=[f"No cited retention curve for {polymer}; inspect or test instead."])
    if dose_mj_m2 is None:
        return RetentionEstimate(polymer, None, "unknown_dose", sources=[c.source for c in available],
                                 notes=["Exposure (time outdoors and region) is needed to estimate retention."])

    values = [c(dose_mj_m2) for c in available]
    max_dose = max(_max_dose(c.source) for c in available)
    notes = []
    if dose_mj_m2 > max_dose:
        notes.append(f"Dose {dose_mj_m2:.0f} MJ/m² is beyond the measured range (≤ {max_dose:.0f}); extrapolated.")
    if len(values) == 1:
        notes.append("Single source: variation from unknown additives (UV stabilisers) is not quantified.")
        return RetentionEstimate(polymer, dose_mj_m2, "ok", estimate=values[0], sources=[available[0].source], notes=notes)
    return RetentionEstimate(polymer, dose_mj_m2, "ok", estimate=sorted(values)[len(values) // 2],
                             low=min(values), high=max(values), uncertainty_quantified=True,
                             sources=[c.source for c in available], notes=notes)


def _max_dose(source_id: str) -> float:
    src = load_registry()["sources"][source_id]
    return float(src.get("dose_range_mj_m2", [0, math.inf])[1])
