# Degradation data review (PLAN Section 12, decision gate)

Status: **draft for supervisor review**, 17 Nov 2026.
Purpose: before any degradation model is chosen (README §7.2), decide what
"degradation" means in this project, which measured data supports it, and
which inputs the app can genuinely collect.

---

## 1. What the README requires

- The target is defined by the data: a condition category with ground truth, or
  a measured property such as tensile-strength retention or elongation at break (§4.3).
- No universal degradation score without labels. The target, units, method and horizon must be documented (§4.3).
- A polymer-labelled image dataset is **not** enough (§9).
- Measured, user-entered and AI-estimated values are kept separate (§4.1).
- Uncertainty is shown, and inspection or testing is requested when the evidence is weak (§16).

## 2. What the search found (17 Nov 2026)

No public dataset links the **observable evidence about an individual waste
item** (polymer, approximate age, sun exposure, visible damage) to a
**measured degradation outcome**. What exists:

| # | Source | Polymers | Exposure | Measured target | Data form | Licence | Usefulness |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | Kim, Lee, Kim, Choi. *Analysis of Mechanical Property Degradation of Outdoor Weather-Exposed Polymers.* Polymers 14(2):357, 2022. [PMC8782030](https://pmc.ncbi.nlm.nih.gov/articles/PMC8782030/) | PC, **PP**, PBT, **HDPE** | 4 years outdoors, Seosan (Korea, Köppen Cfa), 0–1020 MJ/m² UV | **Fracture-strain (elongation at break) retention** vs cumulative UV dose; tensile yield strength unchanged | Fitted logistic retention functions (Table 5); per-step points only in figures | CC BY 4.0 | **High**: measured, documented method (ISO 527 / ASTM D638, 5 specimens per step), fitted parameters published |
| S2 | Chamas et al. *Degradation Rates of Plastics in the Environment.* ACS Sustainable Chem. Eng. 2020, doi:10.1021/acssuschemeng.9b06635 | Many common plastics | Marine, land, landfill etc. (literature) | Specific surface degradation rate (µm/year) | Literature compilation | Article CC BY (SI to be checked) | Medium: polymer × environment *rates*, very wide spread, not item condition |
| S3 | Min et al. *Ranking environmental degradation trends of plastic marine debris.* Nature Communications 11:727, 2020 | Many | Marine | Fast / medium / slow degradation class | Literature-derived, partly extrapolated | CC BY | Low to medium: population-level ranking |
| S4 | Recent study on polymer density and thermal mobility as predictors of degradation rates ([PubMed 43038819](https://pubmed.ncbi.nlm.nih.gov/43038819)) | Many | Air and water | Surface degradation rate | Literature compilation | **Not verified** | Medium: confirms the limiting factor is comparability of literature data, not model choice |
| S5 | Single-polymer studies found in the search (LDPE/LLDPE films, PP with UV stabilisers [PMC7178429](https://pmc.ncbi.nlm.nih.gov/articles/PMC7178429/), A-PET films, PVC roofing, U-PVC in [NIST TN 2304](https://nvlpubs.nist.gov/nistpubs/TechnicalNotes/NIST.TN.2304.pdf)) | LDPE, PP, PET, PVC | Natural or accelerated | Elongation at break, tensile strength | Tables or figures; formulations differ | Mixed; check each | Medium: adds polymers, but each study uses a different grade, specimen and protocol |
| S6 | Ranking the accelerated weathering of plastic polymers. Environ. Sci.: Processes & Impacts 2023 ([open copy](https://eprints.whiterose.ac.uk/id/eprint/204721/1/d3em00295k.pdf)) | PP, LDPE, PS, PET, PLA, PEB | 41 days, chamber | Mass loss, carbonyl index | Figures/tables | Check | Medium: relative ranking PP ≫ LDPE > PS > PET under the same conditions |

### Key scientific finding

**Additives dominate the degradation rate.** Reported for PE: unstabilised
film loses 50 % of its elongation at break within months outdoors, while
HALS-stabilised film takes years. For LDPE/LLDPE films, 50 % tensile-strength
retention was reached at 30–110 days unstabilised, 205 days with one HALS,
and 590 days with HALS plus a UV absorber. A waste item's additive package is
unknown, so **any prediction from polymer + exposure must be a range, not a
point value**. This supports the README's insistence on uncertainty and on
"inspect / test" outcomes.

### Gaps

- **PET, PS, PVC:** no outdoor retention curve comparable to S1 was found yet. For these, the system must be able to say "insufficient evidence".
- **Photographs:** no labelled dataset links photos of plastic items to measured degradation. An image-based degradation model is **not** supported.
- **Local UV climate:** turning "months outdoors" into cumulative UV dose needs annual UV irradiance for the user's region. S1 gives 283.5 MJ/m²/year for its site. Values for the project's region still need a citable source.

## 3. Candidate targets

| Option | Target | Inputs at prediction time | Data | Pros | Cons |
| --- | --- | --- | --- | --- | --- |
| **A (recommended)** | **Elongation-at-break retention ER(D) = ε_b(D)/ε_b(0)**, per polymer, as a function of cumulative outdoor UV dose D (MJ/m²), with an **uncertainty band** spanning stabilised and unstabilised material | Polymer (identified or verified), estimated outdoor exposure time, region (→ D) | S1 curves (PP, HDPE) + curves digitised from S5-type studies, each row cited | Measured, standard engineering indicator of embrittlement; units and method documented; honest range | Few polymers; between-study variation is large; digitising figures takes manual effort |
| B | Surface degradation rate (µm/year) per polymer × environment | Polymer, environment, years | S2/S4 | Covers more polymers | Population average; does not describe a single item's condition; very wide spread |
| C | Condition category (low / moderate / high) | Visible-condition checklist + exposure | **None**: needs our own labelled data | Matches README §13 wording | Without ground truth this would be an invented score (§4.3). Only possible with Option D |
| D | Own measurements | Items collected on campus; exposure history recorded; elongation measured on a tensile tester (or carbonyl index on FTIR, if the lab has one) | Created by the project | Real item-level ground truth; strongest capstone contribution | Needs lab access and time; small sample |

### Recommendation

1. **Primary target: Option A.** Elongation-at-break retention against
   cumulative UV dose, with prediction intervals.
   - **Units:** dimensionless ratio, 0–1.
   - **Method:** tensile test (ISO 527 / ASTM D638), as reported by each source.
   - **Horizon:** the *current* state given the exposure so far, plus an optional projection (e.g. "at the current rate, 50 % retention after N more months").
2. **Condition category derived from ER** (high / moderate / low degradation)
   using cut-points agreed with the supervisor. The 50 % point (D50 in S1) is a
   natural anchor because S1 reports it. The cut-points live in a config file,
   cited, never hard-coded.
3. **Visible damage is evidence, not a model input.** Cracks, chalking,
   brittleness and discoloration are recorded as *user-entered* observations
   and handled by the suitability rules (Section 15). For example, visible
   cracking excludes direct reuse. They never feed the ML model, because no
   labelled data links them to ER.
4. **Photo = identification only** (§4.2). There is no image-based degradation model.
5. **If lab access exists, add Option D** as validation data for Option A.
   That would be the strongest scientific result of the project.

## 4. Features available in the app

| Feature | Available at prediction time? | Provenance | Used by |
| --- | --- | --- | --- |
| Polymer | Yes | AI-estimated, or user-verified (resin code) | Model + rules |
| Outdoor exposure duration | Approximate | User-entered | Model (→ UV dose) |
| Region / climate | Yes | User-entered | Model (→ annual UV) |
| Indoor-only use | Yes | User-entered | Model (dose ≈ 0) |
| Stabiliser / additive content | **No** | – | Uncertainty band |
| Specimen thickness | Rarely | User-entered (optional) | Not used in v1 |
| Visible cracks, chalking, discoloration, brittleness, deformation | Yes | User-entered | Rules only |
| Contamination | Yes | User-entered | Rules only |
| Measured ER, tensile data | Only with lab access | Measured | Overrides the model when present |

## 5. Pathway categories (input to Sections 15–16)

As in README §4.4:
1. direct reuse;
2. cleaning and preparation for reuse;
3. mechanical recycling;
4. specialised recycling or treatment;
5. energy recovery or disposal (only where permitted and higher-value recovery is unsuitable).

Two additional *process* outcomes:

- **verify material**: the polymer is unverified or low-confidence;
- **inspect / test**: degradation uncertainty is too high to decide.

## 6. Decisions needed from the supervisor

- [ ] Accept Option A as the degradation target (or choose B, C+D, or D).
- [ ] Agree the ER cut-points for the condition categories.
- [ ] Is a tensile tester or FTIR available for Option D validation?
- [ ] Which region's UV climate should be used (and a citable source for annual UV)?

## 7. Provisional work started (reversible if the decision changes)

- `ai_model/degradation/`: source registry and the curve library for S1 (PP, HDPE), with tests.
- `backend/app/decision/`: pathway catalogue skeleton, hard safety exclusions and the feasibility checker. These do not depend on the degradation target.
