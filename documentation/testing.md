# PlasticLens test record

Last full run: 14 November 2026. Device: Pixel 7 emulator, Android 36 (x86_64).

## Automated test suites

| Suite | Command | Result |
| --- | --- | --- |
| Flutter unit + widget (`android_app/test/`) | `flutter test` | 32 passed |
| On-device model parity, airplane mode (`android_app/integration_test/`) | `flutter test integration_test/classifier_parity_test.dart -d <device>` | 1 passed (7 images) |
| Firestore + Storage security rules (`firebase/tests/`) | `npm run test:rules` | 9 passed |
| Backend API (`backend/tests/`) | `pytest` | 21 passed |
| Model: ONNX vs PyTorch (`ai_model/export/verify_onnx.py`) | | max diff 4.0e-6, 0 mismatches |
| Model: test-set evaluation and scenarios | `evaluate.py`, `scenarios.py` | see `model_card.md` |
| Static analysis | `flutter analyze` | no issues |

## identification spec §15.3 application tests

| Requirement | How it was tested | Result |
| --- | --- | --- |
| Camera and gallery permission handling | Emulator: allowed camera → live preview; revoked and denied → message with "Allow camera" and "Choose from gallery". Gallery uses the Android photo picker (no permission needed). | ✅ (after fixing a hang on resume) |
| Invalid image handling | `validateImageFile` (type, empty, > 20 MB); `preprocessBytes` rejects non-images and images < 64 px (`preprocess_parity_test.dart`); backend rejects non-images (415) and > 5 MB (413) | ✅ |
| Offline scanning | Integration test with airplane mode on; release APK scan on the emulator | ✅ |
| Cloud synchronisation | `sync_test.dart` (fake Firestore): offline scans sync once online, no duplicates, edits overwrite, offline deletes applied later, new phone pulls remote scans. **Live project (17 Nov 2026):** scan synced; local data wiped; sign-in restored the scan | ✅ |
| Authentication and access control | `rules.test.js`: owner-only scans and progress, validated fields, admin-only content, feedback ownership, Storage owner-only, size and type limits; backend token and admin checks (`test_api.py`); first-launch sign-in / guest flow (`widget_test.dart`). **Live:** email sign-up, sign-in, sign-out, account deletion (the account can no longer sign in) | ✅ (Google sign-in to check on a phone) |
| Scan history persistence | SQLite storage on the device (scan survived an app restart on the emulator); history search and filter widget test | ✅ |
| Image deletion | Delete scan (result screen, swipe in history); "Delete data on this phone" removes the DB and the `scans/` folder; account deletion removes Firestore docs and Storage images (`sync_test.dart`) | ✅ |
| Model loading failures | `OnnxClassifier.warmUp` surfaces `ClassifierException` on the preview screen and retries on the next scan; corrupt input images are handled in preprocessing | ✅ code path · manual fault injection not done |
| Low-memory devices | Preprocessing runs in an isolate; photos capped at 2000 px by the picker and 720p by the camera; model loaded once (17 MB) | ⏳ needs a low-end phone |
| Different Android screen sizes | Widget tests at phone size; emulator portrait and landscape (no crash, layout scrolls) | ✅ emulator · ⏳ tablet / small phone |

## identification spec §15.4 website tests

| Requirement | Result |
| --- | --- |
| Lighthouse (performance, accessibility, best practices, SEO) | 100 / 100 / 100 / 100 on mobile and desktop |
| Layout at phone (360 px), tablet, desktop | 360 px emulated viewport: menu collapses, no overflow; tablet and desktop grids by CSS breakpoints |
| All download links work | Points to GitHub Releases. ⏳ Works once the v1.0.0 release is published |

## Bugs found and fixed during testing

1. Camera screen stuck on a spinner after the user denied the permission, because the permission dialog's pause/resume restarted the camera mid-request. Fixed with an explicit permission request, a single-start guard, and restarting on resume only if the camera had been running.
2. App stuck on the splash screen without Firebase config: `Firebase.initializeApp()` never completes on Android when `google-services.json` is missing. Fixed with a native check (`plasticlens/config` channel) before initialising.
3. Release and test builds failed because the `onnxruntime` plugin compiles against SDK 33 while the AndroidX dependencies need 34+. Fixed by compiling all plugin modules against SDK 37.
4. The ONNX plugin bundles only ARM libraries, so it could not run on x86_64 emulators. Fixed by adding the official `onnxruntime-android:1.15.1` AAR.
5. Dart preprocessing differed from Python by up to ~37 grey levels in textured areas. Fixed by porting Pillow's antialiased bilinear resize; now within ~4 grey levels.
6. Pydantic accepted `"yes"` as a boolean in LLM output. Fixed with strict validation.
7. Account deletion failed on the live project because it always called Cloud Storage, which is not enabled on the Spark plan. Fixed: Storage is used only if photos were ever backed up, and photos are deleted first (regression test in `sync_test.dart`).
8. Firebase refuses to delete accounts without a recent sign-in, *after* the app had already deleted the cloud data. Fixed: the app checks the sign-in age first and asks the user to sign in again.
9. After sign-up the profile showed the email instead of the name. Fixed by refreshing the user after the name is saved.

## Still to do on physical phones (PLAN Section 11)

- [ ] Install the arm64 release APK on 2 phones; scan real items (one per polymer plus non-plastic).
- [ ] Record per-scan latency (Profile → About shows the last scan's time).
- [ ] Photograph the identification spec §15.2 scenarios (crushed bottle, bag, dark container, white tub, several items, low light, blur) and note the results here.
- [ ] With Firebase connected: sign up, scan offline, reconnect, and check Firestore; delete the account.
