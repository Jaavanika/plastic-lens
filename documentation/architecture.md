# PlasticLens architecture

```text
 ┌──────────────────────── Android app (Flutter) ────────────────────────┐
 │  Screens: Home · Scan · Preview · Result · Material · Collection ·    │
 │           History · Profile · Learn/Quiz · Badges · Sign-in           │
 │                                                                       │
 │  ClassifierService ── OnnxClassifier ── assets/models/plasticlens.onnx│
 │     (isolate preprocess → ONNX Runtime → calibrated probabilities)    │
 │  MaterialRepository ── assets/data/plastic_types.json (+ Firestore)   │
 │  ScanStore ── SqliteScanStorage (sqflite, offline first)              │
 │  ProgressService ── points / streaks / badges from scans + lessons    │
 │  LearningService ── assets/data/learn.json                            │
 │  AuthService ── Firebase Auth (email, Google)  | LocalOnlyAuth        │
 │  CloudSync ── Firestore users/{uid}/scans, user_progress, Storage     │
 │  EnrichService ── HTTPS → FastAPI (optional second opinion)           │
 └───────────────┬───────────────────────────────┬───────────────────────┘
                 │ Firebase SDK (rules enforced)  │ ID token
                 ▼                                ▼
   Firebase: Auth · Firestore · Storage      FastAPI (Cloud Run / Render)
   · Hosting (website)                         /api/identify/enrich → Claude vision
                                               /api/plastics, /api/feedback, admin
```

## Key decisions

| Decision | Why |
| --- | --- |
| On-device MobileNetV3-Large (ONNX) | Works offline, costs nothing per scan, keeps photos private, and gives measurable metrics. |
| Temperature scaling inside the ONNX graph | The app reads calibrated probabilities directly, so Python and Dart cannot drift apart on calibration. |
| `labels.json` ships next to the model | Class order, thresholds, input spec and model version travel together (README §12). |
| Offline-first local database | Every scan is saved locally first (`sync_status = pending`) and pushed when the user is signed in and online. |
| UUID scan ids = Firestore document ids | Retries overwrite rather than duplicate, so sync is idempotent. Deletes made offline are kept as tombstones. |
| Firebase is optional at build time | Without `google-services.json` the app runs local-only. This keeps the repo free of secrets and the app usable without an account. |
| Progress is derived, not accumulated | Points, streaks and badges are recomputed from scans and lessons. They cannot drift, and unreliable predictions never count. |
| FastAPI only for server-side secrets | The LLM API key never ships in the APK. Normal user data goes straight to Firestore under security rules. |
| Strict validation of LLM output | Strict Pydantic validation on the server plus defensive parsing in the app. Bad output is dropped, never shown. |

## Data model (Firestore)

| Path | Contents | Access |
| --- | --- | --- |
| `users/{uid}` | display name, email, created_at, photo_backup | owner |
| `users/{uid}/scans/{scanId}` | scan record (README §10) | owner, validated fields |
| `user_progress/{uid}` | points, streaks, badges | owner, validated |
| `plastic_types/{code}` | material records | public read, admin write |
| `plastic_items/{id}` | item descriptions (reserved) | public read, admin write |
| `achievements/{id}` | badge definitions | public read, admin write |
| `feedback/{id}` | user corrections | create own; admin read |
| Storage `scans/{uid}/{scanId}.jpg` | optional photo backup (≤ 5 MB, images) | owner |

The README listed separate `scans` and `collections` collections. Here scans
are a sub-collection per user (simpler, safer rules), and "in collection" is a
flag on the scan, so the two cannot get out of step.

Rules: `firebase/firestore.rules`, `firebase/storage.rules`. Tests:
`firebase/tests/rules.test.js` (`npm run test:rules`, Firebase emulator).

## Scan flow

1. Camera (`camera`) or gallery (`image_picker` photo picker). The file is validated for type, size and existence.
2. Preview → **Use photo**.
3. In parallel:
   - on-device classification: decode → EXIF rotate → resize 224×224 → normalise → ONNX → probabilities;
   - if signed in and online: `POST /api/identify/enrich` with a 12 s timeout, skipped on any failure.
4. Threshold policy (`labels.json`) → High / Medium / Low / Non-plastic.
5. Merge the second opinion: it names the object, and a printed resin code beats the model, with both shown.
6. Copy the photo into app storage, save the scan locally (pending), then sync.
7. Result screen: Object / Plastic presence / Plastic type / Confidence, material panel, correct / rename / save to collection.

## Testing map

| Layer | Tests |
| --- | --- |
| Flutter widgets, policy, preprocessing parity, progress, sync, enrichment parsing | `android_app/test/*.dart` (`flutter test`) |
| Security rules | `firebase/tests/rules.test.js` (emulator) |
| Backend | `backend/tests/test_api.py` (`pytest`, LLM mocked) |
| Model | `ai_model/evaluation/evaluate.py`, `ai_model/export/verify_onnx.py` |
