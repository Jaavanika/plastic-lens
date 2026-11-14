# Datasets (not committed)

Run the scripts in `ai_model/preprocessing/` in this order to rebuild this folder:

1. `download.py`: fetches `raw/PlasticWaste-DB/` (checked against Mendeley's SHA-256 checksums) and `raw/trashnet/`.
2. `inspect_data.py`: counts images, finds corrupt files, and saves a grid of sample images.
3. `prepare.py`: writes `processed/images/<class>/` and `processed/manifest.csv`.
4. `split.py`: writes `processed/splits.csv` and `processed/stats.json`.

Licences and statistics are in [documentation/model_card.md](../../documentation/model_card.md).
