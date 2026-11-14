# PlasticLens API

FastAPI service in `backend/`. Interactive docs are served at `/docs` when it is running.

Authentication: `Authorization: Bearer <Firebase ID token>`. The server
verifies the token with Firebase Admin and takes the user id from it. A user
id in the request body is rejected. Admin endpoints require the custom claim
`admin: true` (set with `backend/scripts/seed_firestore.py --make-admin`).

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/health` | none | Health check: `{status, version, model}` |
| POST | `/api/identify/enrich` | user | Vision-LLM second opinion for one photo |
| GET | `/api/plastics` | none | All material records |
| GET | `/api/plastics/{code}` | none | One material (`PET`, `HDPE`, …) |
| PUT | `/api/admin/plastics/{code}` | admin | Create or replace a material record |
| POST | `/api/feedback` | user | Submit a material correction |
| GET | `/api/admin/feedback?status_filter=new&limit=100` | admin | Review corrections |

## POST /api/identify/enrich

`multipart/form-data` with a field `image` (JPEG, PNG or WebP, at most 5 MB;
the type is checked from the file's bytes, not its name).

Response `200`:

```json
{
  "object_name": "Water Bottle",
  "contains_plastic": true,
  "resin_code_visible": 1,
  "likely_polymer": "PET",
  "notes": "Clear bottle, ribbed label area"
}
```

`resin_code_visible` (1–7), `likely_polymer` and `notes` may be `null`. The
output is validated strictly: unknown fields, wrong types and out-of-range
values are rejected.

| Status | Meaning |
| --- | --- |
| 401 | Missing or invalid token |
| 413 | Image larger than 5 MB |
| 415 | Not a JPEG, PNG or WebP image |
| 429 | Per-user hourly limit reached (`ENRICH_PER_HOUR`, default 30); see the `Retry-After` header |
| 503 | Model unavailable, refused, or returned invalid output |

The image is processed in memory and never stored. The model is called with
structured JSON output, low effort and the server-side refusal fallback
enabled (`fallbacks: "default"`).

## POST /api/feedback

```json
{ "scan_id": "uuid", "predicted": "PET", "corrected": "PP", "confidence": 0.61, "model_version": "mobilenetv3-v1" }
```

`corrected` must be one of `PET HDPE PVC LDPE PP PS non_plastic`. Returns `201`
with the stored record (`id`, `user_id`, `status: "new"`).

## Configuration (environment variables)

| Variable | Default | Notes |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | (required) | Secret: server only |
| `ENRICH_MODEL` | `claude-opus-5-5` | |
| `ENRICH_TIMEOUT_S` | `20` | |
| `ENRICH_PER_HOUR` | `30` | Per-user limit |
| `MAX_IMAGE_BYTES` | `5242880` | |
| `FIREBASE_PROJECT` | `plasticlens-61083` | |
| `GOOGLE_APPLICATION_CREDENTIALS` | (none) | Service-account key path, if not on Cloud Run |
| `CORS_ORIGINS` | `https://plasticlens-61083.web.app` | Comma-separated |

## Run and test

```powershell
cd backend
C:\src\venvs\plasticlens\Scripts\Activate.ps1
pip install -r requirements.txt
pytest                         # 21 tests, the LLM is mocked
uvicorn app.main:app --reload  # http://127.0.0.1:8000/docs
```

## Deploy (Google Cloud Run)

```powershell
gcloud run deploy plasticlens-api --source backend --region asia-south1 `
  --allow-unauthenticated --set-secrets ANTHROPIC_API_KEY=anthropic-key:latest
```

Then build the app with the URL:
`flutter build apk --release --dart-define=ENRICH_URL=https://<service-url>`.
