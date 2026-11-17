# Implementation Plan -- AI-Based Plastic Waste Degradation Prediction for Intelligent Recycling Route Optimization

Prototype name: **PlasticLens**. Project definition: [README.md](README.md).

The plan has two parts:

- **Part A (Sections 0–11), the foundation: complete.** Polymer identification
  model, Android app, cloud layer, backend and website. Its original
  specification is in [documentation/plasticlens_identification_spec.md](documentation/plasticlens_identification_spec.md).
- **Part B (Sections 12–18), the new scope from the README of 17 Nov 2026.**
  Degradation prediction, suitability assessment and recovery-route
  optimization, following the README's roadmap (§14, Phases 1–7).

Each section has a goal, tasks, deliverables, and a "Done when" checklist.
Sections are implemented **in order**; do not start a section until the
previous one's "Done when" list is complete (except where marked *parallel*).
**Section 12 is a decision gate:** nothing after it can be designed
responsibly until the degradation target and dataset are fixed.

## Project Decisions

| Decision          | Choice                                                                 |
| ----------------- | ---------------------------------------------------------------------- |
| Deliverables      | Android app **and** landing website; Part B adds a decision-support module |
| Team              | Solo developer                                                         |
| Training hardware | Local CPU (identification model trained in ~45 min); Colab notebook optional |
| App framework     | Flutter (one codebase, good camera/ONNX/Firebase plugins)              |
| Cloud             | Firebase free tier (Auth, Firestore, Storage, Hosting)                 |
| Identification    | Trained on-device model = core; vision LLM = optional extra (identification spec §4.2) |
| Degradation model | **Not chosen yet**: decided after the data review in Section 12 (identification spec §7.2) |
| Optimizer         | Transparent weighted MCDA first, compared with a fixed-rule baseline; LP/MILP only if justified (identification spec §7.4) |
| Decision engine   | Python package in `backend/` (FastAPI), so rules, model and optimizer are testable with pytest |

Because this is a solo project, sections are tagged by priority:

- **Core** -- must be finished; this is the minimum complete project.
- **Stretch** -- do only if core sections finish on time.

---

| #  | Section                                 | Week | Depends on | Priority | Status      |
| -: | --------------------------------------- | ---: | ---------- | -------- | ----------- |
|  0 | Project setup                           |    1 | --         | Core     | Done        |
|  1 | Flutter UI skeleton (static screens)    |    1 | 0          | Core     | Done        |
|  2 | Dataset preparation                     |    2 | 0          | Core     | Done        |
|  3 | Model training and evaluation           |    3 | 2          | Core     | Done |
|  4 | Model export and on-device inference    |    4 | 1, 3       | Core     | Done (phone latency pending) |
|  5 | Material database and result screen     |    4 | 4          | Core     | Done |
|  6 | Firebase auth and cloud data            |    5 | 1          | Core     | Code done; needs your Firebase setup |
|  7 | FastAPI backend and LLM enrichment      |    5 | 4, 6       | Stretch  | Code done; needs deploy |
|  8 | History, collection, sync               |    6 | 5, 6       | Core     | Done (verify on phone) |
|  9 | Gamification and learning               |    7 | 8          | Stretch (points + badges only are Core) | Done (FCM optional skipped) |
| 10 | Landing website                         |    7 | 5          | Core     | Done (deploy needs your login) |
| 11 | Testing, hardening, release, report     |    8 | all        | Core     | Mostly done; phone tests + video need you |
| 12 | Problem definition and data review (decision gate) | TBD | 11 | Core | Not started: needs you + supervisor |
| 13 | Degradation dataset preparation         |  TBD | 12         | Core     | Not started |
| 14 | Baseline degradation model              |  TBD | 13         | Core     | Not started |
| 15 | Pathway knowledge base and suitability rules | TBD | 12   | Core     | Not started (can run *parallel* with 13–14) |
| 16 | Route optimization engine               |  TBD | 14, 15     | Core (MILP is Stretch) | Not started |
| 17 | App and API integration                 |  TBD | 16         | Core     | Not started |
| 18 | Testing, final evaluation, repositioning |  TBD | all       | Core     | Not started |

Weeks for Part B are TBD: the README asks for the timeline to be fixed only after
the degradation and pathway data are confirmed (§14).

Sections 1 and 2 can run in parallel: while the model trains on Colab,
work on the Flutter UI. Section 10 can start any time after the result
screen exists (it needs a real screenshot).

If Section 7 is skipped, the Object field is typed by the user, and the
admin tasks are done in the Firebase Console.

---

## Section 0 -- Project Setup

**Goal:** A working repository and toolchain on your machine.

Tasks:

Project location: `C:\dev\plastic-lens` (kept outside OneDrive to avoid sync/lock problems).

- [x] Create the folder structure from identification spec §16.
- [x] `git init`, add `.gitignore` (Python, Flutter, `datasets/`, model weights, `.env`, `google-services.json`).
- [x] Create a GitHub repository and push (https://github.com/Jaavanika/plastic-lens).
- [x] Install Flutter SDK at `C:\src\flutter` (3.50.0, on user PATH).
- [x] Android cmdline-tools installed. SDK reached via junction `C:\Android\Sdk` (the real path has a space); `flutter config --android-sdk` and `ANDROID_HOME` point to it.
- [x] `flutter doctor --android-licenses` (all accepted; Android toolchain passes).
- [x] Emulator `PlasticLens_Pixel` (Pixel 7, Android 36).
- [x] Python venv at `C:\src\venvs\plasticlens` (outside the repo); packages from `ai_model/requirements.txt` (CPU torch for local tests; training runs on Colab).
- [x] `flutter create` → `android_app/` (package `com.plasticlens.plastic_lens`).
- [x] Create a Firebase project `plasticlens` (project ID `plasticlens-61083`, Spark plan).
- [x] App name and palette: **PlasticLens**, green + ocean blue. Logo: TBD in Section 1.

Activate the Python environment:

```powershell
C:\src\venvs\plasticlens\Scripts\Activate.ps1
```

Deliverables: repo on GitHub, `flutter doctor` passing (Visual Studio warning ignored, Windows desktop not targeted), Python env working.

Done when:

- [x] `flutter create` app runs on an emulator or phone (emulator, 2026-11-14).
- [x] `python -c "import torch, timm"` works.

---

## Section 1 -- Flutter UI Skeleton

**Goal:** All screens exist with fake (hard-coded) data so the app flow can be clicked through.

Tasks:

- [x] Set up Material 3 theme (colours, fonts). Uses the `material_ui` package (Flutter 3.50's template), with green `#2E7D4F` and ocean `#0B6E99`.
- [x] Bottom navigation: Home, Scan, Collection, History, Profile.
- [x] Home screen with Scan / Upload buttons and placeholder recent scans.
- [x] Scanner screen: camera preview (`camera` package) + gallery picker (`image_picker`), preview, retake/confirm.
- [x] Result screen matching the reference layout: image, card with Object / Plastic Presence / Plastic Type / Confidence, material panel below.
- [x] Material details, Collection, History, Profile screens with dummy data.
- [x] Camera and storage permission handling. Gallery uses Android's photo picker, which needs no storage permission.

Deliverables: clickable prototype APK.

Done when:

- [x] You can take/pick a photo and land on a result screen showing fake data (tested on the emulator).
- [x] All screens reachable; no crashes on rotation or permission denial (emulator; widget tests in `test/widget_test.dart`).

Notes: `compileSdk = 37` because `permission_handler` requires it.

---

## Section 2 -- Dataset Preparation *(parallel with Section 1)*

**Goal:** A clean, split, versioned dataset of 7 classes (6 polymers + non-plastic).

Tasks:

- [x] Download PlasticWaste-DB; check licence and annotation format (`preprocessing/download.py`; CC BY 4.0; YOLOv8 oriented boxes).
- [x] Write `preprocessing/inspect_data.py` (renamed from `inspect.py`, which would shadow Python's built-in `inspect` module): count images per class, find corrupt files, show samples.
- [x] Crop objects using bounding boxes if available (`preprocessing/prepare.py`).
- [x] Remove duplicates (perceptual hash).
- [x] Add a `non_plastic` class from TrashNet glass/paper/cardboard/metal (440 images).
- [ ] *(Optional)* Photograph 20–50 own items per class, labelled from the printed resin code.
- [x] Write `preprocessing/split.py`: grouped 70/15/15 split; save as `train/ val/ test/` folders or a CSV manifest.
- [x] Record dataset statistics in `documentation/model_card.md`.

Deliverables: `ai_model/datasets/processed/` + `splits.csv` + statistics table.

Done when:

- [x] Every image opens, every image has exactly one label (checked by `split.py`).
- [x] No duplicate image appears in two splits (groups + pHash check in `split.py`).

---

## Section 3 -- Model Training and Evaluation

**Goal:** A fine-tuned MobileNetV3-Large with documented metrics.

Tasks:

- [x] `training/dataset.py`: PyTorch `Dataset` + transforms (224×224, ImageNet normalisation, augmentation for train only).
- [x] `training/train.py`: load `timm` `mobilenetv3_large_100`, `num_classes=7`, weighted loss for imbalance.
- [x] Stage 1: train head only (frozen backbone). Stage 2: unfreeze and fine-tune with low LR.
- [x] Early stopping on validation F1; save best checkpoint.
- [x] ~~Train on Google Colab~~ Trained locally on the 12-core CPU instead (~95 s/epoch, no Google login needed). `training/colab_train.ipynb` is ready for GPU retraining.
- [x] `evaluation/evaluate.py`: accuracy, per-class precision/recall/F1, confusion matrix image.
- [x] Temperature scaling on validation set; report calibration (ECE): T = 2.733, val ECE 0.085 → 0.048, test ECE 0.034.
- [x] Pick High / Medium / Low confidence thresholds from validation data: High ≥ 0.70 (97.3 % accurate on test), Medium 0.30–0.70, Low < 0.30.
- [ ] *(Optional)* Compare with EfficientNet-B0 (cell ready in the Colab notebook).

Deliverables: `models/mobilenetv3_v1.pt`, `labels.json`, metrics report + confusion matrix in `model_card.md`.

Done when:

- [x] Test-set metrics are recorded: **accuracy 0.916, macro-F1 0.915** (best epoch 20 of 27), per-class table and confusion matrix in `documentation/model_card.md`.
- [x] Thresholds and temperature value are written down (`labels.json`, model card).

---

## Section 4 -- Model Export and On-Device Inference

**Goal:** The real model runs inside the Flutter app, offline.

Tasks:

- [x] `export/to_onnx.py`: fixed input `1×3×224×224`; temperature + softmax inside the graph; ONNX IR 8 for the app's ORT 1.15.
- [x] `export/verify_onnx.py`: 100 test images, max diff 4.0e-6, 0 top-1 mismatches; also writes Dart parity fixtures.
- [x] Copy `plasticlens.onnx` (16.8 MB) + `labels.json` to `android_app/assets/models/` (done by `to_onnx.py`).
- [x] Flutter `OnnxClassifier`: load model once, preprocess (EXIF rotate, Pillow-equivalent bilinear resize ported to Dart, normalise), run, return probabilities.
- [x] Apply threshold policy → `High / Medium / Low / NonPlastic` result state (unit-tested).
- [x] Run preprocessing in an isolate and inference via `runAsync`; progress indicator on the preview screen.
- [ ] Measure latency on a physical phone (shown in Profile → About after a scan). **Needs your phone.**
- [x] ~~Fallback to TFLite~~ Not needed: the plugin ships ARM-only libraries, so the official `onnxruntime-android:1.15.1` AAR is added for x86_64 emulators.

Deliverables: app that classifies a real photo offline.

Done when:

- [x] Same image gives the same top-1 class in Python and in the app: 7/7 on the emulator (`integration_test/classifier_parity_test.dart`), plus `test/preprocess_parity_test.dart`.
- [x] Works in airplane mode (integration test run with airplane mode on; ~115 ms per scan on the emulator).

---

## Section 5 -- Material Database and Result Screen

**Goal:** The result screen shows real material information for the predicted class.

Tasks:

- [x] Write `assets/data/plastic_types.json` for all 6 polymers (full name, resin code, properties, common items, recycling guidance, fact, eco tip), in original wording, with sources noted.
- [x] `MaterialRepository` that reads the bundled JSON and merges newer Firestore records.
- [x] Connect result screen to classifier output + material record.
- [x] Uncertain state UI ("Unable to identify reliably" + "Try another photo") and non-plastic state.
- [x] Editable Object name field and "Correct the material" action (also sends feedback).
- [x] Material Details screen with full information.

Deliverables: end-to-end offline scan → full result.

Done when:

- [x] Every class shows complete info; low-confidence and non-plastic states display correctly (widget tests + real scan on the emulator: LDPE 93.5 %, High).

---

## Section 6 -- Firebase Auth and Cloud Data

**Goal:** Users can sign in and their data lives in Firestore securely.

Tasks:

- [x] Add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`. Firebase is optional: without `google-services.json` the app runs local-only.
- [x] Email/password and Google sign-in; sign-out; first-launch sign-in screen with "continue without an account".
- [x] Create `users` document on first sign-in.
- [x] Upload `plastic_types` to Firestore (`backend/scripts/seed_firestore.py`). **Run it with your service-account key.**
- [x] Write Firestore + Storage security rules (identification spec §10); tested with the Firebase emulator (`firebase/`, `npm run test:rules`, 9 tests pass).
- [x] Account deletion (deletes scans, progress, profile, Storage images, then the auth user).
- [ ] Connect the real project: add `android/app/google-services.json`, enable Email/Password + Google providers, create Firestore + Storage, deploy rules. **Needs your Firebase login.**

Deliverables: login flow + deployed security rules.

Done when:

- [x] A user cannot read another user's data (verified with emulator test).

---

## Section 7 -- FastAPI Backend and LLM Enrichment

**Goal:** Optional online "second opinion" that fills the Object field and reads resin codes.

Tasks:

- [x] FastAPI app with `/api/health`.
- [x] Firebase ID-token verification dependency (`firebase-admin`).
- [x] `/api/identify/enrich`: accept image, call a vision LLM (Claude, `claude-opus-5-5`, structured JSON output) and validate strictly with Pydantic.
- [x] Keep the LLM API key in server environment variables only.
- [x] Per-user rate limit (30/hour), 5 MB image limit with byte-level type check, images never stored.
- [x] `/api/feedback` and admin endpoints (`/api/plastics`, `/api/admin/plastics/{code}`, `/api/admin/feedback`).
- [x] Pytest tests with the LLM mocked (21 pass).
- [ ] Deploy (Dockerfile ready for Cloud Run / Render). **Needs your cloud account + Anthropic API key.**
- [x] Flutter: if online and signed in, call enrich in parallel with the local result; merge (printed resin code beats the classifier, and both are shown).

Deliverables: deployed API + app showing object names when online.

Done when:

- [ ] App works identically offline (without enrichment) and online (with enrichment). *(offline path verified; online needs the deployed API)*
- [x] Invalid LLM output never crashes the app (server: strict validation tests; app: `test/enrich_test.dart`).

---

## Section 8 -- History, Collection, Sync

**Goal:** Scans are saved locally, synced to the cloud, and browsable.

Tasks:

- [x] Local storage (`sqflite`) for scans with `sync_status`.
- [x] Save scan from result screen (stable UUID scan IDs). Every scan goes to History; "Save" adds it to the collection.
- [x] Background sync to Firestore when online; optional photo backup to Storage (off by default); offline deletes kept as tombstones.
- [x] History screen: list, search, filter by material, swipe to delete.
- [x] Collection screen: saved items grouped by material, progress (x/6 polymers found).

Deliverables: persistent history + collection.

Done when:

- [x] Scans made offline appear in Firestore after reconnecting, with no duplicates (`test/sync_test.dart` against a fake Firestore; re-check on a phone once Firebase is connected).

---

## Section 9 -- Gamification and Learning

**Goal:** Points, badges, streaks, and learning content.

Tasks:

- [x] Achievement definitions (10 badges) in `assets/data/achievements.json`; uploaded to Firestore `achievements` by the seed script.
- [x] Points rules: reliable scan 10, verification 5, lesson 15, quiz 20; nothing for unreliable predictions.
- [x] Streak calculation (daily, scans or lessons; current + best).
- [x] Learning library: 4 recycling-basics lessons + one page per polymer + 8-question quiz.
- [ ] Notifications (FCM) for streak reminders (optional, skipped).

Deliverables: Profile shows points, badges, streak; learning section works.

Done when:

- [x] Achievements unlock correctly in a scripted test scenario (`test/progress_test.dart`).

---

## Section 10 -- Landing Website

**Goal:** A public one-page site similar in purpose to the reference page, with original content.

Tasks:

- [x] Hero: ocean gradient + SVG waves (own artwork, no licensed photo needed), phone mock-up with a real PlasticLens screenshot, headline, tagline, download button.
- [x] How it works (Snap → Identify → Recycle).
- [x] Features and supported plastics (6 resin-code cards).
- [x] Why it matters (facts with sources: UNEP, OECD 2022, Pew/SYSTEMIQ 2020).
- [x] Download section (GitHub Releases APK link), footer with privacy policy (`privacy.html`).
- [x] Responsive (phone, tablet, desktop), accessible, fast.
- [ ] Deploy to Firebase Hosting (`firebase.json` ready). **Needs `firebase login`.**

Deliverables: live URL.

Done when:

- [x] Lighthouse ≥ 90 for performance and accessibility: **100 / 100 / 100 / 100** (perf, a11y, best practices, SEO) on mobile and desktop; checked at a 360 px viewport.

---

## Section 11 -- Testing, Hardening, Release, Report

**Goal:** A release-quality APK and project documentation.

Tasks:

- [x] Run image test scenarios (identification spec §15.2): simulated on the test set with the shipped model + policy (`evaluation/scenarios.py`, model card §6). *Real-photo scenarios: do on your phone.*
- [x] Application tests (identification spec §15.3); `flutter test` widget tests: 32 Flutter + 1 on-device + 9 rules + 21 backend tests passing; matrix in `documentation/testing.md`.
- [ ] Test on at least 2 physical Android devices. **Needs your phones.**
- [x] Security review: rules (emulator tests), token checks (backend tests), no secrets in the release APK or git history (scanned).
- [x] Build signed release APK: arm64 50 MB, armv7 44 MB, x86_64 54 MB, universal 112 MB; keystore in `C:\dev\keys\` (**back it up**).
- [x] Finish `model_card.md`, `architecture.md`, `api_documentation.md`.
- [ ] Prepare capstone report and demo video. Report draft: `documentation/capstone_report.md`. **Demo video needs you.**

Deliverables: signed APK, documentation, report.

Done when:

- [ ] All boxes in identification spec §21 "Project Completion Criteria" are ticked.


---

# Part B -- Degradation Prediction and Recovery Route Optimization

Part B implements the scope added by the README of 17 Nov 2026 (§4.3–4.5, §7.2–7.4, §10.2–10.3, §12–13).
It follows the README's roadmap (§14, Phases 1–7). Sections 0–11 above
(Part A) are the completed foundation: the polymer identification model, the
app, the cloud layer and the website.

Ground rules from the README that apply to every Part B section:

- **Do not choose a degradation model before the dataset is inspected** (§7.2). Section 12 is a decision gate.
- **No invented degradation score.** The target, units, measurement method and prediction horizon must be documented (§4.3).
- **Separate evidence types.** Keep measured values, user-entered information and AI estimates apart everywhere (§4.1).
- **No safety-critical reuse from AI alone.** Food-contact, medical and structural reuse is never recommended on the strength of a prediction (§4.4).
- **Rules need sources.** Pathway thresholds come from standards, process specifications or expert review, never arbitrary numbers (§7.3, §16).
- **Claims need a baseline.** Any claim that the optimizer improves on simple sorting must be measured against a fixed-rule baseline (§10.3).
- **The test set stays held out.** It is not used for model or threshold selection (§9).

---

## Section 12 -- Problem Definition and Data Review *(decision gate; README Phase 1)*

**Goal:** Decide exactly what "degradation" means in this project, and which data will teach it, before any model is chosen.

Tasks:

- [ ] Survey candidate degradation data (README §9): weathering and accelerated-ageing studies with supplementary data, open materials-science repositories, and polymer degradation studies with before/after measurements. Log each source in `documentation/degradation_data_review.md` with: licence, polymers, exposure variables (UV dose or hours, temperature, humidity, outdoor duration), measured property, units, test method, sample count and study ID.
- [ ] Choose **one** target (§4.3), for example:
  - a measured property such as tensile-strength retention, elongation-at-break retention or carbonyl index (regression); or
  - a condition category (low / moderate / high) with a written, reproducible labelling rule (classification).
- [ ] Write down the units, measurement method and prediction horizon (e.g. "after N hours of exposure" or "current state").
- [ ] List the features that are **genuinely available in the app at prediction time** (polymer, approximate age, sunlight/heat/moisture exposure, visible cracks, discoloration, brittleness, deformation, contamination), separately from features that only exist in lab data. The model may only use the first group, or the gap must be bridged and documented.
- [ ] Decide the role of the photo for degradation:
  - none;
  - a user-confirmed visual checklist; or
  - an image condition classifier, only if labelled condition images exist.
- [ ] Define the pathway categories (README §4.4) and the evaluation criteria (§10.2–10.3) that Sections 14–16 will use.

Deliverables: `documentation/degradation_data_review.md`, a target-definition note, the feature list, and a go / narrow-scope decision.

Done when:

- [ ] Target variable, units, method and horizon are documented.
- [ ] At least one dataset with a verified licence and enough samples is chosen, **or** a narrowed target with defensible data is agreed (README §16, first risk).
- [ ] Your supervisor has agreed with the target definition. **Needs you.**

---

## Section 13 -- Degradation Dataset Preparation *(README Phase 2)*

**Goal:** A clean, documented, leakage-resistant degradation dataset.

Tasks:

- [ ] `ai_model/degradation/` scripts that build the dataset from the sources chosen in Section 12. When values are transcribed from papers, cite the source table on every row.
- [ ] Remove duplicates and invalid records; standardise units and category values.
- [ ] Keep study, specimen and sample identifiers. Do not merge incompatible experiments without documenting the differences in polymer grade, specimen preparation, exposure and protocol (README §9).
- [ ] Handle missing values transparently (report the missingness per feature; impute only with a stated method).
- [ ] Analyse the target distribution and class imbalance, per polymer and per exposure condition.
- [ ] Grouped train / validation / test split **by study or sample**, so that no experiment appears in two splits. The test set is held out.
- [ ] Write a dataset card in `documentation/model_card.md` (new "Degradation model" part): provenance, preprocessing and statistics.

Deliverables: processed dataset, split manifest, dataset card.

Done when:

- [ ] The pipeline is reproducible from raw sources with one command.
- [ ] No study or sample identifier crosses splits (automatic check).

---

## Section 14 -- Baseline Degradation Model *(README Phase 3)*

**Goal:** A measured, honest baseline for the chosen target.

Tasks:

- [ ] A naive baseline first: a per-polymer mean, or a polymer × exposure lookup.
- [ ] Tabular models: Random Forest and gradient boosting (XGBoost or LightGBM) (README §7.2). Use regression or classification to match the Section 12 target.
- [ ] Image or multi-input model **only** if Section 12 found labelled condition images.
- [ ] Metrics (README §10.2): MAE, RMSE and R² (regression) or accuracy, precision, recall, F1, confusion matrix and per-class recall (classification). Report them per polymer and per exposure condition where the data allows.
- [ ] Uncertainty: prediction intervals (quantile models or conformal prediction) or calibrated probabilities, so that the app can say "inspect / test" instead of forcing a route.
- [ ] Factor analysis (README objective 3): permutation importance or SHAP for UV, temperature, moisture, age, stress and contamination, where these are present.
- [ ] Choose how the model is served: in the backend (simplest), or exported (e.g. ONNX via `skl2onnx`) for offline use.

Deliverables: a trained model, a metrics report, an uncertainty method, and the degradation section of the model card.

Done when:

- [ ] Held-out test results are recorded against the naive baseline, even if the model does not beat it.
- [ ] Uncertainty is quantified and its limitations documented.

---

## Section 15 -- Pathway Knowledge Base and Suitability Rules *(README Phase 4)*

**Goal:** For any assessed item, a sourced list of which recovery pathways are feasible, and why the others are not.

Tasks:

- [ ] Pathway catalogue (`backend/app/decision/pathways.yaml`): direct reuse, cleaning and preparation for reuse, mechanical recycling, specialised recycling or treatment, energy recovery or disposal. Each entry has the README §7.3 fields: accepted polymers, permitted condition range or property requirements, contamination limits, required pre-processing, facility, expected output and quality, and cost/energy data where available. Every value carries a **source citation**.
- [ ] Local facility list (your city or campus): accepted materials and processes. **Needs you** to collect it (phone calls or council websites).
- [ ] Feasibility checker: input (polymer + verification status, predicted condition + uncertainty, contamination, intended next use); output: feasible / infeasible / needs inspection, each with reasons.
- [ ] Hard exclusions:
  - [ ] Food-contact, medical, structural and other safety-critical reuse is never recommended from AI output alone (README §4.4).
  - [ ] An unverified polymer leads to a "verify material first" step.
  - [ ] High degradation uncertainty leads to an "inspect or test" step instead of a forced route (README §16).
  - [ ] Pathways without an available facility are marked unavailable (README §16).
- [ ] A unit test for every rule, plus a randomised test showing that no unsafe pathway can ever be returned as feasible.

Deliverables: the pathway catalogue with sources, the checker, and tests.

Done when:

- [ ] Every rule cites a source.
- [ ] Tests prove every exclusion holds.

---

## Section 16 -- Route Optimization Engine *(README Phase 5)*

**Goal:** Rank the feasible pathways transparently, and show what that gains over a fixed rule.

Tasks:

- [ ] **Fixed-rule baseline**: polymer → a default pathway (today's practice).
- [ ] **Weighted multi-criteria decision analysis** over the feasible pathways (weighted sum, plus TOPSIS for comparison), with configurable weights for recovery, material quality, cost, energy and disposal avoided (README §7.4).
- [ ] Uncertainty-aware scoring: compute the expected score over the predicted condition distribution, or fall back to inspection when the ranking flips within the uncertainty.
- [ ] An explanation object: recommended pathway, alternatives, the deciding factors, and the reason each excluded pathway was excluded.
- [ ] *(Stretch)* LP / MILP batch allocation with facility capacities (OR-Tools), only if the data justifies it.
- [ ] API: `POST /api/assess` (evidence → condition estimate + recommendation + explanation).
- [ ] Evaluation (README §10.3) on a scenario set:
  - constraint violations, which must be **0**;
  - agreement with expert-labelled pathways (a small set labelled by you or your supervisor; **needs you**);
  - sensitivity to the weights and to degradation uncertainty;
  - share of material sent to reuse or recycling versus disposal, compared with the baseline.

Deliverables: the optimizer, the baseline, the evaluation report and the API endpoint.

Done when:

- [ ] Zero feasibility violations on the scenario set.
- [ ] Optimizer versus fixed-rule baseline is reported, with a sensitivity analysis.
- [ ] No environmental or economic claim is made without a measured baseline.

---

## Section 17 -- App and API Integration *(README Phase 6)*

**Goal:** The README §12 modules in the PlasticLens app.

Tasks:

- [ ] **Add waste item or batch** form, starting from a scan or entered by hand. Fields:
  - polymer, with verification status;
  - age and usage history;
  - exposure: sunlight, heat, moisture, outdoor storage;
  - visible condition checklist: cracks, discoloration, brittleness, deformation, surface damage;
  - contamination;
  - optional measured properties.
- [ ] A **provenance flag on every value** (measured / user-entered / AI-estimated), stored, synced and shown (README §4.1).
- [ ] **Degradation assessment** screen: the target value or category, units, uncertainty and key factors.
- [ ] **Recommendation / optimization result** screen, following the README §13 layout: next step, alternatives with status, reasons, uncertainty, and the "not a laboratory certification" note.
- [ ] Objective-weight settings (simple presets plus advanced sliders).
- [ ] **Dashboard** and **History** extended from scans to assessments and decisions.
- [ ] **Admin / data management**: pathway rules, facilities and outcome records (Firestore collections and API), with security rules and emulator tests.
- [ ] **Outcome recording** (README §5 step 9): what actually happened to an item, with a review status. Only reviewed outcomes may feed retraining (README §16).
- [ ] Decide and document what works offline (identification, the checklist and possibly the rule check) versus what needs the API.

Deliverables: the new screens and endpoints, with tests.

Done when:

- [ ] Scan → evidence → assessment → recommendation → outcome works end to end on the emulator.
- [ ] Widget tests and security-rule tests cover the new data.

---

## Section 18 -- Testing, Final Evaluation and Repositioning *(README Phase 7)*

**Goal:** A validated prototype and documentation that match the new scope.

Tasks:

- [ ] Test missing, noisy and uncertain inputs, and infeasible pathway scenarios (README §14 Phase 7).
- [ ] Final held-out evaluation of the degradation model, and the optimizer evaluation.
- [ ] Update `model_card.md` (degradation part), `architecture.md`, `api_documentation.md` and `testing.md`.
- [ ] Rewrite `capstone_report.md` for the new title and abstract (README §18), and present unimplemented parts as proposed architecture (README §17).
- [ ] Reposition the website copy (identification → assessment and recommendation).
- [ ] Physical-device tests (carried over from Section 11). **Needs your phones.**

Done when:

- [ ] All README §23 completion criteria are ticked.

---

## Your remaining steps for Part A (cannot be done without your accounts or devices)

1. **Back up** `C:\dev\keys\` (keystore + `key.properties.backup`) somewhere safe, e.g. a USB drive or a password manager. Losing it means you can never update the app.
2. **GitHub release**: github.com/Jaavanika/plastic-lens → Releases → *Draft a new release* → tag `v1.0.0` → attach the APKs from `C:\dev\plastic-lens-release\` → paste `RELEASE_NOTES.md` → Publish. The website's download button points here.
3. **Firebase**: Console → Add app → Android, package `com.plasticlens.plastic_lens` → download `google-services.json` into `android_app/android/app/`. Then Authentication → enable **Email/Password** and **Google**; create a **Firestore** database and **Storage**. For Google sign-in, add the debug and release SHA-1 fingerprints (see `RELEASE_NOTES.md`).
4. In a terminal: `cd firebase` → `npx firebase login` → `npm run deploy:rules` → `npm run deploy:hosting` (the website goes live at https://plasticlens-61083.web.app).
5. *(Optional, Section 7)*: deploy `backend/` to Cloud Run or Render with your `ANTHROPIC_API_KEY`, run `backend/scripts/seed_firestore.py`, then rebuild the APK with `--dart-define=ENRICH_URL=<url>`.
6. **Phones**: install `app-arm64-v8a-release.apk` on 2 phones and work through the checklist at the end of `documentation/testing.md`.
7. Record the **demo video** and fill in the name, college and supervisor fields in `capstone_report.md`.
