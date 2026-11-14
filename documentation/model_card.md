# PlasticLens model card

## 1. Dataset

### Sources

| Source | Use | Licence | Citation |
| --- | --- | --- | --- |
| PlasticWaste-DB v1 (Mendeley Data `tvfx5dspf3`) | Six polymer classes (PET, HDPE, PVC, LDPE, PP, PS) | CC BY 4.0 | Sarkar, S. C., Bushra, J. J., Hossain, M. S. *PlasticWaste-DB*, Mendeley Data, v1, doi:10.17632/tvfx5dspf3.1 |
| TrashNet (`garythung/trashnet`, `dataset-resized`) | `non_plastic` class (glass, paper, cardboard, metal) | MIT | Thung, G., Yang, M. *Classification of Trash for Recyclability Status*, 2016 |

Changes made to the data, as required by CC BY 4.0: objects were cropped from the
photos using the published bounding boxes, images were resized, and
near-duplicates were removed. The app's About screen credits both datasets.

### Raw data inspection (`preprocessing/inspect_data.py`)

| Class | Images | Corrupt | Missing label | Boxes per image | Median size |
| --- | ---: | ---: | ---: | --- | --- |
| PET | 499 | 0 | 0 | 1: 446, 2: 39, 3: 8, 4: 6 | 4000×3000 |
| HDPE | 321 | 0 | 0 | 1: 300, 2: 16, 3: 3, 4: 2 | 524×683 |
| PVC | 168 | 0 | 0 | 1: 118, 2: 20, 3: 16, 4–7: 14 | 3614×3000 |
| LDPE | 440 | 0 | 0 | 1: 403, 2: 24, 3: 9, 4+: 4 | 524×640 |
| PP | 327 | 0 | 0 | 1: 315, 2: 10, 3: 2 | 3264×3000 |
| PS | 472 | 0 | 0 | 1: 385, 2: 64, 3: 20, 4: 3 | 640×640 |
| TrashNet glass / paper / cardboard / metal | 501 / 594 / 403 / 410 | 0 | – | – | 512×384 |

The PlasticWaste-DB description states 500 PET and 322 HDPE images; the
downloaded v1 files contain 499 and 321. Labels are YOLOv8 *oriented*
bounding boxes (four corner points, exported from Roboflow).

Observations (see `figures/raw_samples.png`):

- Many PP, PS and LDPE photos show a small item lying in soil, grass or
  rubble, which makes cropping by bounding box essential.
- Several PVC images are product photos or 3-D renders on plain
  backgrounds rather than real waste photos. This is a domain gap: the
  model may learn "studio background → PVC".
- The labels come from the dataset authors; they could not be checked
  against printed resin codes.

### Processing (`preprocessing/prepare.py`)

1. Each labelled object is cropped to the axis-aligned rectangle around
   its oriented box, plus a 10 % margin. Images with several boxes produce
   several crops, all in the same group. Boxes smaller than 48 px were
   skipped (38 boxes).
2. `non_plastic`: 110 random images (seed 42) from each of TrashNet's
   glass, paper, cardboard and metal = 440 images.
3. Everything is resized so the longest side is 384 px.
4. Perceptual hashes (pHash, 64-bit) are used to:
   - drop near-duplicates (Hamming distance ≤ 4) within a class (32 removed);
   - drop conflicting near-duplicates with different labels (0 found);
   - group images at distance ≤ 10, together with crops of the same photo,
     so that a group never crosses splits.

### Split (`preprocessing/split.py`)

Grouped, stratified split: `StratifiedGroupKFold` with 20 folds (seed 42).
3 folds go to test, 3 to validation and 14 to train.

| Class | Train | Val | Test | Total |
| --- | ---: | ---: | ---: | ---: |
| PET | 396 | 84 | 84 | 564 |
| HDPE | 242 | 51 | 51 | 344 |
| PVC | 173 | 36 | 40 | 249 |
| LDPE | 339 | 72 | 72 | 483 |
| PP | 236 | 51 | 51 | 338 |
| PS | 403 | 87 | 86 | 576 |
| non_plastic | 308 | 66 | 66 | 440 |
| **All** | **2097** | **447** | **450** | **2994** |

2,994 images in 2,585 groups. Automatic checks passed: every image
opens, every image has exactly one label, no group crosses splits, and no
near-duplicate (pHash distance ≤ 4) appears in two splits.

To regenerate everything:

```powershell
C:\src\venvs\plasticlens\Scripts\Activate.ps1
cd ai_model\preprocessing
python download.py; python inspect_data.py; python prepare.py; python split.py
```
