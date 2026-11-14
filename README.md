# PlasticLens -- AI-Powered Plastic Identification and Recycling Assistant

> **Project type:** Android application (Flutter) + promotional landing website
> **Primary goal:** Identify likely plastic materials from photographs and
> provide useful material, recycling, and educational information.
> **Proposed development timeline:** 8 weeks for an initial end-to-end implementation
> **Initial AI classes:** PET, HDPE, PVC, LDPE, PP, and PS
> **Implementation plan:** see [PLAN.md](PLAN.md)

---

## 1. Project Overview

PlasticLens is an Android application inspired by the functionality of
the Sustainable Design Studio Plastic Scanner. It is an independent
implementation with its own name, user interface, code, model, database,
and content.

A user can photograph a plastic item or choose an image from the
gallery. The application analyses the image and displays a result card
containing:

| Field            | Example        | Produced by                         |
| ---------------- | -------------- | ----------------------------------- |
| Object           | Water Bottle   | Object-naming stage (see §6)        |
| Plastic presence | Yes            | Plastic / non-plastic gate (see §6) |
| Plastic type(s)  | PET            | Polymer classifier (see §6)         |
| Confidence       | 94.3 %         | Calibrated classifier output        |
| Material info    | PET description, recycling notes | Material database (see §9) |

The application also supports user accounts, scan history, personal
collections, achievements, learning content, and synchronisation with
cloud services. A public landing website (§13) presents the app and links
to the APK / Play Store listing.

### Important identification limitation

A normal RGB photograph cannot reliably establish the chemical
composition of every plastic object. The model predicts a likely visual
category based on its training data; it does not perform laboratory
polymer analysis. The app must communicate uncertainty, support manual
verification, and avoid presenting a visual prediction as a guaranteed
material identification.

---

## 2. Project Objectives

1.  Build a complete Android application for plastic-item scanning.
2.  Support camera capture and gallery image selection.
3.  Fine-tune a pretrained image-classification model for plastic categories.
4.  Detect whether an image contains plastic at all, and name the object.
5.  Display a clear identification result and confidence information.
6.  Maintain a structured plastic-material information database.
7.  Provide recycling and disposal guidance that can be adapted to local facilities.
8.  Save scan history and personal collections.
9.  Add learning resources, points, achievements, and scanning streaks.
10. Support offline AI inference on Android.
11. Provide cloud synchronisation, user authentication, and administration.
12. Publish a landing website similar in purpose to the reference page.

---

## 3. Scope and Features

### 3.1 Core scanning

-   Capture an image using the Android camera.
-   Select an image from the device gallery.
-   Preview, retake, or crop an image.
-   Validate image format, dimensions, and file size.
-   Run image preprocessing.
-   Run the on-device AI model.
-   Display the object name, plastic presence, predicted class, and confidence.
-   Show an uncertain-result state when confidence is low or the image
    is unsuitable.

### 3.2 Identification result

The result screen should display:

-   Object name (from the AI, editable by the user).
-   Plastic presence (Yes / No / Unsure).
-   Predicted plastic type.
-   Full polymer name.
-   Resin identification code, where applicable.
-   Model confidence and an explanation that it is not a laboratory
    measurement.
-   Material properties.
-   Other commonly associated materials, where known.
-   Recycling and disposal guidance.
-   Recyclability information with local-context caveats.
-   Educational fact and eco tip.
-   Save-to-collection action.

### 3.3 User features

-   Registration, sign-in, and sign-out.
-   User profile.
-   Scan history.
-   Search and filter history.
-   Personal collection of identified items.
-   Achievements and points.
-   Daily or weekly scanning streaks.
-   Learning library.
-   Feedback or correction submission.
-   Privacy and data-deletion controls.

### 3.4 Administration features

A protected admin workflow should allow authorised maintainers to:

-   Add and update material records.
-   Add and update item descriptions.
-   Review user-submitted corrections.
-   Maintain recycling guidance.
-   Manage learning content.
-   Review aggregate model feedback.
-   Publish updated model versions and class labels.

For the first release, admin tasks may be done directly in the Firebase
Console; a custom admin UI is optional.

---

## 4. Proposed Technology Stack

| Layer                 | Technology                         | Responsibility                                  |
| --------------------- | ---------------------------------- | ----------------------------------------------- |
| Android frontend      | Flutter and Dart                   | Screens, navigation, camera, gallery            |
| UI components         | Material 3                         | Consistent Android interface                    |
| AI training           | Python, PyTorch, `timm`            | Fine-tuning and evaluation                      |
| Polymer classifier    | MobileNetV3-Large                  | Polymer image classification                    |
| Plastic gate          | Same network, extra "non-plastic" class, or a small binary model | Plastic presence |
| Object naming (cloud) | Vision LLM via FastAPI (optional)  | Object name, resin-code reading, second opinion |
| Optional detector     | YOLOv8n                            | Locating objects in cluttered images            |
| On-device inference   | ONNX Runtime Mobile (or TFLite)    | Offline model inference                         |
| Backend API           | Python and FastAPI                 | LLM proxy, admin, analytics                     |
| Authentication        | Firebase Authentication            | User identity                                   |
| Database              | Cloud Firestore                    | Users, scans, collections, material records     |
| Image storage         | Firebase Storage                   | Optional cloud image storage                    |
| Notifications         | Firebase Cloud Messaging           | Notifications                                   |
| Landing website       | HTML/CSS/JS (or React + Vite)      | Public promotional page                         |
| Website hosting       | Firebase Hosting                   | Hosting the landing page                        |
| Version control       | Git and GitHub                     | Source control                                  |
| API testing           | Postman                            | Endpoint testing                                |
| Python testing        | Pytest                             | Backend and ML tests                            |
| Flutter testing       | `flutter test`                     | Widget and application tests                    |

### Architecture choice

Use a **hybrid architecture**:

-   Run the classifier on the Android device for offline scanning.
-   Use Firebase directly from the app for authentication, user data, and
    optional image storage (protected by Firestore security rules).
-   Use FastAPI only for things that must not run on the phone: calling a
    vision LLM with a secret API key, admin operations, and analytics.

The application should not need to upload every image just to make a
basic prediction. Never embed an LLM API key inside the Android app.

---

## 5. High-Level System Architecture

```text
                    ANDROID APPLICATION (Flutter / Dart)
                                  |
                   +--------------+--------------+
                   |                             |
              Camera Module                Gallery Module
                   |                             |
                   +--------------+--------------+
                                  |
                         Image Validation
                                  |
                        Image Preprocessing
                                  |
                 [Optional] Object Detection (YOLOv8n)
                                  |  crop
                                  v
                 On-device Classifier (ONNX Runtime)
                 MobileNetV3: PET/HDPE/PVC/LDPE/PP/PS
                         + non-plastic class
                                  |
                       Prediction Handling
               (thresholds, uncertain / unknown state)
                                  |
          +-----------------------+------------------------+
          |                                                |
  Plastic Information Engine                 [Optional, online only]
  (local material database)                  FastAPI -> Vision LLM
          |                                  object name, resin code,
          |                                  second opinion
          +-----------------------+------------------------+
                                  |
                            Result Screen
                                  |
                          Local Scan Record
                                  |
                        Cloud Synchronisation
                                  |
                 Firebase Auth / Firestore / Storage
```

### Initial implementation simplification

Start with a single MobileNetV3 classifier on a cropped or user-centred
image. Add YOLO object detection only if tests show that locating an
object in cluttered scenes is necessary. Add the LLM stage after the
offline path works. This avoids adding complexity before it is justified.

---

## 6. Identification Approach: Trained Model vs. LLM

Two ways exist to identify the plastic in a photo.

| Criterion                 | Fine-tuned model (MobileNetV3)             | Vision LLM (e.g. Claude, Gemini, GPT)          |
| ------------------------- | ------------------------------------------ | ---------------------------------------------- |
| Training needed           | Yes (dataset, GPU, ~1–2 weeks)             | No (prompt only)                               |
| Works offline             | Yes                                        | No                                             |
| Cost per scan             | Free                                       | Paid per API call                              |
| Speed                     | ~50–200 ms on device                       | ~1–5 s network round-trip                      |
| Names the object          | No (only the trained classes)              | Yes ("water bottle", "yogurt cup")             |
| Reads the resin code ♲    | No                                         | Yes, if visible in the photo                   |
| Polymer accuracy          | Measurable on a test set                   | Unmeasured, can sound confident when wrong     |
| Privacy                   | Image stays on device                      | Image sent to a third party                    |
| Capstone value            | Shows ML work: dataset, training, metrics  | Integration work only                          |

**Decision: hybrid.**

1.  **Primary (required): a trained on-device classifier.** It gives
    offline scanning, zero per-scan cost, and measurable metrics (accuracy,
    F1, confusion matrix) for the project report.
2.  **Secondary (optional, online): a vision LLM called through FastAPI.**
    It fills the *Object* field, reads a visible resin code, and gives a
    second opinion. If the LLM reads a resin code that disagrees with the
    classifier, prefer the printed code and show both to the user.
3.  The LLM output must be requested as strict JSON and validated, e.g.:

```json
{
  "object_name": "Water Bottle",
  "contains_plastic": true,
  "resin_code_visible": 1,
  "likely_polymer": "PET",
  "notes": "Clear bottle, ribbed label area"
}
```

If budget or connectivity is a problem, the app still works fully with the
on-device model alone; the object name is then entered by the user.

---

## 7. AI and Machine Learning Plan

### 7.1 Initial classes

| Class ID | Class                                 | Resin identification code |
| -------: | ------------------------------------- | ------------------------: |
|        0 | PET -- Polyethylene Terephthalate     |                         1 |
|        1 | HDPE -- High-Density Polyethylene     |                         2 |
|        2 | PVC -- Polyvinyl Chloride             |                         3 |
|        3 | LDPE -- Low-Density Polyethylene      |                         4 |
|        4 | PP -- Polypropylene                   |                         5 |
|        5 | PS -- Polystyrene                     |                         6 |
|        6 | Non-plastic (recommended addition)    |                         – |

The resin identification code is a material-identification convention;
it does not guarantee that an item is accepted by a local recycling
programme. Code 7 ("Other") is out of scope for the first model.

The non-plastic class can be trained with the non-plastic categories of
TrashNet (glass, paper, cardboard, metal). Other categories, including
mixed plastics, should be added only when suitable labelled training data
and evaluation evidence are available.

### 7.2 Pretrained model selection

| Model             | Role                 | Notes                                        |
| ----------------- | -------------------- | -------------------------------------------- |
| MobileNetV3-Large | Primary candidate    | Efficient and suitable for mobile deployment |
| EfficientNet-B0   | Comparison candidate | Alternative accuracy/size trade-off          |
| ResNet50          | Baseline candidate   | Larger model for comparison                  |

**Recommended starting point: MobileNetV3-Large.**

Use pretrained weights, replace the original classification head with a
new head, and fine-tune on the project dataset.

```python
import timm

model = timm.create_model(
    "mobilenetv3_large_100",
    pretrained=True,
    num_classes=7,  # 6 polymers + non-plastic
)
```

This creates a model architecture with pretrained weights and a new
output layer. It does not train the model; training code, labelled data,
and evaluation are still required.

### 7.3 Training workflow

1.  Download and inspect datasets.
2.  Verify class labels and annotations.
3.  Remove corrupted and duplicate images.
4.  Create object crops if bounding-box annotations are available.
5.  Split data into training, validation, and test sets.
6.  Ensure images of the same physical object or source do not leak
    across splits.
7.  Resize images to the model input size, initially 224 × 224.
8.  Apply the correct pretrained-model normalisation.
9.  Apply realistic augmentation.
10. Handle class imbalance (weighted loss or weighted sampling; PVC has
    the fewest images).
11. Train the new classification head.
12. Fine-tune selected feature layers.
13. Evaluate on the untouched test set.
14. Calibrate prediction confidence and define an unknown/uncertain path.
15. Export the selected model to ONNX.
16. Verify that ONNX predictions match the PyTorch model within an
    acceptable tolerance.
17. Test latency, memory use, and battery impact on Android devices.

### 7.4 Image preprocessing

Inference preprocessing (must be identical in Python and in the app):

-   Decode image safely.
-   Correct orientation using EXIF metadata.
-   Validate minimum image dimensions.
-   Crop the detected object if object detection is used.
-   Resize to 224 × 224.
-   Convert to RGB.
-   Convert pixel values to a float tensor (NCHW).
-   Apply the normalisation expected by the selected pretrained weights
    (ImageNet mean/std for the default `timm` weights).

Training augmentation:

-   Horizontal flip.
-   Small rotations.
-   Brightness and contrast variation.
-   Mild colour variation.
-   Random crop or scale.
-   Background variation.

Do not use augmentations that alter the material's appearance so
strongly that they create unrealistic training samples.

### 7.5 Confidence and unknown handling

Softmax confidence is not automatically a reliable probability of
correctness. Evaluate calibration (e.g. temperature scaling) on
validation data.

A provisional application policy:

-   High confidence: show the prediction with a verification reminder.
-   Medium confidence: ask the user to verify the material or provide
    another image.
-   Low confidence: show "Unable to identify reliably".
-   Non-plastic class wins: show "No plastic detected"; do not force a
    polymer prediction.

Thresholds must be chosen using validation results, not treated as
universal values.

---

## 8. Datasets

### 8.1 PlasticWaste-DB

Proposed primary dataset: <https://data.mendeley.com/datasets/tvfx5dspf3/1>

Reported class counts:

| Polymer   | Reported images |
| --------- | --------------: |
| PET       |             500 |
| HDPE      |             322 |
| PVC       |             168 |
| LDPE      |             440 |
| PP        |             327 |
| PS        |             472 |
| **Total** |       **2,229** |

The reported licence is CC BY 4.0. Before use, verify the current
dataset version, licence, files, annotation format, and citation
requirements on the dataset page.

### 8.2 TrashNet

Repository: <https://github.com/garythung/trashnet>

Broad waste categories (glass, paper, cardboard, plastic, metal, trash).
Useful as the source of **non-plastic** examples; its generic plastic
class does not distinguish polymers.

### 8.3 TACO -- Trash Annotations in Context

Repository: <https://github.com/pedropro/TACO>

Litter images in real-world environments with annotations. Useful for
object detection and robustness testing; not a polymer-specific dataset.

### 8.4 Custom dataset

Collect additional images of common plastic items using different
lighting, backgrounds, distances, orientations, colours, levels of
dirt or wear, and transparent / translucent / opaque appearances.

Label from the printed resin code, manufacturer markings, or reliable
product documentation. Do not label an item solely by visual guesswork.
A clear photo of the resin code is a good way to record the label source.

### 8.5 Dataset split

| Split      | Percentage |
| ---------- | ---------: |
| Training   |        70% |
| Validation |        15% |
| Testing    |        15% |

Use grouped splitting so near-duplicate images, the same physical item,
or images from the same capture session do not occur in both training
and test sets.

---

## 9. Flutter Application Screens

### Screen 1 -- Home

-   Welcome message.
-   Scan plastic button.
-   Upload image button.
-   Recent scans.
-   Collection summary.
-   Daily challenge or learning prompt.

### Screen 2 -- Scanner

-   Camera preview.
-   Capture button.
-   Gallery picker.
-   Image preview.
-   Retake and confirm actions.
-   Scanning progress indicator.

### Screen 3 -- Identification Result

Layout follows the reference card: image on top, then a details card.

-   Scanned image.
-   Object, Plastic Presence, Plastic Type(s), Confidence rows.
-   Polymer full name and resin code.
-   Uncertainty and verification message.
-   Material description panel (e.g. "PET -- Polyethylene Terephthalate ...").
-   Save scan action.

### Screen 4 -- Material Details

-   Material description.
-   Physical properties.
-   Typical applications.
-   Recycling guidance.
-   Local recyclability caveat.
-   Additional materials, if known.
-   Educational fact.
-   Eco tip.

### Screen 5 -- My Collection

-   Saved items.
-   Material categories.
-   Collection progress.
-   Achievements.
-   Streaks and points.

### Screen 6 -- Scan History

-   Previous scan records.
-   Date and time.
-   Predicted material.
-   Search and filters.
-   View result.
-   Delete record.

### Screen 7 -- Profile and Learning

-   User profile.
-   Learning library.
-   Notifications.
-   Settings.
-   Privacy and account controls.

---

## 10. Database Design

Use Firestore collections with user-specific access controls.

| Collection      | Purpose                                 |
| --------------- | --------------------------------------- |
| `users`         | User profile and preferences            |
| `plastic_types` | Polymer names, codes, and properties    |
| `plastic_items` | Item names and descriptions             |
| `scans`         | Prediction records and image references |
| `collections`   | Items saved by users                    |
| `achievements`  | Achievement definitions and awards      |
| `user_progress` | Points, streaks, and progress           |
| `feedback`      | User corrections and feedback           |

A copy of `plastic_types` is also bundled in the app as JSON so results
display offline.

### Example scan record

```json
{
  "scan_id": "SCAN_001",
  "user_id": "USER_001",
  "item_name": "Water Bottle",
  "contains_plastic": true,
  "plastic_type": "PET",
  "resin_code": 1,
  "confidence": 0.943,
  "model_version": "mobilenetv3-v1",
  "llm_used": false,
  "user_verified": false,
  "image_path": "scans/USER_001/SCAN_001.jpg",
  "sync_status": "synced",
  "created_at": "2026-11-14T10:00:00Z"
}
```

The confidence value is an illustrative example, not an actual model result.

### Example material record

```json
{
  "material": "PET",
  "full_name": "Polyethylene Terephthalate",
  "resin_code": 1,
  "properties": ["Lightweight", "Transparent", "Good moisture barrier"],
  "common_items": ["Water bottles", "Soft-drink bottles", "Food trays"],
  "recycling_guidance": "Check local PET collection facilities",
  "recyclability_rating": 4
}
```

Treat recyclability ratings as contextual information. Acceptance varies
by location, product design, contamination, and available facilities.

### Security rules

-   Require authentication for private user data.
-   Users may read and update only their own profile.
-   Users may read and delete only their own scans.
-   Protect admin-only material and content updates.
-   Validate all submitted fields.
-   Do not store passwords in Firestore.
-   Avoid public access to private scan images.
-   Provide a clear image-retention and deletion policy.
-   Do not trust a user-supplied user ID without verifying the Firebase
    identity token.

---

## 11. FastAPI Backend

The app talks to Firestore directly for normal user data. FastAPI exists
for operations that need a server-side secret or admin privileges.

| Endpoint                   | Method | Purpose                                         |
| -------------------------- | ------ | ----------------------------------------------- |
| `/api/health`              | GET    | Health check                                    |
| `/api/identify/enrich`     | POST   | Send image to vision LLM; return validated JSON |
| `/api/plastics`            | GET    | List plastic materials (public)                 |
| `/api/plastics/{id}`       | GET    | Retrieve material details (public)              |
| `/api/admin/plastics/{id}` | PUT    | Update material record (admin only)             |
| `/api/feedback`            | POST   | Submit correction feedback                      |
| `/api/admin/feedback`      | GET    | Review feedback (admin only)                    |

Secure protected endpoints by verifying Firebase ID tokens. Derive the
user identity from the verified token, not from a request field. Rate-limit
`/api/identify/enrich` per user to control LLM cost.

---

## 12. On-Device Model Deployment

1.  Train and validate the model in PyTorch.
2.  Save the selected model checkpoint.
3.  Export to ONNX.
4.  Verify input shape, preprocessing, output labels, and prediction parity.
5.  Benchmark the ONNX model on representative Android devices.
6.  Bundle the model and a `labels.json` file in the Flutter app assets.
7.  Run inference with the `onnxruntime` Flutter package (fallback:
    convert to TFLite and use `tflite_flutter`).
8.  Run inference locally.
9.  Save the result locally.
10. Synchronise the record when connectivity is available.

Keep the model version and class-label mapping together. A model update
must not silently change the meaning of existing scan records.

Optional: add YOLOv8n object detection if cluttered scenes require
object localisation. It is not required for the first version.

---

## 13. Landing Website

A one-page public website, similar in purpose to the reference page
(<https://www.sustainabledesign.studio/plasticscanner>), but with original
branding, text, and images.

Sections:

1.  **Hero** -- full-width ocean/waste background, phone mock-up showing a
    real PlasticLens result screenshot, headline, short tagline,
    "Download APK" / "Get it on Google Play" buttons.
2.  **How it works** -- three steps: Snap → Identify → Recycle.
3.  **Features** -- offline AI, material info, recycling tips, collection
    and achievements.
4.  **Supported plastics** -- cards for PET, HDPE, PVC, LDPE, PP, PS with
    resin codes.
5.  **Why it matters** -- short plastic-pollution facts, with sources.
6.  **Download / CTA** and **footer** (privacy policy, contact, credits).

Requirements: responsive (mobile first), fast-loading, accessible
(contrast, alt text), hosted on Firebase Hosting. Use only images you own
or that are licensed for reuse; do not copy the reference site's assets
or text. Use the official Google Play badge only after the app is
actually published on Play.

---

## 14. Gamification

-   Points for completing a scan.
-   Badges for identifying new material categories.
-   Streaks for regular learning or scanning.
-   Collection completion progress.
-   Educational challenges.
-   Milestones for learning about recycling.

Do not award points for a prediction that the app itself has marked as
unreliable. Consider rewarding user verification and learning actions
instead of scan volume alone.

---

## 15. Evaluation and Testing

### 15.1 AI metrics

| Metric            | Purpose                              |
| ----------------- | ------------------------------------ |
| Accuracy          | Overall classification correctness   |
| Precision         | Correctness of predicted classes     |
| Recall            | Coverage of actual class examples    |
| F1-score          | Balance between precision and recall |
| Confusion matrix  | Identifies class confusion           |
| Calibration (ECE) | Checks reliability of confidence     |
| Inference latency | Measures prediction time             |
| Model size        | Measures deployment footprint        |

Report per-class precision, recall, F1, and support. Include a separate
non-plastic evaluation. If the LLM stage is used, also measure its
agreement with ground truth on a small labelled set.

### 15.2 Image test scenarios

-   Transparent bottles.
-   Dark plastics.
-   White containers.
-   Crushed objects.
-   Plastic bags.
-   Multiple objects in one image.
-   Low-light images.
-   Blurred images.
-   Non-plastic objects.
-   Unseen object types and backgrounds.

### 15.3 Application testing

-   Camera and gallery permission handling.
-   Invalid image handling.
-   Offline scanning.
-   Cloud synchronisation.
-   Authentication and access control.
-   Scan history persistence.
-   Image deletion.
-   Model loading failures.
-   Low-memory devices.
-   Different Android screen sizes.

### 15.4 Website testing

-   Lighthouse score (performance, accessibility, SEO).
-   Layout at phone, tablet, and desktop widths.
-   All download links work.

---

## 16. Project Folder Structure

```text
plastic-lens/
|
|-- android_app/
|   |-- lib/
|   |   |-- screens/
|   |   |-- widgets/
|   |   |-- services/
|   |   |-- models/
|   |   |-- providers/
|   |   |-- utils/
|   |   `-- main.dart
|   |-- assets/
|   |   |-- models/        # plasticlens.onnx, labels.json
|   |   |-- data/          # plastic_types.json (offline copy)
|   |   `-- images/
|   `-- test/
|
|-- ai_model/
|   |-- datasets/          # not committed to Git
|   |-- preprocessing/
|   |-- training/
|   |-- evaluation/
|   |-- export/
|   `-- models/
|
|-- backend/
|   |-- app/
|   |   |-- routers/
|   |   |-- services/
|   |   |-- schemas/
|   |   `-- main.py
|   `-- tests/
|
|-- website/
|   |-- index.html
|   |-- css/
|   |-- js/
|   `-- assets/
|
|-- documentation/
|   |-- architecture.md
|   |-- model_card.md
|   `-- api_documentation.md
|
|-- README.md
|-- PLAN.md
`-- .gitignore
```

---

## 17. Eight-Week Development Roadmap

| Week | Tasks                                                           | Deliverable          |
| ---: | --------------------------------------------------------------- | -------------------- |
|    1 | Repo + environment setup, Flutter UI skeleton, navigation       | UI prototype         |
|    2 | Dataset download, inspection, cleaning, splitting               | Prepared dataset     |
|    3 | MobileNetV3 fine-tuning and evaluation                          | Trained model        |
|    4 | ONNX export and Android inference integration                   | Working scanner      |
|    5 | Firebase auth, Firestore, material database, FastAPI + LLM      | Connected backend    |
|    6 | Scan history, collection, material details                      | Core application     |
|    7 | Achievements, streaks, learning, notifications, landing website | Complete feature set |
|    8 | Testing, security review, performance, APK build, report        | Release candidate    |

This is a target schedule, not a guarantee. The section-by-section
breakdown is in [PLAN.md](PLAN.md).

---

## 18. Development Environment Setup

| Software         | Purpose                          |
| ---------------- | -------------------------------- |
| Android Studio   | Android SDK and emulator         |
| Flutter SDK      | Mobile app framework             |
| VS Code          | Code editor                      |
| Python 3.11      | AI and backend development       |
| PyTorch + timm   | Model training                   |
| Google Colab     | GPU-based experimentation        |
| Firebase CLI     | Firebase project and hosting     |
| Git              | Version control                  |
| Postman          | API testing                      |

Official documentation:

-   Flutter: <https://docs.flutter.dev/>
-   Android Studio: <https://developer.android.com/studio>
-   PyTorch: <https://pytorch.org/>
-   timm: <https://huggingface.co/docs/timm>
-   ONNX Runtime Mobile: <https://onnxruntime.ai/docs/tutorials/mobile/>
-   Firebase Flutter setup: <https://firebase.google.com/docs/flutter/setup>
-   FastAPI: <https://fastapi.tiangolo.com/>
-   PlasticWaste-DB: <https://data.mendeley.com/datasets/tvfx5dspf3/1>
-   TrashNet: <https://github.com/garythung/trashnet>
-   TACO: <https://github.com/pedropro/TACO>

---

## 19. Risks and Mitigation

| Risk                           | Mitigation                                                |
| ------------------------------ | --------------------------------------------------------- |
| Similar-looking polymers       | Collect verified labels and evaluate class confusion      |
| Small dataset                  | Add carefully labelled custom images; weighted loss       |
| Transparent or dark objects    | Include dedicated examples and test conditions            |
| Non-plastic input              | Train a non-plastic class                                 |
| Misleading confidence          | Calibrate and communicate uncertainty                     |
| LLM hallucination              | Strict JSON schema, validation, show as "second opinion"  |
| LLM cost / API key leak        | Key only on server; per-user rate limits                  |
| Incorrect recycling advice     | Use reviewed, location-aware guidance                     |
| Offline/cloud conflicts        | Use stable scan IDs and sync status                       |
| Model updates changing labels  | Version models and preserve label mappings                |
| Privacy concerns               | Minimise image retention and enforce access controls      |
| Flutter ONNX plugin problems   | Fallback to TFLite (`tflite_flutter`)                     |

---

## 20. Final Technical Specification

| Component            | Selected technology                     |
| -------------------- | --------------------------------------- |
| Platform             | Android                                 |
| Frontend             | Flutter and Dart                        |
| AI framework         | PyTorch + timm                          |
| Primary model        | MobileNetV3-Large (6 polymers + non-plastic) |
| Optional detector    | YOLOv8n                                 |
| Optional cloud AI    | Vision LLM via FastAPI                  |
| Model deployment     | ONNX Runtime Mobile                     |
| Backend              | Python and FastAPI                      |
| Database             | Firebase Firestore                      |
| Authentication       | Firebase Authentication                 |
| Storage              | Firebase Storage                        |
| Website              | Static HTML/CSS/JS on Firebase Hosting  |
| Training environment | Google Colab or local GPU               |
| Inference            | On-device, offline-capable              |
| Target timeline      | 8 weeks                                 |

---

## 21. Project Completion Criteria

-   [ ] A user can register and sign in.
-   [ ] A user can capture or upload an image.
-   [ ] The app can run the AI model on Android, offline.
-   [ ] The app displays object, plastic presence, material, and confidence.
-   [ ] Uncertain and non-plastic inputs are handled safely.
-   [ ] The result page displays material information and recycling guidance.
-   [ ] Users can save and view scans.
-   [ ] Users can manage their collection.
-   [ ] Achievements and progress work correctly.
-   [ ] User data is protected by access controls.
-   [ ] Cloud synchronisation works when connectivity returns.
-   [ ] AI evaluation results and model version are documented.
-   [ ] The landing website is live and links to the app.
-   [ ] The application has been tested on physical Android devices.

---

## 22. Reference and Originality Note

PlasticLens is an independent project inspired by publicly described
Plastic Scanner functionality. It is not affiliated with or endorsed by
Sustainable Design Studio.

Use independently created UI designs, branding, source code, images, and
educational content. Review the licence and attribution requirements for
every dataset, model, image, and third-party library used.

The internal architecture and AI model of the reference application are
not known. The stack above is a recommendation for building a similar
application, not a claim about the original implementation.
