"""PyTorch dataset and transforms for PlasticLens.

Inference preprocessing (EVAL_TF) must stay identical to the app's
ClassifierService: EXIF-rotate, RGB, bilinear resize straight to 224x224
(no crop), scale to [0, 1], ImageNet mean/std, NCHW.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import torch
from PIL import Image, ImageOps
from torch.utils.data import Dataset
from torchvision import transforms as T

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "preprocessing"))
from common import CLASSES, PROCESSED  # noqa: E402

INPUT_SIZE = 224
MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)

EVAL_TF = T.Compose([
    T.Resize((INPUT_SIZE, INPUT_SIZE), interpolation=T.InterpolationMode.BILINEAR),
    T.ToTensor(),
    T.Normalize(MEAN, STD),
])

# Realistic augmentation only: framing, flips, small rotations, lighting.
TRAIN_TF = T.Compose([
    T.RandomResizedCrop(INPUT_SIZE, scale=(0.55, 1.0), ratio=(0.75, 1.33)),
    T.RandomHorizontalFlip(),
    T.RandomRotation(15, fill=(124, 116, 104)),
    T.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.2, hue=0.02),
    T.RandomGrayscale(p=0.03),
    T.ToTensor(),
    T.Normalize(MEAN, STD),
])


def load_image(path) -> Image.Image:
    with Image.open(path) as im:
        return ImageOps.exif_transpose(im).convert("RGB")


def read_split(split: str, root: Path = PROCESSED) -> list[tuple[Path, int]]:
    with (root / "splits.csv").open() as f:
        return [(root / r["path"], CLASSES.index(r["label"]))
                for r in csv.DictReader(f) if r["split"] == split]


class PlasticDataset(Dataset):
    def __init__(self, split: str, transform=None, root: Path = PROCESSED):
        self.items = read_split(split, root)
        self.transform = transform or (TRAIN_TF if split == "train" else EVAL_TF)

    def __len__(self):
        return len(self.items)

    def __getitem__(self, i):
        path, label = self.items[i]
        return self.transform(load_image(path)), label

    def class_counts(self) -> torch.Tensor:
        counts = torch.zeros(len(CLASSES))
        for _, y in self.items:
            counts[y] += 1
        return counts
