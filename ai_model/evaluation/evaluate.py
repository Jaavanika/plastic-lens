"""Calibrate and evaluate a trained PlasticLens checkpoint.

1. Validation set: fit a temperature T (minimise NLL), measure ECE before
   and after, and choose the High / Medium confidence thresholds.
2. Test set (used once, for the final report): accuracy, per-class
   precision / recall / F1, confusion matrix, plastic-vs-non-plastic
   metrics, ECE, and how the threshold policy behaves.

Writes models/labels.json (consumed by the app), models/<run>_metrics.json
and documentation/figures/confusion_matrix.png.

    python ai_model/evaluation/evaluate.py --run mobilenetv3_v1
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import timm
import torch
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from torch.utils.data import DataLoader

AI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AI / "training"))
from dataset import CLASSES, INPUT_SIZE, MEAN, STD, PlasticDataset  # noqa: E402

MODELS = AI / "models"
FIGURES = AI.parent / "documentation" / "figures"
NON_PLASTIC = CLASSES.index("non_plastic")

# Target accuracy of the predictions shown at each level (README §7.5).
HIGH_TARGET = 0.95
MEDIUM_TARGET = 0.85


def load_model(run: str):
    ckpt = torch.load(MODELS / f"{run}.pt", map_location="cpu", weights_only=False)
    assert ckpt["classes"] == CLASSES, "class order changed since training"
    model = timm.create_model(ckpt["model_name"], pretrained=False, num_classes=len(CLASSES))
    model.load_state_dict(ckpt["state_dict"])
    return model.eval(), ckpt


@torch.no_grad()
def logits_for(model, split):
    # No worker processes: on low-RAM Windows machines they exhaust the page file.
    dl = DataLoader(PlasticDataset(split), batch_size=64, num_workers=0)
    out, ys = [], []
    for x, y in dl:
        out.append(model(x))
        ys.append(y)
    return torch.cat(out), torch.cat(ys)


def fit_temperature(logits, y):
    log_t = torch.zeros(1, requires_grad=True)
    opt = torch.optim.LBFGS([log_t], lr=0.1, max_iter=200)

    def closure():
        opt.zero_grad()
        loss = torch.nn.functional.cross_entropy(logits / log_t.exp(), y)
        loss.backward()
        return loss

    opt.step(closure)
    return float(log_t.exp())


def ece(probs, y, bins=15):
    conf, pred = probs.max(1)
    correct = (pred == y).float()
    edges = torch.linspace(0, 1, bins + 1)
    total = 0.0
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (conf > lo) & (conf <= hi)
        if m.any():
            total += m.float().mean() * (conf[m].mean() - correct[m].mean()).abs()
    return float(total)


def pick_threshold(conf, correct, target, floor=0.30):
    """Lowest threshold whose selected predictions reach `target` accuracy."""
    for t in np.arange(floor, 0.995, 0.01):
        sel = conf >= t
        if sel.sum() >= 10 and correct[sel].mean() >= target:
            return round(float(t), 2)
    return 0.99


def policy_report(probs, y, high, medium):
    conf, pred = probs.max(1)
    conf, pred, y = conf.numpy(), pred.numpy(), y.numpy()
    nonp = pred == NON_PLASTIC
    hi = ~nonp & (conf >= high)
    med = ~nonp & (conf >= medium) & (conf < high)
    low = ~nonp & (conf < medium)

    def bucket(mask):
        return {"share": float(mask.mean()), "accuracy": float((pred[mask] == y[mask]).mean()) if mask.any() else None}

    return {"non_plastic": bucket(nonp), "high": bucket(hi), "medium": bucket(med), "low": bucket(low)}


def plot_confusion(cm, path, title):
    fig, ax = plt.subplots(figsize=(7, 6))
    norm = cm / cm.sum(1, keepdims=True)
    ax.imshow(norm, cmap="Greens", vmin=0, vmax=1)
    ax.set_xticks(range(len(CLASSES)), CLASSES, rotation=45, ha="right")
    ax.set_yticks(range(len(CLASSES)), CLASSES)
    for i in range(len(CLASSES)):
        for j in range(len(CLASSES)):
            ax.text(j, i, cm[i, j], ha="center", va="center", color="white" if norm[i, j] > 0.5 else "black", fontsize=9)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("True")
    ax.set_title(title)
    fig.tight_layout()
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, dpi=110)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--run", default="mobilenetv3_v1")
    p.add_argument("--version", default="mobilenetv3-v1")
    p.add_argument("--primary", action=argparse.BooleanOptionalAction, default=None,
                   help="write models/labels.json (default: only for mobilenetv3_v1)")
    args = p.parse_args()
    if args.primary is None:
        args.primary = args.run == "mobilenetv3_v1"

    model, ckpt = load_model(args.run)

    # ---- validation: calibration + thresholds ----
    val_logits, val_y = logits_for(model, "val")
    T = fit_temperature(val_logits, val_y)
    val_raw = val_logits.softmax(1)
    val_cal = (val_logits / T).softmax(1)
    conf, pred = val_cal.max(1)
    correct = (pred == val_y).numpy()
    plastic = (pred != NON_PLASTIC).numpy()
    high = pick_threshold(conf.numpy()[plastic], correct[plastic], HIGH_TARGET)
    medium = min(pick_threshold(conf.numpy()[plastic], correct[plastic], MEDIUM_TARGET), high)

    # ---- test: used once for the final numbers ----
    test_logits, test_y = logits_for(model, "test")
    test_cal = (test_logits / T).softmax(1)
    test_pred = test_cal.argmax(1)
    yt, yp = test_y.numpy(), test_pred.numpy()
    report = classification_report(yt, yp, labels=list(range(len(CLASSES))), target_names=CLASSES,
                                   output_dict=True, zero_division=0)
    cm = confusion_matrix(yt, yp, labels=list(range(len(CLASSES))))
    plot_confusion(cm, FIGURES / "confusion_matrix.png", f"{args.version}: test set (n={len(yt)})")

    is_np_true, is_np_pred = yt == NON_PLASTIC, yp == NON_PLASTIC
    gate = {
        "plastic_detected_recall": float((~is_np_pred[~is_np_true]).mean()),
        "non_plastic_recall": float(is_np_pred[is_np_true].mean()),
        "non_plastic_precision": float(is_np_true[is_np_pred].mean()) if is_np_pred.any() else None,
    }
    polymer_mask = ~is_np_true
    size_mb = (MODELS / f"{args.run}.pt").stat().st_size / 1e6

    metrics = {
        "model_version": args.version,
        "architecture": ckpt["model_name"],
        "best_epoch": ckpt["epoch"],
        "val_at_best_epoch": ckpt["val"],
        "temperature": T,
        "thresholds": {"high": high, "medium": medium, "high_target_acc": HIGH_TARGET, "medium_target_acc": MEDIUM_TARGET},
        "val_ece": {"before": ece(val_raw, val_y), "after": ece(val_cal, val_y)},
        "test": {
            "n": int(len(yt)),
            "accuracy": float((yt == yp).mean()),
            "macro_f1": float(f1_score(yt, yp, average="macro")),
            "polymer_only_accuracy": float((yt[polymer_mask] == yp[polymer_mask]).mean()),
            "ece_before": ece(test_logits.softmax(1), test_y),
            "ece_after": ece(test_cal, test_y),
            "per_class": {c: {k: report[c][k] for k in ("precision", "recall", "f1-score", "support")} for c in CLASSES},
            "confusion_matrix": cm.tolist(),
            "plastic_gate": gate,
            "policy": policy_report(test_cal, test_y, high, medium),
        },
        "checkpoint_mb": round(size_mb, 1),
    }
    (MODELS / f"{args.run}_metrics.json").write_text(json.dumps(metrics, indent=2))

    labels = {
        "model_version": args.version,
        "classes": CLASSES,
        "temperature": round(T, 4),
        "thresholds": {"high": high, "medium": medium},
        "input": {"size": INPUT_SIZE, "layout": "NCHW", "mean": MEAN, "std": STD,
                  "resize": "bilinear, straight to size x size (no crop), after EXIF rotation"},
    }
    (MODELS / f"{args.run}_labels.json").write_text(json.dumps(labels, indent=2))
    if args.primary:  # only the shipped model defines the app's labels.json
        (MODELS / "labels.json").write_text(json.dumps(labels, indent=2))

    t = metrics["test"]
    print(f"temperature {T:.3f} | val ECE {metrics['val_ece']['before']:.3f} -> {metrics['val_ece']['after']:.3f}")
    print(f"thresholds high {high} medium {medium}")
    print(f"TEST acc {t['accuracy']:.3f} macro-F1 {t['macro_f1']:.3f} ECE {t['ece_after']:.3f}")
    print(classification_report(yt, yp, target_names=CLASSES, digits=3, zero_division=0))
    print("plastic gate:", gate)
    print("policy:", json.dumps(t["policy"]))


if __name__ == "__main__":
    main()
