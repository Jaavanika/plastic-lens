"""Suitability rules (PLAN Section 15). The exhaustive test enumerates every
combination of the discrete evidence fields to prove the hard exclusions."""

from __future__ import annotations

import itertools

from app.decision.suitability import (
    Condition, Contamination, Evidence, IntendedUse, Status, assess, catalogue,
)

REUSE = {"direct_reuse", "prepare_for_reuse"}


def by_key(a):
    return {p.pathway: p for p in a.pathways}


def good_item(**kw):
    base = dict(polymer="HDPE", polymer_provenance="user_entered", condition=Condition.low,
                condition_provenance="measured", condition_uncertain=False, contamination=Contamination.clean,
                visible_cracks=False, brittleness=False, deformation=False)
    return Evidence(**(base | kw))


def test_every_pathway_has_a_source():
    for key, p in catalogue()["pathways"].items():
        assert p["source"], key


def test_clean_undamaged_measured_low_degradation_item_can_be_reused():
    r = by_key(assess(good_item()))
    assert r["direct_reuse"].status == Status.feasible
    assert r["prepare_for_reuse"].status == Status.feasible
    assert r["mechanical_recycling"].status == Status.feasible


def test_safety_critical_reuse_is_excluded():
    for use in ("food_contact", "medical", "structural", "child_product"):
        r = by_key(assess(good_item(intended_use=IntendedUse(use))))
        assert r["direct_reuse"].status == Status.infeasible
        assert r["prepare_for_reuse"].status == Status.infeasible
        assert "README §4.4" in r["direct_reuse"].reasons[0]


def test_visible_damage_excludes_reuse_but_not_recycling():
    r = by_key(assess(good_item(visible_cracks=True)))
    assert r["direct_reuse"].status == Status.infeasible
    assert r["mechanical_recycling"].status == Status.feasible


def test_unverified_ai_polymer_requires_verification():
    a = assess(good_item(polymer_provenance="ai_estimated", polymer_confidence=0.55))
    assert "verify_material" in a.next_steps
    assert by_key(a)["mechanical_recycling"].status == Status.needs_inspection
    a = assess(good_item(polymer_provenance="ai_estimated", polymer_confidence=0.93))
    assert "verify_material" not in a.next_steps


def test_ai_estimated_condition_cannot_unlock_reuse_before_cutpoints_are_approved():
    r = by_key(assess(good_item(condition_provenance="ai_estimated")))
    assert r["direct_reuse"].status == Status.needs_inspection


def test_uncertain_condition_asks_for_inspection():
    a = assess(good_item(condition_uncertain=True))
    assert by_key(a)["direct_reuse"].status == Status.needs_inspection
    assert "inspect_or_test_condition" in a.next_steps


def test_hazardous_contamination():
    r = by_key(assess(good_item(contamination=Contamination.hazardous)))
    assert r["direct_reuse"].status == Status.infeasible
    assert r["prepare_for_reuse"].status == Status.infeasible
    assert r["mechanical_recycling"].status == Status.needs_inspection


def test_no_facility_means_unavailable_and_disposal_needs_permission():
    r = by_key(assess(good_item()))
    assert r["specialised_treatment"].status == Status.unavailable
    assert r["energy_recovery_or_disposal"].status == Status.needs_inspection
    r = by_key(assess(good_item(permitted_locally=True)))
    assert r["energy_recovery_or_disposal"].status == Status.feasible
    assert any("Last resort" in s for s in r["energy_recovery_or_disposal"].reasons)


def test_every_non_feasible_result_has_a_reason():
    for p in assess(Evidence()).pathways:
        assert p.status == Status.feasible or p.reasons


def test_exhaustive_hard_exclusions():
    """No combination of evidence may ever make reuse feasible for a
    safety-critical use, a damaged item, hazardous contents, or high degradation."""
    tri = [True, False, None]
    space = itertools.product(
        [None, "PET", "HDPE", "PVC", "LDPE", "PP", "PS"],
        ["measured", "user_entered", "ai_estimated", "unknown"],
        list(Condition),
        ["measured", "user_entered", "ai_estimated", "unknown"],
        [True, False],
        list(Contamination),
        tri, tri,
        list(IntendedUse),
    )
    checked = 0
    for poly, pprov, cond, cprov, unc, cont, cracks, brittle, use in space:
        e = Evidence(polymer=poly, polymer_provenance=pprov, polymer_confidence=0.9, condition=cond,
                     condition_provenance=cprov, condition_uncertain=unc, contamination=cont,
                     visible_cracks=cracks, brittleness=brittle, deformation=False, intended_use=use)
        r = by_key(assess(e))
        reuse_ok = any(r[k].status == Status.feasible for k in REUSE)
        if reuse_ok:
            assert use.value not in ("food_contact", "medical", "structural", "child_product")
            assert cracks is False and brittle is False
            assert cont in (Contamination.clean, Contamination.light)
            assert cond in (Condition.low, Condition.moderate) and not unc
            assert cprov == "measured"  # cut-points not yet approved
        checked += 1
    assert checked > 10_000
