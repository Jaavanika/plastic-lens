"""Image test scenarios (identification spec §15.2) on the held-out test images.

Each scenario transforms the test images, or selects a subset of them, and
reports accuracy plus how the app's threshold policy reacts. A robust app
should become *unsure* rather than confidently wrong.

Scenarios without the user's own photos are simulated; photograph real
items for the final report (PLAN Section 11).

    python ai_model/evaluation/scenarios.py
"""

from __future__ import annotations

import csv
import io
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

AI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AI / "training"))
sys.path.insert(0, str(AI / "preprocessing"))
from common import PROCESSED, PWDB, pwdb_dirs  # noqa: E402
from dataset import CLASSES, EVAL_TF, load_image, read_split  # noqa: E402

MODELS = AI / "models"
NON_PLASTIC = CLASSES.index("non_plastic")


def jpeg(im, q):
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=q)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


TRANSFORMS = {
    "baseline (test set as-is)": lambda im: im,
    "low light (35 % brightness)": lambda im: ImageEnhance.Brightness(im).enhance(0.35),
    "very low light (15 %)": lambda im: ImageEnhance.Brightness(im).enhance(0.15),
    "blurred (Gaussian r=3)": lambda im: im.filter(ImageFilter.GaussianBlur(3)),
    "motion-like blur (box r=6)": lambda im: im.filter(ImageFilter.BoxBlur(6)),
    "heavy JPEG (quality 10)": lambda im: jpeg(im, 10),
    "rotated 90°": lambda im: im.rotate(90, expand=True),
    "overexposed (180 % brightness)": lambda im: ImageEnhance.Brightness(im).enhance(1.8),
    "greyscale": lambda im: ImageOps.grayscale(im).convert("RGB"),
}


def main():
    labels = json.loads((MODELS / "labels.json").read_text())
    high, medium = labels["thresholds"]["high"], labels["thresholds"]["medium"]
    sess = ort.InferenceSession(str(MODELS / "plasticlens.onnx"), providers=["CPUExecutionProvider"])
    test = read_split("test")
    images = [(load_image(p), y, p) for p, y in test]

    def run(pairs):
        n = len(pairs)
        correct = confident_wrong = unsure = 0
        for im, y in pairs:
            probs = sess.run(["probs"], {"input": EVAL_TF(im).unsqueeze(0).numpy()})[0][0]
            top = int(probs.argmax())
            ok = top == y
            correct += ok
            is_high = top == NON_PLASTIC or probs[top] >= high
            unsure += (top != NON_PLASTIC and probs[top] < high)
            confident_wrong += (is_high and not ok)
        return {"n": n, "accuracy": correct / n, "shown_as_unsure": unsure / n, "confident_and_wrong": confident_wrong / n}

    results = {}
    for name, fn in TRANSFORMS.items():
        results[name] = run([(fn(im), y) for im, y, _ in images])
        print(f"{name:<34} {results[name]}")

    # Subsets by appearance.
    def brightness(im):
        return np.asarray(ImageOps.grayscale(im), dtype=np.float32).mean() / 255

    dark = [(im, y) for im, y, _ in images if y != NON_PLASTIC and brightness(im) < 0.30]
    results["dark plastics (mean brightness < 0.30)"] = run(dark)
    clear_pet = [(im, y) for im, y, _ in images if CLASSES[y] == "PET"]
    results["PET (mostly transparent bottles)"] = run(clear_pet)
    nonp = [(im, y) for im, y, _ in images if y == NON_PLASTIC]
    results["non-plastic objects"] = run(nonp)

    # Multiple objects: whole, uncropped test photos that contain 2+ boxes.
    with (PROCESSED / "manifest.csv").open() as f:
        manifest = {r["path"]: r for r in csv.DictReader(f)}
    test_sources = {manifest[p.relative_to(PROCESSED).as_posix()]["source_image"] for p, _ in test}
    multi = []
    for src in sorted(test_sources):
        if not src.startswith("PlasticWaste-DB/"):
            continue
        _, cls, name = src.split("/")
        img_dir, lbl_dir = pwdb_dirs(cls)
        lbl = lbl_dir / (Path(name).stem + ".txt")
        if lbl.exists() and len([l for l in lbl.read_text().splitlines() if l.strip()]) >= 2:
            with Image.open(img_dir / name) as raw:
                im = ImageOps.exif_transpose(raw).convert("RGB")
                im.thumbnail((768, 768))
                multi.append((im.copy(), CLASSES.index(cls)))
    results["multiple objects (whole photo, 2+ items)"] = run(multi)

    for name in list(results)[len(TRANSFORMS):]:
        print(f"{name:<34} {results[name]}")
    (MODELS / "scenario_results.json").write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
