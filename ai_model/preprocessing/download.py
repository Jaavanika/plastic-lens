"""Download the raw datasets used by PlasticLens.

- PlasticWaste-DB (CC BY 4.0), Mendeley Data tvfx5dspf3 v1: six polymer
  classes, one folder per class with images/ and YOLO labels/.
- TrashNet (MIT), github.com/garythung/trashnet: used only for the
  non-plastic class (glass, paper, cardboard, metal).

Files land in ai_model/datasets/raw/ (not committed). Each PlasticWaste-DB
file is checked against the SHA-256 published by Mendeley, and files that
are already present and valid are skipped, so the script can be re-run.

Usage:
    python ai_model/preprocessing/download.py
"""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from tqdm import tqdm

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "datasets" / "raw"

MENDELEY_API = "https://data.mendeley.com/public-api/datasets/tvfx5dspf3"
MENDELEY_VERSION = 1
TRASHNET_ZIP = "https://github.com/garythung/trashnet/raw/master/data/dataset-resized.zip"


# Mendeley rejects urllib's default User-Agent with 403.
HEADERS = {"User-Agent": "PlasticLens-dataset-downloader/1.0"}


def get_json(url: str):
    req = urllib.request.Request(url, headers={**HEADERS, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def download_to(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=120) as resp, dest.open("wb") as out:
        while chunk := resp.read(1 << 20):
            out.write(chunk)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def list_mendeley_files() -> list[tuple[Path, str, str]]:
    """Return (relative path, download url, sha256) for every dataset file."""
    folders = get_json(f"{MENDELEY_API}/folders/{MENDELEY_VERSION}")
    by_id = {f["id"]: f for f in folders}

    def folder_path(fid: str) -> Path:
        parts = []
        while fid:
            node = by_id[fid]
            parts.append(node["name"])
            fid = node.get("parent_id")
        return Path(*reversed(parts))

    entries = []
    for fid in by_id:
        files = get_json(
            f"{MENDELEY_API}/files?folder_id={fid}&version={MENDELEY_VERSION}"
        )
        for f in files:
            cd = f["content_details"]
            entries.append(
                (folder_path(fid) / f["filename"], cd["download_url"], cd["sha256_hash"])
            )
    return entries


def fetch(rel: Path, url: str, digest: str) -> str:
    dest = RAW / rel
    if dest.exists() and sha256(dest) == digest:
        return "skipped"
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    download_to(url, tmp)
    if sha256(tmp) != digest:
        tmp.unlink()
        raise RuntimeError(f"checksum mismatch: {rel}")
    tmp.replace(dest)
    return "downloaded"


def download_plasticwaste() -> None:
    entries = list_mendeley_files()
    print(f"PlasticWaste-DB: {len(entries)} files")
    failures = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(fetch, *e): e[0] for e in entries}
        for fut in tqdm(as_completed(futures), total=len(futures)):
            try:
                fut.result()
            except Exception as exc:  # keep going; report at the end
                failures.append((futures[fut], exc))
    if failures:
        for rel, exc in failures:
            print(f"FAILED {rel}: {exc}", file=sys.stderr)
        sys.exit(f"{len(failures)} files failed; re-run to retry")


def download_trashnet() -> None:
    out = RAW / "trashnet"
    if (out / "dataset-resized").exists():
        print("TrashNet: already extracted")
        return
    out.mkdir(parents=True, exist_ok=True)
    zpath = out / "dataset-resized.zip"
    if not zpath.exists():
        print("TrashNet: downloading")
        download_to(TRASHNET_ZIP, zpath)
    with zipfile.ZipFile(zpath) as z:
        for member in z.namelist():
            # Refuse entries that would escape the target directory.
            target = (out / member).resolve()
            if not str(target).startswith(str(out.resolve())):
                raise RuntimeError(f"unsafe path in zip: {member}")
        z.extractall(out)
    print("TrashNet: extracted")


if __name__ == "__main__":
    download_plasticwaste()
    download_trashnet()
