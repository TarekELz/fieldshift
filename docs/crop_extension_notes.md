# Crop extension: what FAO-56 (Tables 11 and 12) gives us (D15)

Read from the FAO web tables (https://www.fao.org/4/x0490e/x0490e0b.htm) on 2026-11-15, **not from the PDF**: re-check every digit before it goes into `models/water_crops.yaml`. Some Kc ini values are images on the page and could not be read, so they are NOT filled in. Nothing here is in the engines yet.

| Crop | Stage days (ini/dev/mid/late) used by the row nearest the Delta | Kc ini / mid / end | Status |
|---|---|---|---|
| Sugar beet | 25/35/50/50 (160 d, May, Mediterranean) or 45/75/80/30 (230 d, Nov, Mediterranean) | 0.35 / 1.20 / 0.70 | complete, can be added |
| Faba bean (dry) | 20/30/35/15 (100 d, Mar-Apr, Mediterranean); winter row is European | 0.5 / 1.15 / 0.30 | complete for the spring row |
| Citrus | 60/90/120/95 (365 d, Jan, Mediterranean) | 0.65 / 0.60 / 0.65 (50% canopy, no ground cover) | complete, canopy cover must be asked or assumed |
| Onion (dry) | 15/25/70/40 (150 d, Apr, Mediterranean) | ini missing / 1.05 / 0.75 | needs Kc ini |
| Potato | 25/30/45/30 (130 d) | ini missing / 1.15 / 0.75 | needs Kc ini |
| Tomato | 30/40/45/30 (145 d, Apr-May, Mediterranean) | ini missing / 1.15 / 0.70-0.90 | needs Kc ini |
| Berseem clover | not in Table 11 | 0.40 / 0.90 / 0.85 (averaged cuttings) | needs stage lengths from another source |
| Date palm | not in Table 11 | 0.90 / 0.95 / 0.95 | perennial, no stages needed; Kc only |
| Grapes | 30/60/40/80 (210 d, Apr, Mid Latitudes) | 0.30 / 0.70 / 0.45 (wine) | complete |
| Mango | not in either table | not found | cannot be added |
| Sugarcane | 35/60/190/120 (405 d) | 0.40 / 1.25 / 0.75 | grown mainly in Upper Egypt; skip for the Delta |

Salt tolerance (FAO-29, `models/salt_tolerance.csv`) already has berseem, sugar beet, barley, faba bean and tomato. Still to read for new crops: citrus, grape, date palm, onion, potato.

Design question for Tarek: the app compares a SUMMER crop and wheat. Berseem, sugar beet, faba bean and onion are WINTER alternatives to wheat, and the heat engine is wheat-specific, so they need either a "winter crop" slot with water and salt only, or a wider redesign.
