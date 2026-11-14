# PlasticLens -- Implementation Plan

This plan splits the project into sections that are implemented **one at a
time, in order**. Each section has a goal, tasks, deliverables, and a
"Done when" checklist. Do not start a section until the previous one's
"Done when" list is complete (except where marked *parallel*).

Full technical details are in
[README.md](README.md).

## Project Decisions

| Decision          | Choice                                                                 |
| ----------------- | ---------------------------------------------------------------------- |
| Deliverables      | Android app **and** landing website                                    |
| Team              | Solo developer                                                         |
| Training hardware | Google Colab (free GPU); local CPU only for quick tests                |
| App framework     | Flutter (one codebase, good camera/ONNX/Firebase plugins)              |
| Cloud             | Firebase free tier (Auth, Firestore, Storage, Hosting)                 |
| Identification    | Trained on-device model = core; vision LLM = optional extra            |

Because this is a solo project, sections are tagged by priority:

- **Core** -- must be finished; this is the minimum complete project.
- **Stretch** -- do only if core sections finish on time.

---

| #  | Section                                 | Week | Depends on | Priority | Status      |
| -: | --------------------------------------- | ---: | ---------- | -------- | ----------- |
|  0 | Project setup                           |    1 | --         | Core     | In progress |
|  1 | Flutter UI skeleton (static screens)    |    1 | 0          | Core     | Not started |
|  2 | Dataset preparation                     |    2 | 0          | Core     | Not started |
|  3 | Model training and evaluation           |    3 | 2          | Core     | Not started |
|  4 | Model export and on-device inference    |    4 | 1, 3       | Core     | Not started |
|  5 | Material database and result screen     |    4 | 4          | Core     | Not started |
|  6 | Firebase auth and cloud data            |    5 | 1          | Core     | Not started |
|  7 | FastAPI backend and LLM enrichment      |    5 | 4, 6       | Stretch  | Not started |
|  8 | History, collection, sync               |    6 | 5, 6       | Core     | Not started |
|  9 | Gamification and learning               |    7 | 8          | Stretch (points + badges only are Core) | Not started |
| 10 | Landing website                         |    7 | 5          | Core     | Not started |
| 11 | Testing, hardening, release, report     |    8 | all        | Core     | Not started |

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

- [x] Create the folder structure from README §16.
- [x] `git init`, add `.gitignore` (Python, Flutter, `datasets/`, model weights, `.env`, `google-services.json`).
- [ ] Create a GitHub repository and push.
- [x] Install Flutter SDK at `C:\src\flutter` (3.50.0, on user PATH).
- [x] Android cmdline-tools installed. SDK reached via junction `C:\Android\Sdk` (the real path has a space); `flutter config --android-sdk` and `ANDROID_HOME` point to it.
- [ ] `flutter doctor --android-licenses` (accept remaining licenses; you must do this yourself).
- [x] Emulator `PlasticLens_Pixel` (Pixel 7, Android 36).
- [x] Python venv at `C:\src\venvs\plasticlens` (outside the repo); packages from `ai_model/requirements.txt` (CPU torch for local tests; training runs on Colab).
- [x] `flutter create` → `android_app/` (package `com.plasticlens.plastic_lens`).
- [ ] Create a Firebase project `plasticlens`.
- [x] App name and palette: **PlasticLens**, green + ocean blue. Logo: TBD in Section 1.

Activate the Python environment:

```powershell
C:\src\venvs\plasticlens\Scripts\Activate.ps1
```

Deliverables: repo on GitHub, `flutter doctor` passing, Python env working.

Done when:

- [x] `flutter create` app runs on an emulator or phone (emulator, 2026-11-14).
- [x] `python -c "import torch, timm"` works.

---

## Section 1 -- Flutter UI Skeleton

**Goal:** All screens exist with fake (hard-coded) data so the app flow can be clicked through.

Tasks:

- [ ] Set up Material 3 theme (colours, fonts).
- [ ] Bottom navigation: Home, Scan, Collection, History, Profile.
- [ ] Home screen with Scan / Upload buttons and placeholder recent scans.
- [ ] Scanner screen: camera preview (`camera` package) + gallery picker (`image_picker`), preview, retake/confirm.
- [ ] Result screen matching the reference layout: image, card with Object / Plastic Presence / Plastic Type / Confidence, material panel below.
- [ ] Material details, Collection, History, Profile screens with dummy data.
- [ ] Camera and storage permission handling.

Deliverables: clickable prototype APK.

Done when:

- [ ] You can take/pick a photo and land on a result screen showing fake data.
- [ ] All screens reachable; no crashes on rotation or permission denial.

---

## Section 2 -- Dataset Preparation *(parallel with Section 1)*

**Goal:** A clean, split, versioned dataset of 7 classes (6 polymers + non-plastic).

Tasks:

- [ ] Download PlasticWaste-DB; check licence and annotation format.
- [ ] Write `preprocessing/inspect.py`: count images per class, find corrupt files, show samples.
- [ ] Crop objects using bounding boxes if available.
- [ ] Remove duplicates (perceptual hash).
- [ ] Add a `non_plastic` class from TrashNet glass/paper/cardboard/metal (~400 images).
- [ ] *(Optional)* Photograph 20–50 own items per class, labelled from the printed resin code.
- [ ] Write `preprocessing/split.py`: grouped 70/15/15 split; save as `train/ val/ test/` folders or a CSV manifest.
- [ ] Record dataset statistics in `documentation/model_card.md`.

Deliverables: `ai_model/datasets/processed/` + `splits.csv` + statistics table.

Done when:

- [ ] Every image opens, every image has exactly one label.
- [ ] No duplicate image appears in two splits.

---

## Section 3 -- Model Training and Evaluation

**Goal:** A fine-tuned MobileNetV3-Large with documented metrics.

Tasks:

- [ ] `training/dataset.py`: PyTorch `Dataset` + transforms (224×224, ImageNet normalisation, augmentation for train only).
- [ ] `training/train.py`: load `timm` `mobilenetv3_large_100`, `num_classes=7`, weighted loss for imbalance.
- [ ] Stage 1: train head only (frozen backbone). Stage 2: unfreeze and fine-tune with low LR.
- [ ] Early stopping on validation F1; save best checkpoint.
- [ ] Train on Google Colab (Runtime → T4 GPU). Keep the dataset zip and checkpoints on Google Drive so a Colab disconnect loses nothing.
- [ ] `evaluation/evaluate.py`: accuracy, per-class precision/recall/F1, confusion matrix image.
- [ ] Temperature scaling on validation set; report calibration (ECE).
- [ ] Pick High / Medium / Low confidence thresholds from validation data.
- [ ] *(Optional)* Compare with EfficientNet-B0.

Deliverables: `models/mobilenetv3_v1.pt`, `labels.json`, metrics report + confusion matrix in `model_card.md`.

Done when:

- [ ] Test-set metrics are recorded (test set used only once).
- [ ] Thresholds and temperature value are written down.

---

## Section 4 -- Model Export and On-Device Inference

**Goal:** The real model runs inside the Flutter app, offline.

Tasks:

- [ ] `export/to_onnx.py`: export with fixed input `1×3×224×224`; apply temperature inside the graph or in app code.
- [ ] `export/verify_onnx.py`: compare PyTorch vs ONNX outputs on 100 test images (max diff < 1e-4, same top-1).
- [ ] Copy `plasticlens.onnx` + `labels.json` to `android_app/assets/models/`.
- [ ] Flutter `ClassifierService`: load model once, preprocess (EXIF rotate, resize, normalise — identical to Python), run, softmax, return top-k.
- [ ] Apply threshold policy → `High / Medium / Low / NonPlastic` result state.
- [ ] Run inference off the UI thread (isolate); show progress indicator.
- [ ] Measure latency on a physical phone.
- [ ] Fallback if the ONNX plugin fails: convert to TFLite and use `tflite_flutter`.

Deliverables: app that classifies a real photo offline.

Done when:

- [ ] Same image gives the same top-1 class in Python and in the app.
- [ ] Works in airplane mode.

---

## Section 5 -- Material Database and Result Screen

**Goal:** The result screen shows real material information for the predicted class.

Tasks:

- [ ] Write `assets/data/plastic_types.json` for all 6 polymers (full name, resin code, properties, common items, recycling guidance, fact, eco tip) — original wording, with sources noted.
- [ ] `MaterialRepository` that reads the bundled JSON (later also Firestore).
- [ ] Connect result screen to classifier output + material record.
- [ ] Uncertain state UI ("Unable to identify reliably — try another photo") and non-plastic state.
- [ ] Editable Object name field and "Correct the material" action.
- [ ] Material Details screen with full information.

Deliverables: end-to-end offline scan → full result.

Done when:

- [ ] Every class shows complete info; low-confidence and non-plastic states display correctly.

---

## Section 6 -- Firebase Auth and Cloud Data

**Goal:** Users can sign in and their data lives in Firestore securely.

Tasks:

- [ ] Add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`.
- [ ] Email/password and Google sign-in; sign-out; auth-gated navigation.
- [ ] Create `users` document on first sign-in.
- [ ] Upload `plastic_types` to Firestore (script).
- [ ] Write Firestore security rules (README §10); test with the Firebase emulator.
- [ ] Account deletion (delete user data + images).

Deliverables: login flow + deployed security rules.

Done when:

- [ ] A user cannot read another user's data (verified with emulator test).

---

## Section 7 -- FastAPI Backend and LLM Enrichment

**Goal:** Optional online "second opinion" that fills the Object field and reads resin codes.

Tasks:

- [ ] FastAPI app with `/api/health`.
- [ ] Firebase ID-token verification dependency (`firebase-admin`).
- [ ] `/api/identify/enrich`: accept image, call a vision LLM with a strict JSON prompt, validate with Pydantic, return result.
- [ ] Keep the LLM API key in server environment variables only.
- [ ] Per-user rate limit; image size limit; do not store images on the server.
- [ ] `/api/feedback` and admin endpoints.
- [ ] Pytest tests (mock the LLM call).
- [ ] Deploy (Render / Railway / Google Cloud Run).
- [ ] Flutter: if online, call enrich in parallel with local result; merge (printed resin code > classifier; show both if they disagree).

Deliverables: deployed API + app showing object names when online.

Done when:

- [ ] App works identically offline (without enrichment) and online (with enrichment).
- [ ] Invalid LLM output never crashes the app.

---

## Section 8 -- History, Collection, Sync

**Goal:** Scans are saved locally, synced to the cloud, and browsable.

Tasks:

- [ ] Local storage (`sqflite` or `hive`) for scans with `sync_status`.
- [ ] Save scan from result screen (stable UUID scan IDs).
- [ ] Background sync to Firestore when online; images optional to Storage.
- [ ] History screen: list, search, filter by material, delete.
- [ ] Collection screen: saved items grouped by material, progress (e.g. 4/6 polymers found).

Deliverables: persistent history + collection.

Done when:

- [ ] Scans made offline appear in Firestore after reconnecting, with no duplicates.

---

## Section 9 -- Gamification and Learning

**Goal:** Points, badges, streaks, and learning content.

Tasks:

- [ ] Achievement definitions in Firestore (first scan, all 6 polymers, 7-day streak, …).
- [ ] Points rules (no points for unreliable predictions; points for verification and lessons).
- [ ] Streak calculation (daily).
- [ ] Learning library: short articles per polymer + recycling basics; simple quiz.
- [ ] Notifications (FCM) for streak reminders — optional.

Deliverables: Profile shows points, badges, streak; learning section works.

Done when:

- [ ] Achievements unlock correctly in a scripted test scenario.

---

## Section 10 -- Landing Website

**Goal:** A public one-page site similar in purpose to the reference page, with original content.

Tasks:

- [ ] Hero: ocean background (licensed image), phone mock-up with a real PlasticLens screenshot, headline, tagline, download buttons.
- [ ] How it works (Snap → Identify → Recycle).
- [ ] Features and supported plastics (6 resin-code cards).
- [ ] Why it matters (facts with sources).
- [ ] Download section (APK link / Play Store when published), footer with privacy policy.
- [ ] Responsive (phone, tablet, desktop), accessible, fast.
- [ ] Deploy to Firebase Hosting.

Deliverables: live URL.

Done when:

- [ ] Lighthouse ≥ 90 for performance and accessibility; no layout break at 360 px width.

---

## Section 11 -- Testing, Hardening, Release, Report

**Goal:** A release-quality APK and project documentation.

Tasks:

- [ ] Run image test scenarios (README §15.2) on the real app; record results.
- [ ] Application tests (README §15.3); `flutter test` widget tests.
- [ ] Test on at least 2 physical Android devices.
- [ ] Security review: rules, token checks, no secrets in APK.
- [ ] Build signed release APK.
- [ ] Finish `model_card.md`, `architecture.md`, `api_documentation.md`.
- [ ] Prepare capstone report and demo video.

Deliverables: signed APK, documentation, report.

Done when:

- [ ] All boxes in README §21 "Project Completion Criteria" are ticked.
