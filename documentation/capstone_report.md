# PlasticLens: AI-Powered Plastic Identification and Recycling Assistant

**Capstone project report (draft)**

| | |
| --- | --- |
| Student | Jaavanika L |
| Programme / college | *[fill in]* |
| Supervisor | *[fill in]* |
| Date | November 2026 |
| Source code | https://github.com/Jaavanika/plastic-lens |

---

## Abstract

Household plastic is often sorted wrongly because people cannot tell one
plastic from another. PlasticLens is an Android app that estimates the likely
plastic type of an item from a single photo and explains how to dispose of it.
A MobileNetV3-Large network was fine-tuned on 2,994 images covering six resin
types (PET, HDPE, PVC, LDPE, PP, PS) plus a non-plastic class. It runs fully
offline on the phone through ONNX Runtime. On a held-out test set of 450
images it reaches **91.6 % accuracy (macro-F1 0.915)**. After temperature
scaling, its confidence is well calibrated (ECE 0.034), and a threshold policy
chosen on validation data marks 74 % of test images as high-confidence at
**97.3 % accuracy**. The app adds a material database, scan history,
collections, gamification and a learning library. It optionally uses Firebase
for accounts and sync, and a FastAPI service for a vision-LLM "second opinion".
A landing website scores 100 in every Lighthouse category.

## 1. Introduction

### 1.1 Problem

The resin identification code (♲1–♲7) printed on plastic items is often
missing, hard to read or misunderstood. Many people also read it as a promise
that the item is recyclable. Sorting mistakes contaminate recycling streams,
and plastic that is burned in the open or leaked into the environment causes
lasting harm.

### 1.2 Aim and objectives

Build a working Android app that:

1. identifies the likely plastic type from a camera or gallery photo, offline;
2. is honest about uncertainty and never presents a visual guess as a lab result;
3. gives material and recycling information for each type;
4. keeps scan history and a collection, with motivation through points and badges;
5. syncs securely to the cloud when the user chooses;
6. is presented by a public landing website.

### 1.3 Scope

There are seven classes: six resin codes plus non-plastic. Code 7 ("other"),
multi-material packaging and several items in one photo are out of scope for
v1 (see §8).

## 2. Background and related work

Plastic-scanner apps exist; the Sustainable Design Studio Plastic Scanner
inspired this project. Its internals are not public, so PlasticLens is an
independent design with its own model, data, UI and content. Image
classification of waste usually fine-tunes ImageNet-pretrained CNNs. Mobile
architectures such as MobileNetV3 trade a little accuracy for low latency and
small size. Vision LLMs can name objects and read printed codes, but they need
a network connection, cost money per call and are hard to measure.
PlasticLens therefore uses a trained on-device model as the core and an LLM
only as an optional second opinion (README §6).

## 3. System design

See `documentation/architecture.md` for the diagram and the data model.

- **App:** Flutter (Material 3), offline-first. Scans are written to SQLite first and synced later.
- **AI:** MobileNetV3-Large exported to ONNX (16.8 MB). Calibration (temperature + softmax) is baked into the graph, and `labels.json` carries the class order, thresholds and input spec.
- **Cloud (optional):** Firebase Auth, Firestore and Storage, protected by security rules and tested in the emulator.
- **Backend (optional):** FastAPI on Cloud Run or Render. The LLM API key stays on the server; responses are rate-limited and strictly validated.
- **Website:** static HTML, CSS and JS on Firebase Hosting.

Key design decisions and the reasons for them are tabulated in `architecture.md`.

## 4. Dataset

Details: `documentation/model_card.md` §1.

- **PlasticWaste-DB** (CC BY 4.0): 2,227 photos with oriented bounding boxes. Each labelled object was cropped with a 10 % margin.
- **TrashNet** (MIT): 440 images of glass, paper, cardboard and metal for the non-plastic class.
- Perceptual-hash de-duplication removed 32 images. Visually similar images were grouped, and a grouped, stratified **70 / 15 / 15** split guarantees that no near-duplicate crosses splits. This was checked automatically.

## 5. Model

- `timm` `mobilenetv3_large_100`, ImageNet weights, new 7-class head.
- Two-stage fine-tuning: head only, then the full network. Class-weighted cross-entropy, realistic augmentation, early stopping on validation macro-F1. Best epoch 20 of 27; about 45 minutes on a laptop CPU.
- Temperature scaling (T = 2.733) on the validation set.
- Thresholds from validation data: High ≥ 0.70 (≥ 95 % target accuracy), Medium 0.30–0.70 ("please verify"), Low < 0.30 ("unable to identify").

## 6. Results

### 6.1 Classification (test set, n = 450)

| Metric | Value |
| --- | ---: |
| Accuracy | 0.916 |
| Macro-F1 | 0.915 |
| ECE (calibrated) | 0.034 |
| Plastic correctly detected as plastic | 0.992 |
| Non-plastic recall / precision | 0.924 / 0.953 |

Per-class F1 ranges from 0.887 (PET) to 0.938 (non-plastic). The confusion
matrix (`figures/confusion_matrix.png`) shows that most errors are PET
confused with HDPE or LDPE (crumpled clear bottles and films) and PP confused
with PS (small white fragments).

### 6.2 Uncertainty policy

| Bucket | Share | Accuracy |
| --- | ---: | ---: |
| High confidence | 74.0 % | 97.3 % |
| Please verify | 10.7 % | 54.2 % |
| Unable to identify | 1.1 % | 20.0 % |
| No plastic | 14.2 % | 95.3 % |

The policy works as intended: confident answers are almost always right, and
the cases the app asks the user to check really are uncertain.

### 6.3 Robustness (README §15.2)

With degraded images (low light, blur, compression, rotation), results mostly
move into the *unsure* states rather than becoming confident errors. Even at
15 % brightness only 10 % are confidently wrong. The weakest case is several
items in one photo (17 % confidently wrong). Full table: model card §6.

### 6.4 Deployment

The PyTorch and ONNX outputs agree to within 4 × 10⁻⁶. The Dart image
preprocessing ports Pillow's resampling and matches Python to within about 4
grey levels. On an Android runtime with **airplane mode on**, all 7 parity
images gave the same top-1 class as Python. Latency on the emulator is about
115 ms per scan; the physical-phone figure is still to be measured.

## 7. Implementation and testing

| Area | Evidence |
| --- | --- |
| App features | Home, scanner (camera and gallery), preview, result (Object / Plastic presence / Plastic type / Confidence + material panel), correct and rename, material details, collection (x/6 polymers), history (search, filter, delete), profile, learning library + quiz, badges |
| Tests | 32 Flutter unit/widget tests, 1 on-device integration test, 9 security-rule tests, 21 backend tests, all passing; Lighthouse 100 ×4 |
| Security | Owner-only Firestore and Storage rules with field validation; ID-token verification on the server; no secrets in the APK or the git history (scanned); LLM key only on the server; photo backup off by default |
| Bugs found and fixed | 6, listed in `documentation/testing.md` |

## 8. Limitations

- A photo cannot reveal chemistry. The app presents a *likely* type and always asks users to check the printed code.
- The training data comes from a single plastic dataset with many outdoor litter photos and some product renders; it has a domain gap with clean household items.
- There is no object detector, so photos with several items are the weakest case.
- Code 7, multi-layer packaging and black plastics are not covered.
- Physical-phone latency and multi-device testing are still pending.

## 9. Future work

1. Collect and label household photos using the printed resin code, then fine-tune again; use the in-app corrections as a review queue.
2. Add a YOLOv8n detector to crop single items from cluttered scenes.
3. Add a code-7 or "other plastic" class once there is labelled data.
4. Location-aware recycling rules (which bins a given council accepts).
5. Publish on Google Play after the physical-device tests are done.

## 10. Conclusion

PlasticLens meets its core aim: an offline Android app that identifies the
likely plastic type with measured, calibrated confidence, handles uncertain
and non-plastic inputs safely, and gives useful recycling guidance. It has a
tested cloud layer and a public website. The engineering choices (on-device
inference, offline-first storage, calibration inside the model, strict
validation of AI output) favour honesty and privacy over flashy but
unverifiable claims.

## References

1. S. C. Sarkar, J. J. Bushra, M. S. Hossain. *PlasticWaste-DB*. Mendeley Data, v1, 2026. doi:10.17632/tvfx5dspf3.1 (CC BY 4.0).
2. G. Thung, M. Yang. *Classification of Trash for Recyclability Status*. 2016. https://github.com/garythung/trashnet (MIT).
3. A. Howard et al. *Searching for MobileNetV3*. ICCV 2019.
4. C. Guo, G. Pleiss, Y. Sun, K. Weinberger. *On Calibration of Modern Neural Networks*. ICML 2017.
5. R. Wightman. *PyTorch Image Models (timm)*. https://github.com/huggingface/pytorch-image-models
6. ONNX Runtime. https://onnxruntime.ai
7. ASTM D7611, *Standard Practice for Coding Plastic Manufactured Articles for Resin Identification*.
8. OECD. *Global Plastics Outlook*. 2022.
9. UNEP. *Beat Plastic Pollution*. https://www.unep.org/interactives/beat-plastic-pollution/
10. Pew Charitable Trusts & SYSTEMIQ. *Breaking the Plastic Wave*. 2020.

## Appendix: reproducing the results

```powershell
C:\src\venvs\plasticlens\Scripts\Activate.ps1
cd ai_model\preprocessing; python download.py; python prepare.py; python split.py
cd ..\training;   python train.py --workers 0
cd ..\evaluation; python evaluate.py; python scenarios.py
cd ..\export;     python to_onnx.py; python verify_onnx.py
cd ..\..\android_app; flutter test; flutter build apk --release --split-per-abi
```
