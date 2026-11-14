# Project status

**Current step: 3/10, waiting for Tarek at gate G1 (which problem).**

AUDIT 2026-11-14 about 15:20: Steps 2 and 3 outputs written (docs/brief.md, docs/submission-rules.md, literature/search_log.csv, literature/papers.csv, docs/problem_statement_options.md). No new data on disk. MODIS retry (PID 27152) still running after about 3 hours with no output folder; probably hung, left alone pending Tarek's word. Still no `.env`. Three other public Field Shift repos found on GitHub (huiliijiang/spaceapp26, Zul-Qarnain/field-shift, chhra/field-shift).

Rule changes found in Step 2 that affect later steps: demo is a 30-second video or 7 slides; AI may not be used to come up with the solution idea; AI-generated code must be acknowledged in the project; final project link must be public.

Open for Tarek: G1 choice; four paywalled papers (see G1 message); AI-disclosure wording vs AGENTS.md; overwrite docs/agent_prompt.md; Youssefnada-Engineer repo access; teammate roles; which Local Event (sets the deadline clock).

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
- `docs/agent_prompt.md` is an older version of the operating prompt. The governing version is the one Tarek pasted in chat on 2026-11-14. Needs Tarek's OK to overwrite the file with it.

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
- Decide whether to overwrite `docs/agent_prompt.md` with the current prompt.
- Confirm whether Youssefnada-Engineer should have repo access.
- Teammate ownership areas.
