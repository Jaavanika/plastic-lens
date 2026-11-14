"""Check that the ONNX model matches PyTorch, and write app parity fixtures.

- 100 test images: max |p_torch - p_onnx| < 1e-4 and identical top-1.
- ONNX CPU latency on this PC (the phone figure is measured in the app).
- android_app/test/fixtures/parity.json: for a few test images, the
  preprocessed-tensor statistics and expected top-1, so the Dart
  preprocessing can be checked against Python in `flutter test`.

    python ai_model/export/verify_onnx.py --run mobilenetv3_v1
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import sys
import time
from pathlib import Path

import numpy as np
import onnxruntime as ort
import torch

AI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AI / "evaluation"))
sys.path.insert(0, str(AI / "training"))
from dataset import CLASSES, EVAL_TF, load_image, read_split  # noqa: E402
from evaluate import load_model  # noqa: E402

MODELS = AI / "models"
FIXTURES = AI.parent / "android_app" / "test" / "fixtures"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--run", default="mobilenetv3_v1")
    p.add_argument("--n", type=int, default=100)
    args = p.parse_args()

    labels = json.loads((MODELS / "labels.json").read_text())
    model, _ = load_model(args.run)
    T = labels["temperature"]
    sess = ort.InferenceSession(str(MODELS / "plasticlens.onnx"), providers=["CPUExecutionProvider"])

    items = read_split("test")
    random.Random(0).shuffle(items)
    items = items[: args.n]

    max_diff, mismatches, times = 0.0, 0, []
    for path, _ in items:
        x = EVAL_TF(load_image(path)).unsqueeze(0)
        with torch.no_grad():
            pt = torch.softmax(model(x) / T, 1).numpy()
        t0 = time.perf_counter()
        ox = sess.run(["probs"], {"input": x.numpy()})[0]
        times.append((time.perf_counter() - t0) * 1000)
        max_diff = max(max_diff, float(np.abs(pt - ox).max()))
        mismatches += int(pt.argmax() != ox.argmax())

    print(f"{len(items)} images: max |diff| = {max_diff:.2e}, top-1 mismatches = {mismatches}")
    print(f"ONNX CPU latency (this PC): median {np.median(times):.1f} ms")
    ok = max_diff < 1e-4 and mismatches == 0

    # Parity fixtures: one image per class.
    FIXTURES.mkdir(parents=True, exist_ok=True)
    fixtures = []
    seen = set()
    for path, y in read_split("test"):
        if y in seen:
            continue
        seen.add(y)
        x = EVAL_TF(load_image(path)).unsqueeze(0)
        probs = sess.run(["probs"], {"input": x.numpy()})[0][0]
        name = f"{CLASSES[y]}_{path.name}"
        shutil.copy(path, FIXTURES / name)
        arr = x.numpy()[0]
        fixtures.append({
            "file": name,
            "label": CLASSES[y],
            "channel_mean": arr.mean(axis=(1, 2)).tolist(),
            "channel_std": arr.std(axis=(1, 2)).tolist(),
            "samples": {f"{c},{i},{j}": float(arr[c, i, j]) for c, i, j in [(0, 0, 0), (1, 112, 112), (2, 223, 223), (0, 50, 170)]},
            "top1": CLASSES[int(probs.argmax())],
            "probs": probs.tolist(),
        })
    (FIXTURES / "parity.json").write_text(json.dumps(fixtures, indent=2))
    print(f"wrote {len(fixtures)} parity fixtures to {FIXTURES}")

    result = {"n": len(items), "max_abs_diff": max_diff, "top1_mismatches": mismatches,
              "pc_cpu_latency_ms_median": float(np.median(times)), "passed": ok}
    (MODELS / "onnx_verification.json").write_text(json.dumps(result, indent=2))
    if not ok:
        raise SystemExit("ONNX verification FAILED")
    print("ONNX verification passed")


if __name__ == "__main__":
    main()
