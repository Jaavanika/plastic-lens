"""Export the trained checkpoint to ONNX for the Android app.

The graph takes `input` float32[1,3,224,224] (normalised, NCHW) and returns
`probs` float32[1,7] = softmax(logits / T), i.e. calibration is inside
the model, so the app only needs to read the probabilities.

    python ai_model/export/to_onnx.py --run mobilenetv3_v1
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import onnx
import torch
from torch import nn

AI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AI / "evaluation"))
from evaluate import load_model  # noqa: E402

MODELS = AI / "models"
APP_ASSETS = AI.parent / "android_app" / "assets" / "models"


class Calibrated(nn.Module):
    def __init__(self, model, temperature):
        super().__init__()
        self.model = model
        self.register_buffer("inv_t", torch.tensor(1.0 / temperature))

    def forward(self, x):
        return torch.softmax(self.model(x) * self.inv_t, dim=1)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--run", default="mobilenetv3_v1")
    p.add_argument("--opset", type=int, default=17)
    args = p.parse_args()

    labels = json.loads((MODELS / "labels.json").read_text())
    model, _ = load_model(args.run)
    wrapped = Calibrated(model, labels["temperature"]).eval()
    size = labels["input"]["size"]

    out = MODELS / "plasticlens.onnx"
    torch.onnx.export(
        wrapped, torch.zeros(1, 3, size, size), out,
        input_names=["input"], output_names=["probs"],
        opset_version=args.opset, dynamo=False,
    )
    m = onnx.load(out)
    # The Flutter `onnxruntime` plugin ships ORT 1.15, which reads IR <= 9.
    m.ir_version = 8
    onnx.checker.check_model(m)
    m.metadata_props.add(key="model_version", value=labels["model_version"])
    m.metadata_props.add(key="classes", value=",".join(labels["classes"]))
    onnx.save(m, out)

    APP_ASSETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(out, APP_ASSETS / "plasticlens.onnx")
    shutil.copy(MODELS / "labels.json", APP_ASSETS / "labels.json")
    print(f"exported {out} ({out.stat().st_size / 1e6:.1f} MB) and copied to {APP_ASSETS}")


if __name__ == "__main__":
    main()
