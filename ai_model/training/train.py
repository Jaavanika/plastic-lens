"""Fine-tune MobileNetV3-Large on the PlasticLens dataset.

Stage 1 trains only the head (backbone frozen); stage 2 unfreezes the whole
network with a low learning rate. Class-weighted cross-entropy handles the
imbalance (PVC is smallest). Early stopping on validation macro-F1; the best
checkpoint is saved to models/<run>.pt.

    python ai_model/training/train.py                 # CPU, ~1 h
    python ai_model/training/train.py --device cuda   # Colab GPU
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import timm
import torch
from sklearn.metrics import f1_score
from torch import nn
from torch.utils.data import DataLoader

from dataset import CLASSES, PlasticDataset

MODELS = Path(__file__).resolve().parents[1] / "models"


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--model", default="mobilenetv3_large_100")
    p.add_argument("--run", default="mobilenetv3_v1")
    p.add_argument("--epochs-head", type=int, default=4)
    p.add_argument("--epochs-ft", type=int, default=30)
    p.add_argument("--batch", type=int, default=32)
    p.add_argument("--lr-head", type=float, default=1e-3)
    p.add_argument("--lr-ft", type=float, default=3e-4)
    p.add_argument("--weight-decay", type=float, default=1e-4)
    p.add_argument("--patience", type=int, default=7)
    p.add_argument("--workers", type=int, default=3)
    p.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    p.add_argument("--seed", type=int, default=42)
    return p.parse_args()


def evaluate(model, loader, device):
    model.eval()
    ys, ps, loss_sum = [], [], 0.0
    with torch.no_grad():
        for x, y in loader:
            logits = model(x.to(device))
            loss_sum += nn.functional.cross_entropy(logits, y.to(device), reduction="sum").item()
            ys.append(y.numpy())
            ps.append(logits.argmax(1).cpu().numpy())
    y, p = np.concatenate(ys), np.concatenate(ps)
    return {
        "loss": loss_sum / len(y),
        "acc": float((y == p).mean()),
        "macro_f1": float(f1_score(y, p, average="macro")),
    }


def run_epoch(model, loader, criterion, optimizer, scheduler, device):
    model.train()
    total, n = 0.0, 0
    for x, y in loader:
        x, y = x.to(device), y.to(device)
        optimizer.zero_grad(set_to_none=True)
        loss = criterion(model(x), y)
        loss.backward()
        optimizer.step()
        if scheduler is not None:
            scheduler.step()
        total += loss.item() * len(y)
        n += len(y)
    return total / n


def head_parameters(model):
    # timm MobileNetV3: conv_head (1x1 conv to 1280) + classifier form the head.
    return list(model.conv_head.parameters()) + list(model.get_classifier().parameters())


def main():
    args = parse_args()
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    if args.device == "cpu":
        torch.set_num_threads(max(1, torch.get_num_threads()))
    device = torch.device(args.device)

    train_ds, val_ds = PlasticDataset("train"), PlasticDataset("val")
    counts = train_ds.class_counts()
    weights = counts.sum() / (len(CLASSES) * counts)
    print("train counts:", dict(zip(CLASSES, counts.int().tolist())))
    print("class weights:", dict(zip(CLASSES, [round(w, 2) for w in weights.tolist()])))

    loader_kw = dict(num_workers=args.workers, persistent_workers=args.workers > 0)
    train_dl = DataLoader(train_ds, batch_size=args.batch, shuffle=True, drop_last=True, **loader_kw)
    val_dl = DataLoader(val_ds, batch_size=64, **loader_kw)

    model = timm.create_model(args.model, pretrained=True, num_classes=len(CLASSES)).to(device)
    criterion = nn.CrossEntropyLoss(weight=weights.to(device))

    MODELS.mkdir(parents=True, exist_ok=True)
    ckpt_path = MODELS / f"{args.run}.pt"
    history, best_f1, bad_epochs = [], -1.0, 0

    def save(epoch, metrics):
        torch.save({
            "model_name": args.model,
            "classes": CLASSES,
            "state_dict": model.state_dict(),
            "epoch": epoch,
            "val": metrics,
            "args": vars(args),
        }, ckpt_path)

    stages = [("head", args.epochs_head, args.lr_head), ("finetune", args.epochs_ft, args.lr_ft)]
    epoch = 0
    for stage, n_epochs, lr in stages:
        head = set(id(p) for p in head_parameters(model))
        for prm in model.parameters():
            prm.requires_grad = stage == "finetune" or id(prm) in head
        params = [p for p in model.parameters() if p.requires_grad]
        optimizer = torch.optim.AdamW(params, lr=lr, weight_decay=args.weight_decay)
        scheduler = torch.optim.lr_scheduler.OneCycleLR(
            optimizer, max_lr=lr, total_steps=n_epochs * len(train_dl), pct_start=0.15)
        bad_epochs = 0
        for _ in range(n_epochs):
            epoch += 1
            t0 = time.time()
            train_loss = run_epoch(model, train_dl, criterion, optimizer, scheduler, device)
            val = evaluate(model, val_dl, device)
            row = {"epoch": epoch, "stage": stage, "train_loss": train_loss, **{f"val_{k}": v for k, v in val.items()},
                   "seconds": round(time.time() - t0, 1)}
            history.append(row)
            improved = val["macro_f1"] > best_f1
            if improved:
                best_f1 = val["macro_f1"]
                bad_epochs = 0
                save(epoch, val)
            else:
                bad_epochs += 1
            print(f"[{stage}] epoch {epoch:2d} loss {train_loss:.3f} | val acc {val['acc']:.3f} "
                  f"f1 {val['macro_f1']:.3f} loss {val['loss']:.3f} | {row['seconds']}s{'  *' if improved else ''}",
                  flush=True)
            if stage == "finetune" and bad_epochs >= args.patience:
                print(f"early stop: no val F1 improvement for {args.patience} epochs")
                break

    (MODELS / f"{args.run}_history.json").write_text(json.dumps(history, indent=2))
    print(f"best val macro-F1 {best_f1:.4f} -> {ckpt_path}")


if __name__ == "__main__":
    main()
