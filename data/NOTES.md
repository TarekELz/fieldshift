# Data notes

- `data/raw/` and `data/interim/` are **not** in git. Ask the team for the files, or re-download with the scripts in `src/fieldshift/ingest/`.
- `data/sample/` holds small files the demo needs offline. They are in git.
- Every dataset, its source, access and status: [`catalog.yaml`](catalog.yaml).
- Large files (SRTM tiles, MODIS GeoTIFFs) do not go into git. Agree with Tarek where they are shared (for example a shared drive) and record the location here.
- Some AppEEARS request files contain the requester's email. Keep them in `data/raw/` only.

## Current sample files
| File | What | From |
|---|---|---|
| `sample/imerg_delta_daily_2015_2025.csv` | Daily rain, Delta area mean, 2015-01-01 to 2025-09-30 (Giovanni export, 8 header lines) | NASA GPM IMERG Final V07 |
| `sample/modis_ndvi_delta_area_stats_2015_2025.csv` | 16-day NDVI/EVI statistics over the Delta box (mean, median, quartiles) | NASA MODIS MOD13Q1 v061 via AppEEARS |
