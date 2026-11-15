# Project status

AUDIT 2026-11-14 ~19:00: team-downloaded NASA data added: IMERG daily rain (Delta area mean 2015-2025), MODIS NDVI area statistics for the Delta box (rasters still to come from Hussain), SRTM 30 m tiles for the whole Delta. First push to GitHub on Tarek's instruction: merged so main shows only our files; Youssef Nada's and Hussain's earlier commits stay in the history (also backed up locally as branch backup/youssef-remote).

**Current step: building the Flutter app (Step 7). Updated 2026-11-15 ~08:10.** Deadline Sunday 15 Nov 23:59, Local Event time (still UNVERIFIED which event; Tarek to confirm).

Done: problem and region (D1, D5), grounded engines (D2), voice kept (D3), methods (D7, after two independent reviews). Built and tested (43 tests): wheat calendar, water (FAO-56), salt (FAO paper 29), rotation comparison. NASA POWER 1990-2025 for six Delta points; IMERG and MODIS statistics for the Delta; SRTM tiles; MODIS rasters downloading (about 70 of 254 dates, slow).

App (Flutter, D8): assistant is named Eyad (cartoon avatar with a visible AI mark, moods by situation); location is chosen by tapping a map of Egypt made of the 27 real governorate boundaries with Arabic names (Natural Earth, generalized, not an official survey; checked against OpenStreetMap): tap a Delta governorate to zoom, tap again to choose; governorates with their own NASA data point use it, the others use the nearest and say so; taps outside the Delta are refused; redesigned (dark, welcome screen, rings, stat tiles, climate chart); analysis clean; 7 Dart tests pass, including a check against the Python engines. Debug APK built 2026-11-15 08:36 at app/build/app/outputs/flutter-apk/app-debug.apk (163 MB, not in git). Seen only in a browser copy at phone size; NOT yet tried on a real phone, and the Arabic text is an AI draft not yet reviewed by a native speaker. MODIS Delta rasters: 120 of 254 dates downloaded, resumable.

Not done: voice layer, picture card and web page; Arabic conversation text (Tarek); voice tests (Youssef); input checks (POWER Tmax and ET0 against ground data); AI disclosure (on hold); LICENSE; demo (30-second video or 7 slides); submission page.

Known problems: Damietta weather cell is mostly sea; Menoufia and Sharqia share a cell; ET0 looks high, so use ratios not millimetres; several wheat parameters have no full-text source (marked low confidence); the repo is private and the final link must be public.

Open for Tarek: confirm the Local Event deadline; make the repo public before submitting (G6); AI disclosure wording; whether to accept git commit emails being public.

---
Step 1 audit follows (2026-11-14 12:50).

Last audit: 2026-11-14 12:50 local (Step 1, full audit). Files were opened and checked, not assumed.

## DONE (verified)
| Item | What was checked | Result |
|---|---|---|
| NASA POWER daily, both sites | 11 variables x 13,149 days each, 1990-01-01..2025-12-31, zero -999 values, coordinates match sites | Real data. Variables: T2M, T2M_MAX, T2M_MIN, PRECTOTCORR, ALLSKY_SFC_SW_DWN, RH2M, WS2M, GWETTOP, GWETROOT, GWETPROF, EVPTRNS |
| SoilGrids, US Mead | 8 properties x 5 depths, all have values (e.g. clay 383 g/kg, pH 6.4 at 0-5 cm) | Real data (non-NASA) |
| SSURGO, US Mead | One map unit (mukey 1691452, Yutan silty clay loam), horizons with texture, OM, AWC, Ksat, pH | Real but a single point query |
| CDL crop history, US Mead | 85 point-years (5 points x 2008-2024), no nulls | Centre point: corn every year except soybeans 2011, 2022, 2024. Point 500 m east is a corn-soybean rotation; west and south points are grass/developed |
| PRISM yearly ppt and tmean, 2015-2024 | 20 zips, 2.1-2.8 MB each, all pass zip integrity test and contain a GeoTIFF | Real data, US only. Note: these are whole-CONUS grids (48 MB), not clipped to Mead |
| NWIS station list | 8 sites near Mead (4 stream, 4 groundwater) | List only, no time series |
| CMR granule counts | `_cmr_coverage.json` matches docs/coverage_report.md | GEDI and GRACE-FO counts of 0 are inconclusive (query likely wrong) |
| GitHub repo (read-only) | TarekELz/fieldshift is PRIVATE and EMPTY: no branches, commits, issues or PRs | Collaborators with access: TarekELz, Al-Ashmawy, EyadM0hamed, hussainkzaid. Youssefnada-Engineer is NOT listed (invite pending or not sent). Project board not readable (gh token lacks read:project) |
| Local git | Initialised in Step 1 on `main`, local commits only | Nothing pushed |

## CORRECTIONS to earlier notes
- **SoilGrids Egypt is EMPTY.** `data/raw/soilgrids/eg_nile_delta.json` has the right structure but every value (8 properties x 5 depths) is null. docs/coverage_report.md and the prompt table list it as done. We hold **no soil properties for the Egypt site**. Cause not yet determined (SoilGrids masks some pixels; a nearby point may work).
- `data/raw/cdl/us_mead_ne_cdl_values.json` holds only HTTP 500 error bodies from the first attempt. The good file is `us_mead_ne_cdl_2008_2024.json`.
- `docs/agent_prompt.md` (an old copy of the agent instructions) was deleted from the repo and its history on Tarek's request, 2026-11-14.

## IN PROGRESS
- MODIS NDVI retry: `fetch_retry.py` (PID 27152) started 12:25, still running at 12:47, no output folder yet. Left alone; no duplicate started.

## NOT STARTED
- Steps 2-10. No README, LICENSE, CITATION.cff, CONTRIBUTING, literature/, models/, app/, tests/, notebooks/, demo/, submission/, data/catalog.yaml, data/NOTES.md, data/sample content.
- Nothing uses any dataset yet: `src/fieldshift/` has only the two ingest scripts.
- NWIS time series, AmeriFlux US-Ne1, QuickStats, AMS prices, GAEZ.

## BLOCKED
| Item | Blocked by |
|---|---|
| SMAP, IMERG, SRTM, ECOSTRESS, GLDAS | No `.env` file exists. Needs NASA Earthdata token, written into `.env` by Tarek |
| ERA5, Sentinel-2 | Copernicus account |
| USDA QuickStats | Free API key |
| AmeriFlux US-Ne1 | AmeriFlux registration |
| Project board read | `gh auth refresh -s read:project` (Tarek) |
| Team ownership in tasks | Owner roles for the four teammates are `<FILL IN>` in the prompt |

## Three highest-value next actions
1. Step 2: read the live brief and submission rules (no credentials needed).
2. Step 3: literature search to G1.
3. Tarek: create `.env` from `.env.example` with an Earthdata token, so data pulls are not the bottleneck after G2.

## Needs a human
- Earthdata token in `.env` (never in chat).
- Confirm whether Youssefnada-Engineer should have repo access.
- Teammate ownership areas.
