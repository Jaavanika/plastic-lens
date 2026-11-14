"""Build the processed classification dataset.

1. PlasticWaste-DB: crop every labelled object (YOLO oriented boxes ->
   axis-aligned box + 10 % margin). Tiny boxes are skipped.
2. non_plastic: a fixed random sample from TrashNet glass/paper/cardboard/metal.
3. Resize so the longest side is 384 px (training uses 224 px crops).
4. Perceptual-hash every image:
   - near-duplicates (Hamming <= DUP_DIST) inside a class: keep the first;
   - near-duplicates with different labels: drop all of them (ambiguous);
   - images within GROUP_DIST, or crops of the same photo, share a group id
     so split.py keeps them in the same split.

Output: datasets/processed/images/<class>/*.jpg and datasets/processed/manifest.csv

    python ai_model/preprocessing/prepare.py
"""

from __future__ import annotations

import csv
import random
import shutil

import imagehash
import numpy as np
from PIL import Image, ImageOps
from tqdm import tqdm

from common import IMAGE_EXTS, POLYMERS, PROCESSED, TRASHNET, TRASHNET_NON_PLASTIC, pwdb_dirs

MAX_SIDE = 384
MARGIN = 0.10
MIN_BOX_PX = 48
NON_PLASTIC_PER_SOURCE = 110  # 4 x 110 = 440, close to the median polymer class
DUP_DIST = 4
GROUP_DIST = 10
SEED = 42


def parse_boxes(label_path, w, h):
    """Return pixel boxes (x0, y0, x1, y1) from a YOLO or YOLO-OBB label file."""
    boxes = []
    for line in label_path.read_text().splitlines():
        vals = line.split()
        if len(vals) == 9:  # class x1 y1 ... x4 y4 (normalised corners)
            xs = [float(v) * w for v in vals[1::2]]
            ys = [float(v) * h for v in vals[2::2]]
            boxes.append((min(xs), min(ys), max(xs), max(ys)))
        elif len(vals) == 5:  # class cx cy bw bh
            cx, cy, bw, bh = (float(v) for v in vals[1:])
            boxes.append(((cx - bw / 2) * w, (cy - bh / 2) * h, (cx + bw / 2) * w, (cy + bh / 2) * h))
    return boxes


def expand(box, w, h):
    x0, y0, x1, y1 = box
    mx, my = (x1 - x0) * MARGIN, (y1 - y0) * MARGIN
    return (max(0, int(x0 - mx)), max(0, int(y0 - my)), min(w, int(x1 + mx)), min(h, int(y1 + my)))


def shrink(im):
    im = im.convert("RGB")
    im.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
    return im


def save(im, cls, name, rows, source, source_image):
    out_dir = PROCESSED / "images" / cls
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.jpg"
    im.save(path, quality=92)
    rows.append({
        "path": path.relative_to(PROCESSED).as_posix(),
        "label": cls,
        "source": source,
        "source_image": source_image,
        "phash": str(imagehash.phash(im)),
        "width": im.width,
        "height": im.height,
    })


def crop_plasticwaste(rows, skipped):
    for cls in POLYMERS:
        img_dir, lbl_dir = pwdb_dirs(cls)
        for p in tqdm(sorted(img_dir.iterdir()), desc=cls):
            if p.suffix.lower() not in IMAGE_EXTS:
                continue
            with Image.open(p) as raw:
                im = ImageOps.exif_transpose(raw)
                w, h = im.size
                boxes = parse_boxes(lbl_dir / f"{p.stem}.txt", w, h)
                for k, box in enumerate(boxes):
                    x0, y0, x1, y1 = expand(box, w, h)
                    if min(x1 - x0, y1 - y0) < MIN_BOX_PX:
                        skipped["tiny box"] += 1
                        continue
                    save(shrink(im.crop((x0, y0, x1, y1))), cls, f"{p.stem}_{k}", rows,
                         "PlasticWaste-DB", f"PlasticWaste-DB/{cls}/{p.name}")


def sample_trashnet(rows):
    rnd = random.Random(SEED)
    for src in TRASHNET_NON_PLASTIC:
        files = sorted(p for p in (TRASHNET / src).iterdir() if p.suffix.lower() in IMAGE_EXTS)
        for p in tqdm(rnd.sample(files, NON_PLASTIC_PER_SOURCE), desc=f"trashnet/{src}"):
            with Image.open(p) as raw:
                save(shrink(ImageOps.exif_transpose(raw)), "non_plastic", f"{src}_{p.stem}", rows,
                     f"TrashNet/{src}", f"TrashNet/{src}/{p.name}")


class UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))

    def find(self, i):
        while self.parent[i] != i:
            self.parent[i] = self.parent[self.parent[i]]
            i = self.parent[i]
        return i

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra


def dedupe_and_group(rows, skipped):
    hashes = np.array([int(r["phash"], 16) for r in rows], dtype=np.uint64)
    n = len(rows)
    drop = set()
    uf = UnionFind(n)

    by_source = {}
    for i, r in enumerate(rows):
        by_source.setdefault(r["source_image"], []).append(i)
    for idx in by_source.values():
        for j in idx[1:]:
            uf.union(idx[0], j)

    for i in range(n):
        dist = np.bitwise_count(hashes[i] ^ hashes[i + 1:])
        for off in np.nonzero(dist <= GROUP_DIST)[0]:
            j = i + 1 + int(off)
            uf.union(i, j)
            if dist[off] <= DUP_DIST and rows[i]["source_image"] != rows[j]["source_image"]:
                if rows[i]["label"] == rows[j]["label"]:
                    drop.add(j)
                    skipped["near-duplicate"] += 1
                else:
                    drop.update((i, j))
                    skipped["conflicting duplicate"] += 1

    roots = {}
    kept = []
    for i, r in enumerate(rows):
        if i in drop:
            (PROCESSED / r["path"]).unlink(missing_ok=True)
            continue
        r["group"] = roots.setdefault(uf.find(i), len(roots))
        kept.append(r)
    return kept


def main():
    if PROCESSED.exists():
        shutil.rmtree(PROCESSED)
    rows, skipped = [], {"tiny box": 0, "near-duplicate": 0, "conflicting duplicate": 0}
    crop_plasticwaste(rows, skipped)
    sample_trashnet(rows)
    kept = dedupe_and_group(rows, skipped)

    with (PROCESSED / "manifest.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(kept[0].keys()))
        writer.writeheader()
        writer.writerows(kept)

    counts = {}
    for r in kept:
        counts[r["label"]] = counts.get(r["label"], 0) + 1
    print("kept per class:", counts)
    print("total:", len(kept), "groups:", len({r['group'] for r in kept}))
    print("skipped:", skipped)


if __name__ == "__main__":
    main()
