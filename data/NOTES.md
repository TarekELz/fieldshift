# Data notes

- `data/raw/` and `data/interim/` are **not** in git. Ask the team for the files, or re-download.
- `data/sample/` holds small files the demo needs offline. They are in git.
- Every dataset, its source, access and status: [`catalog.yaml`](catalog.yaml).
- Large files (SRTM tiles, MODIS GeoTIFFs, HWSD v2.0 rasters) do not go into git. Agree with Tarek where they are shared.
- Some AppEEARS request files contain the requester's email. Keep them in `data/raw/` only.

## Dataset files and local paths
| File | What | From |
|---|---|---|
| `sample/imerg_delta_daily_2015_2025.csv` | Daily rain, Delta area mean, 2015-01-01 to 2025-09-30 | NASA IMERG |
| `sample/modis_ndvi_delta_area_stats_2015_2025.csv` | 16-day NDVI/EVI statistics over the Delta box | NASA MODIS |
| `/run/media/b1ackraven/New Volume/Nasa_space_apps/fieldshift/HWSD2/HWSD2.bil` | Global soil raster binary data (21600x43200, ~1.8 GB) | FAO HWSD v2.0 |
| `/run/media/b1ackraven/New Volume/Nasa_space_apps/fieldshift/HWSD2/HWSD2.hdr` | Raster header file (21600 rows x 43200 cols) | FAO HWSD v2.0 |
| `/run/media/b1ackraven/New Volume/Nasa_space_apps/fieldshift/HWSD2/HWSD2.prj` | Projection metadata (GCS_WGS_1984) | FAO HWSD v2.0 |
| `/run/media/b1ackraven/New Volume/Nasa_space_apps/fieldshift/HWSD2/HWSD2.mdb` | Soil attribute database (~88 MB) | FAO HWSD v2.0 |

**Local Setup Note:** The HWSD v2.0 files are stored locally on your machine at `/run/media/b1ackraven/New Volume/Nasa_space_apps/fieldshift/HWSD2`.















