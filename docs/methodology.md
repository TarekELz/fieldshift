# Methodology (draft for gate G3)

Written 2026-11-14. Nothing here is final until Tarek chooses at G3. Each engine lists two or three ways to do it, simplest first. Parameters live in `models/*.yaml` with `evidence` and `confidence`.

Two words used below:
- **Input check:** comparing our inputs with ground data. Shows inputs are sound, not that outputs are right.
- **Plausibility check:** our outputs agree with published findings and move the right way when an input changes.

We cannot show that following the tool leads to better results on a real farm, and we will not say so.

---

## Engine 1: wheat calendar
**Question:** if wheat is sown on date X at place Y, how much heat does it meet while the grain is filling?

| Option | How it works | Data | Shows uncertainty by | Hours | Weakness |
|---|---|---|---|---|---|
| A. Fixed calendar | Maturity = sowing + 160 days. Grain filling = last 35 days. Count days with Tmax at or above 32 C, for each of 35 seasons | POWER Tmax | Spread across 35 seasons (median, 10th-90th percentile) | built | A late-sown crop does not take 160 days; A puts a January crop's maturity in mid-June, which is unrealistic |
| **B. Thermal time (recommended)** | Maturity when accumulated degree-days reach a target. The target is calibrated so a 15 November sowing matures about 25 April. Grain filling = last 30% of thermal time. Same heat-day count | POWER Tmax, Tmin | Same spread, plus a threshold sensitivity (30, 32, 34 C) | built | Calibration target and the 30% share are assumptions, not measurements |
| C. Learn from satellite phenology | Fit sowing-to-maturity timing from MODIS green-up and senescence dates per pixel | MODIS rasters (downloading), MCD12Q2 (needs token) | Pixel-to-pixel spread | 4-6 | A 250 m pixel mixes several 1 ha plots and crops; no ground truth for which pixel is wheat |

**Recommendation: B, with MODIS (C) used only as a check on the calendar**, not as the model. B is transparent, runs on data we hold, and fixes A's main flaw.

**First results (method B, threshold 32 C, 35 seasons 1990-2025, NASA POWER):**

| Sown | Gharbia: median heat days (10th-90th) | Seasons with 10+ heat days | Kafr El-Sheikh | Beheira | Median maturity (Gharbia) |
|---|---|---|---|---|---|
| 1 Nov | 4 (1-8) | 0% | 3 | 1 | 12 Apr |
| 15 Nov (recommended) | 7 (4-13) | 31% | 7 | 3 | 26 Apr |
| 1 Dec | 13 (9-17) | 89% | 12 | 5 | 9 May |
| 15 Dec | 17 (12-22) | 100% | 14 | 6 | 19 May |
| 10 Jan (trial "late" date) | 23 (18-30) | 100% | 20 | 10 | 3 Jun |

**Plausibility check:** heat exposure rises steadily with later sowing, about threefold from mid-November to 10 January at Gharbia. This agrees in direction with elbasyoni2018, where wheat sown 7-13 January lost about 40% of yield against mid-November sowing. We do not convert heat days into a yield loss: we have no source for that conversion.

**Known problems**
- **Damietta shows zero heat days at every date.** Its POWER cell is mostly sea, so the temperatures are maritime. POWER cannot represent coastal farmland a few kilometres inland. The app must not present Damietta as "no heat risk".
- Menoufia and Sharqia fall in the same POWER cell and give identical results.
- Inland July maxima of 38-40 C look high; the cells include desert. Input check against station data is still to do.
- The 32 C threshold, the 35-day or 30% grain-filling window and the late-April maturity target have **no full-text source yet** (`confidence: low`). The recommended sowing date and the late-sowing contrast do (elbasyoni2018).
- Heat is the only stress counted. Rust, water and salinity are not in this engine.

---

## Engine 2: water
**Question:** how much water does each summer crop need here, against how often the farmer gets canal water?

| Option | How it works | Data | Uncertainty | Hours | Weakness |
|---|---|---|---|---|---|
| **A. FAO-56 crop water need (recommended)** | Reference evapotranspiration (ET0) by Penman-Monteith from POWER weather; multiply by published crop coefficients and stage lengths to get seasonal need for rice, maize, cotton; compare crops as ratios | POWER; FAO-56 tables 11 and 12 | Year-to-year spread 1990-2025 | 3-4 | Gives demand, not supply. Rice also needs standing water and percolation, which FAO-56 Kc does not include |
| B. A plus a turn-based soil water bucket | Add soil water storage and the farmer's irrigation turn (for example water every 10 days): count days the crop runs short | A plus soil texture (SoilGrids near the points), farmer input | Spread across years and across assumed soil storage | 6-8 | Needs soil and application-depth assumptions we cannot check |
| C. Satellite water use | Use MODIS MOD16 or ECOSTRESS ET as the measure of crop water use | Needs Earthdata token; Hussain's AppEEARS request | - | 3 + waiting | 500 m pixels mix crops; shows what was used, not what a crop would need |

**Recommendation: A first, then the turn question from B in its simplest form** (days between turns against days the crop can wait), with C as an input check if Hussain's request arrives.

**Sourced so far (FAO-56, read from the FAO web tables; digits to be re-checked against the PDF):** Kc mid 1.20 for rice and maize, 1.15-1.20 cotton, 1.15 wheat, berseem 0.90 (averaged cutting). Cotton stages 30/50/60/55 days (195) listed for Egypt; rice 30/30/60/30 (150), Mediterranean, May planting.
**IMERG finding (data on disk):** Delta area-mean rain is 14-181 mm a year, almost none from May to September, so summer crops depend entirely on irrigation.

---

## Engine 3: salt
**Question:** which crops can the farmer's soil take, and what is the trade-off of dropping rice?

| Option | How it works | Data | Uncertainty | Hours | Weakness |
|---|---|---|---|---|---|
| **A. Tolerance lookup from the farmer's answer (recommended)** | Farmer gives a soil test value, or picks from signs (none / patches / white crust). Compare with published crop tolerance thresholds to mark each crop fine / reduced / not advised | FAO paper 29 table (Eyad's task) | Shown as ranges, since signs are a rough guide | 2-3 | Signs-to-salinity mapping is a judgement; must be labelled as such |
| B. A plus an area prior | Pre-fill the likely class from the FAO soil map (HWSD v2, 1 km) and low elevation (SRTM, on disk) | HWSD (not downloaded), SRTM | Prior clearly marked as area-level | +3 | 1 km soil units do not describe a 1 ha field |
| C. Satellite salinity index | Landsat or Sentinel-2 salinity indices | Token | - | 6+ | No ground truth; hagage2024 needed field samples to interpret them. Not recommended |

**Recommendation: A, add B only if time allows.** No NASA product measures soil salinity; this engine is literature plus farmer input, and the app says so.
**The rice trade-off** (rice controls salt but uses the most water) is described in ghazouani2014 (full text) and kotb2000 (abstract only). We present it as a caution, not a calculation.

---

## How the engines meet
One conversation, one comparison: the farmer's current rotation against two alternatives. For each: heat risk for the wheat that follows (engine 1), summer water need against the farmer's turn (engine 2), salt fit (engine 3), why it was suggested, what evidence supports it, and what needs checking with a local agronomist. Every number is tagged as satellite/reanalysis, model assumption, farmer input or literature.

## Validation section
To be written in Step 8. Planned: input check of POWER temperature against station data for a Delta station; plausibility checks listed above.
