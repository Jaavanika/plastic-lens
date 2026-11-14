"""Shared paths and constants for the PlasticLens data pipeline."""

from pathlib import Path

AI_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = AI_ROOT.parent
RAW = AI_ROOT / "datasets" / "raw"
PROCESSED = AI_ROOT / "datasets" / "processed"
DOCS = REPO_ROOT / "documentation"

PWDB = RAW / "PlasticWaste-DB"
TRASHNET = RAW / "trashnet" / "dataset-resized"

# Class index order is fixed: it defines the model's output layer.
CLASSES = ["PET", "HDPE", "PVC", "LDPE", "PP", "PS", "non_plastic"]
POLYMERS = CLASSES[:6]
TRASHNET_NON_PLASTIC = ["glass", "paper", "cardboard", "metal"]

IMAGE_EXTS = {".jpg", ".jpeg", ".png"}


def pwdb_dirs(polymer: str) -> tuple[Path, Path]:
    """images/ and labels/ folders for one PlasticWaste-DB class."""
    base = PWDB / polymer / polymer
    return base / "images", base / "labels"
