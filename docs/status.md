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

## 2026-11-15 update: official borders and setup flow
- Map: governorate borders now come from the official CAPMAS boundaries (HDX COD-AB, CC BY-IGO) instead of Natural Earth; the Rosetta and Damietta lines lie within 0.4 km of them. Rivers and lakes are still Natural Earth. Canals not added. Arabic spellings follow HDX (Alexandria without the hamza).
- Setup flow: three screens laid out like the team's reference (welcome with Skip / Get started, what Eyad does, voice or typing choice). The voice-or-typing choice is a real setting (mutes spoken replies). Arabic text is a draft and needs a native-speaker review.
- Not done: APK not rebuilt since these changes (the MODIS download is still using memory); not tested on a phone; nothing pushed.

- Corrections after the independent review (2026-11-15): MODIS is 242 of 254 dates on disk (not 120, not all); the 12 missing include nine consecutive composites from July to October 2025, so any 2025 summer analysis has a hole. Dart tests are now 23. The sea warning now appears only for Damietta; Menoufia and Sharqia get a neutral shared-cell note. Salt ring and heat tile wording no longer imply yield or an exact hot-day count.

## 2026-11-15 update: redesign and language switch
- The scrolling chat is replaced by a guided screen: one question at a time, big answer buttons, the map, a big mic button. The result screen follows the car-control reference (hero picture, rotation switcher, one ring, two cards, round buttons for water, heat, salt, weather).
- Hero pictures are real NASA MODIS greenness renderings of the Delta made from our own data (scripts/make_delta_images.py), replacing the painted Earth.
- Arabic / English switch (one language at a time) on every screen; the layout flips right-to-left or left-to-right; English answers are understood when typed or spoken; voice follows the language when the phone has that voice.
- Not done: tested only in a browser preview at phone size (no real phone, no voice test); APK not rebuilt; Arabic and English text unreviewed by a native speaker.

## 2026-11-15 update: design system from the team's Advanced Monitor app
- Tarek asked for the colours, boxes and general design to follow his Advanced Monitor app (his own project, found in C:\Users\tarek\dev\am-v2-ui\app\design). Ported: the dark palette (neutral near-black canvas and surfaces, one blue accent, green/amber/red for state only), soft cards without outlines, radius 22/14, IBM Plex Sans + IBM Plex Sans Arabic (SIL OFL licences copied to app/assets/fonts), two-weight headlines, icon bubbles, the 240-degree dial, and the hero picture with readings on dotted leaders (here the real MODIS picture of the Delta with the chosen place pinned at its true position).
- Not taken: the Lotus Power logo and mark, and the hive and device art.
- Dark theme only; the monitor app also has a light palette (could be added; outdoors in sun a light theme may read better).
- Still only seen in a browser preview at phone size: no real phone, no voice test; APK not rebuilt.

## 2026-11-15 update: light mode, Halayeb and Shalateen, a date bug
- Light mode added with the palette from the Advanced Monitor app (warm off-white canvas, white cards on a faint shadow, deep blue accent, darker state colours); a sun/moon button switches, Arabic and English both work in both modes. Default is dark.
- Halayeb and Shalateen are drawn on the map from the official HDX admin-2 sub-divisions (Red Sea governorate) with Arabic names; tapping or naming them says they are outside the Delta.
- Bug found and fixed: the answer buttons for 1 November and 1 December were read as 12 January / 10 January (the typed-date parser read "12-01" as day 12 of month 1). Buttons now keep their exact date; a test covers every date button. Earlier previews and any earlier APK have this bug.
- Preview-only URL switches for the web build: ?theme=light, ?lang=en, ?skip=1, ?demo=1 (ignored on phones).
- Still only seen in a browser preview: no phone, no voice test, APK not rebuilt.

## 2026-11-15 update: Dakahlia / Mansoura weather
- Tarek asked where Dakahlia and Mansoura get their data: before, from the nearest point (Gharbia at 37 km for Mansoura, Damietta for the governorate's middle). Checked and fixed (D11): Mansoura lies in the same NASA POWER cell as Gharbia (identical weather), so it now uses Gharbia's data and the app says so; a seventh point, east Dakahlia, was downloaded (1990-2025, no gaps) and the app picks by weather cell first. Mean Tmax differs from Gharbia by about 0.8 C. Not checked: whether the east Dakahlia point is cropland (task 2 in tasks.md now covers seven points); POWER temperatures still not checked against stations.
- Tests: 27 Flutter, 43 Python.

## 2026-11-15 update: Halayeb triangle and avatar
- Tarek said the Halayeb and Shalateen shapes were wrong and that a southern triangle was missing from the border. Checked: our national outline follows 22N all along the south and already contains 100% of the Natural Earth Halayib Triangle; the shapes I had drawn were two HDX administrative divisions, not the triangle. Now the triangle itself is drawn and named. OPEN: which "missing triangle" Tarek means exactly (Bir Tawil, south of 22N, is not drawn and is not in Egypt's outline).
- Avatar: smaller everywhere (welcome 84, question 78, result 50) and the calm "main" pose is the default; the arms-up pose is no longer used. Which poses Tarek wants where is OPEN.
- Bir Tawil added (Tarek, 2026-11-15) and drawn like the rest of the map: same fill and outline, no label, not selectable (D12). The first dashed, labelled version was rejected.
- Avatar: Tarek approved the reactive poses (calm close-up as the default and on the first question; open hands on questions, thumbs-up or worried on results, thoughtful on a retry), saying it is better than one pose (2026-11-15). Pose switching stays.
- Correction: this machine is on Egypt Standard Time. At 10:57 local on 2026-11-15 about 13 hours remained before the 23:59 deadline (an earlier note that said about 7 hours came from a mislabelled shell time zone).
- Halayeb and Shalateen are now drawn like the rest of the map (neutral label); the amber had no meaning there and amber is the warning colour. The web preview shows the app inside a phone-sized frame when the browser window is wide (web only; a phone is unaffected).
- Avatar identity (2026-11-15): sized by role (welcome 132, setup 90 and 150, questions 108, result headline 64); the name under him on the question screens; a soft pulsing ring while he speaks or the mic listens; tap him to hear the question again. The pulse depends on the phone's text-to-speech reporting when speech starts and ends, so it is untested until a phone test.

## 2026-11-15 update: fixes from the second independent review (Opus)
Fixed: (1) the mic screen could stay on "Listening" after a speech timeout or error (voice.dart/flow.dart now reset it; Back also stops speech); (2) a tap in Sharqia picked Menoufia because the two share a POWER cell: the governorate's own point now wins (test added); (3) scripts/apply_text_review.py escaped placeholders and broke 47 strings: rewritten, and tests/test_apply_text_review.py proves every one of the 164 strings round-trips exactly (six reworded since the page was sent are skipped by name); (4) shared-cell note now says only the temperatures/heat results are the same (solar radiation, so water use, differs slightly); (5) the main dial says it compares the summer crop only; (6) the hero picture has a NASA MODIS credit caption; the HDX licence (CC BY-IGO) is named under the map; (7) D11 added to the decision log; (8) English parser traps (2 weeks, 1st December, no white crust, maybe vs May); (9) a hero bubble that sat on a pin is moved; (10) about 46 stray preview-server processes killed.
Left for Tarek: README rewrite and LICENSE choice; AI-use disclosure; whether the welcome text should say "AI assistant" (the conversation is scripted; the AI mark on the avatar is separate); whether to delete the local branch backup/pre-history-rewrite (it still holds docs/agent_prompt.md); the Local Event deadline.
