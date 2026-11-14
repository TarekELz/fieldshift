# Data coverage report (2026-11-14)

Pilot sites: **US** Mead, Nebraska (41.165N, -96.477W) and **Egypt** Nile Delta near Tanta (30.79N, 31.00E).
Raw files live in `data/raw/` (gitignored). Scripts: `src/fieldshift/ingest/`.

## Is the US all NASA has? No.
NASA products are global. Only the USDA/USGS/OSU context layers are US-only. NASA CMR granule search at both points
(`data/raw/_cmr_coverage.json`):

| Product | US (Mead) | Egypt (Delta) | Note |
|---|---|---|---|
| SMAP L4 soil moisture | 33,961 | 33,961 | identical coverage |
| IMERG Final rainfall | 10,135 | 10,135 | identical coverage |
| MODIS Terra NDVI 250 m | 614 | 614 | identical |
| VIIRS NDVI | 680 | 680 | identical |
| GLDAS Noah | 273,446 | 273,446 | identical |
| ECOSTRESS ET (L3 JET) | 1,886 | 377 | Egypt about 5x fewer scenes |
| ECOSTRESS LST (L2T) | 5,286 | 1,567 | Egypt about 3x fewer scenes |
| SRTM 1 arc-sec | 1 tile | 2 tiles | fine |
| GEDI L4A, GRACE-FO | 0 | 0 | INCONCLUSIVE: short names or spatial query likely wrong; not verified |

## What is on disk
| Dataset | US | Egypt | Status |
|---|---|---|---|
| NASA POWER daily 1990-2025 (T2M, Tmax/min, rain, solar, RH, wind, soil wetness top/root/profile, EVPTRNS) | yes | yes | Done, no -999 gaps in Egypt file |
| SoilGrids (sand, silt, clay, SOC, pH, N, bulk density, CEC, 5 depths) | yes | yes | Done (non-NASA, global) |
| SSURGO soil horizons | point only | n/a | Done but tiny (one map unit: Yutan silty clay loam); need polygon queries for a real field |
| USDA CDL crop history | 5 points x 2008-2024 | n/a | Done. At the centre point: corn every year except soybeans in 2011, 2022, 2024. That is near-continuous corn, which is a useful "existing rotation" baseline |
| PRISM yearly ppt and tmean, 4 km | 2015-2024 | n/a | Done (48 MB, US only) |
| USGS NWIS | station list only | n/a | Time series not yet fetched |
| MODIS NDVI 250 m | retrying | retrying | First attempt failed on ORNL server timeouts. Retry with longer timeouts running. Check `data/raw/modis_ndvi/` |

## Not downloaded
- **Needs NASA Earthdata token:** SMAP, IMERG, ECOSTRESS, SRTM, GLDAS, GRACE/GRACE-FO.
- **Needs Copernicus account:** ERA5, Sentinel-2.
- **Needs free API key:** USDA QuickStats.
- **Manual or portal:** FAO GAEZ, Web Soil Survey, Ag Data Commons.
- **Not downloaded, no login needed:** USDA AMS Market News, NAIP, NLCD, LANDFIRE, CoCoRaHS (US/Canada only), NWIS time series.
- **Skipped on purpose:** OpenET (western US only, covers neither site), GEDI (weak over cropland), Landsat (needs USGS account; MODIS/Sentinel-2 cover the same need).

## Implications for the region decision
- The NASA feature set (soil moisture, rainfall, NDVI, temperature, terrain) is the same for both regions.
- The US adds free, rich soil and crop-history data (SSURGO, CDL) plus ground validation (AmeriFlux US-Ne1, PRISM).
- Egypt needs substitute soil and crop inputs (SoilGrids, GAEZ, user input). Validation data is the open question; ECOSTRESS is thinner.
- Note: re-running the retry script overwrote `_retry_log.json` with MODIS-only results. CDL and PRISM results are in the files themselves.
