"""Grouped, stratified 70/15/15 split of the processed dataset.

Groups from prepare.py (same source photo or visually near-identical)
never cross splits. Also runs the Section 2 checks:
  - every image opens and has exactly one label;
  - no group and no near-duplicate image appears in two splits.

Output: datasets/processed/splits.csv and datasets/processed/stats.json

    python ai_model/preprocessing/split.py
"""

from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict

import numpy as np
from PIL import Image
from sklearn.model_selection import StratifiedGroupKFold

from common import CLASSES, PROCESSED

N_FOLDS = 20  # 3 folds test, 3 folds val, 14 folds train = 15/15/70
SEED = 42
DUP_DIST = 4


def assign_splits(rows):
    y = [r["label"] for r in rows]
    groups = [r["group"] for r in rows]
    sgkf = StratifiedGroupKFold(n_splits=N_FOLDS, shuffle=True, random_state=SEED)
    split = [None] * len(rows)
    for fold, (_, idx) in enumerate(sgkf.split(np.zeros(len(rows)), y, groups)):
        name = "test" if fold < 3 else "val" if fold < 6 else "train"
        for i in idx:
            split[i] = name
    for r, s in zip(rows, split):
        r["split"] = s


def verify(rows):
    errors = []
    labels_per_path = defaultdict(set)
    for r in rows:
        labels_per_path[r["path"]].add(r["label"])
        try:
            with Image.open(PROCESSED / r["path"]) as im:
                im.verify()
        except Exception as e:
            errors.append(f"cannot open {r['path']}: {e}")
        if r["label"] not in CLASSES:
            errors.append(f"unknown label {r['label']} for {r['path']}")
    errors += [f"{p} has labels {ls}" for p, ls in labels_per_path.items() if len(ls) != 1]

    group_splits = defaultdict(set)
    for r in rows:
        group_splits[r["group"]].add(r["split"])
    errors += [f"group {g} in {s}" for g, s in group_splits.items() if len(s) > 1]

    hashes = np.array([int(r["phash"], 16) for r in rows], dtype=np.uint64)
    splits = np.array([r["split"] for r in rows])
    for i in range(len(rows)):
        d = np.bitwise_count(hashes[i] ^ hashes[i + 1:])
        for off in np.nonzero((d <= DUP_DIST) & (splits[i + 1:] != splits[i]))[0]:
            errors.append(f"near-duplicate across splits: {rows[i]['path']} / {rows[i + 1 + off]['path']}")
    return errors


def main():
    with (PROCESSED / "manifest.csv").open() as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r["group"] = int(r["group"])
    assign_splits(rows)

    errors = verify(rows)
    if errors:
        print("\n".join(errors[:50]))
        raise SystemExit(f"{len(errors)} verification errors")

    with (PROCESSED / "splits.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["path", "label", "split", "group", "source"])
        w.writeheader()
        for r in rows:
            w.writerow({k: r[k] for k in w.fieldnames})

    table = {c: Counter() for c in CLASSES}
    for r in rows:
        table[r["label"]][r["split"]] += 1
    stats = {
        "total": len(rows),
        "groups": len({r["group"] for r in rows}),
        "per_class": {c: {s: table[c][s] for s in ("train", "val", "test")} for c in CLASSES},
    }
    (PROCESSED / "stats.json").write_text(json.dumps(stats, indent=2))

    print(f"{'class':<12}{'train':>7}{'val':>6}{'test':>6}{'total':>7}")
    for c in CLASSES:
        t = table[c]
        print(f"{c:<12}{t['train']:>7}{t['val']:>6}{t['test']:>6}{sum(t.values()):>7}")
    tot = Counter(r["split"] for r in rows)
    print(f"{'all':<12}{tot['train']:>7}{tot['val']:>6}{tot['test']:>6}{len(rows):>7}")
    print("verification passed: all images open, one label each, no group or near-duplicate crosses splits")


if __name__ == "__main__":
    main()
