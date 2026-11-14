"""Inspect the raw datasets: counts, corrupt files, image sizes, labels.

Writes documentation/figures/raw_samples.png and prints a summary table.

    python ai_model/preprocessing/inspect_data.py
"""

from __future__ import annotations

import random
import statistics
from collections import Counter

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from PIL import Image

from common import DOCS, IMAGE_EXTS, POLYMERS, TRASHNET, TRASHNET_NON_PLASTIC, pwdb_dirs


def check_image(path):
    try:
        with Image.open(path) as im:
            im.verify()
        with Image.open(path) as im:
            return im.size
    except Exception:
        return None


def main() -> None:
    rows = []
    samples = []
    for cls in POLYMERS:
        img_dir, lbl_dir = pwdb_dirs(cls)
        images = sorted(p for p in img_dir.iterdir() if p.suffix.lower() in IMAGE_EXTS)
        sizes, corrupt, no_label, boxes = [], [], [], Counter()
        for p in images:
            size = check_image(p)
            if size is None:
                corrupt.append(p.name)
                continue
            sizes.append(size)
            lbl = lbl_dir / (p.stem + ".txt")
            if not lbl.exists():
                no_label.append(p.name)
            else:
                lines = [l for l in lbl.read_text().splitlines() if l.strip()]
                boxes[len(lines)] += 1
        widths = [w for w, _ in sizes]
        heights = [h for _, h in sizes]
        rows.append((cls, len(images), len(corrupt), len(no_label), dict(sorted(boxes.items())),
                     f"{statistics.median(widths)}x{statistics.median(heights)}" if sizes else "-"))
        samples += [(cls, p) for p in random.Random(0).sample(images, 4)]

    for cls in TRASHNET_NON_PLASTIC:
        folder = TRASHNET / cls
        images = sorted(p for p in folder.iterdir() if p.suffix.lower() in IMAGE_EXTS)
        corrupt = [p.name for p in images if check_image(p) is None]
        rows.append((f"trashnet/{cls}", len(images), len(corrupt), "-", "-", "512x384"))
        samples.append(("non_plastic", random.Random(0).choice(images)))

    print(f"{'class':<20}{'images':>8}{'corrupt':>9}{'no label':>10}  boxes/image   median size")
    for cls, n, bad, nolab, bx, med in rows:
        print(f"{cls:<20}{n:>8}{bad:>9}{str(nolab):>10}  {str(bx):<13} {med}")

    fig, axes = plt.subplots(4, 7, figsize=(14, 8))
    for ax in axes.flat:
        ax.axis("off")
    for i, (cls, p) in enumerate(samples[:28]):
        ax = axes.flat[i]
        with Image.open(p) as im:
            im.thumbnail((256, 256))
            ax.imshow(im)
        ax.set_title(cls, fontsize=9)
    out = DOCS / "figures" / "raw_samples.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out, dpi=80)
    print(f"samples -> {out}")


if __name__ == "__main__":
    main()
