"""Checks that the transcribed S1 parameters reproduce the paper's own numbers.

    python -m pytest ai_model/degradation
"""

import math

import pytest

from retention import dose_from_exposure, estimate, load_curves, load_registry


@pytest.fixture(scope="module")
def curves():
    return load_curves()


@pytest.mark.parametrize("polymer", ["PP", "HDPE", "PC", "PBT"])
def test_curves_reproduce_published_d50(curves, polymer):
    """S1 Table 5 lists D50% per polymer; our function must hit it."""
    published = load_registry()["sources"]["S1"]["curves"][polymer]["D50"]
    assert curves[polymer][0].dose_at(0.5) == pytest.approx(published, rel=2e-3)


def test_retention_starts_near_one_and_decreases(curves):
    for polymer in ("PP", "HDPE"):
        c = curves[polymer][0]
        assert c(0) > 0.95
        values = [c(d) for d in range(0, 1100, 60)]
        assert all(a >= b for a, b in zip(values, values[1:]))
        assert values[-1] >= c.p_min


def test_unknown_polymer_gets_no_guess():
    r = estimate("PET", 300)
    assert r.status == "insufficient_evidence" and r.estimate is None


def test_unknown_exposure_gets_no_guess():
    r = estimate("PP", None)
    assert r.status == "unknown_dose" and r.estimate is None


def test_single_source_flags_unquantified_uncertainty():
    r = estimate("HDPE", 406.344)
    assert r.status == "ok" and r.estimate == pytest.approx(0.5, abs=1e-3)
    assert not r.uncertainty_quantified
    assert any("not quantified" in n for n in r.notes)


def test_extrapolation_is_flagged():
    assert any("beyond the measured range" in n for n in estimate("PP", 1500).notes)


def test_dose_from_exposure_requires_sourced_region():
    assert dose_from_exposure(2, "seosan_kr") == pytest.approx(567.0)
    assert dose_from_exposure(2, "nowhere") is None
    assert dose_from_exposure(0, None) == 0.0
    assert dose_from_exposure(None, "seosan_kr") is None


def test_every_curve_has_a_licensed_source():
    reg = load_registry()
    for sid, src in reg["sources"].items():
        assert src.get("licence") and src.get("doi") or src.get("url"), sid
    for region in reg["regions"].values():
        assert region["source"] in reg["sources"]
