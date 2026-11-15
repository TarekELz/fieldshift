# Check outputs (small summaries, committed so a reader can see them)

These are the results behind three validation claims in the README. The raw inputs (`data/raw/`) are large and are not in the repository, so the scripts cannot be re-run from a clean clone without downloading them.

| File | What it holds | Produced by |
|---|---|---|
| `input_checks.json` | Per site: NASA MOD16A3GF yearly actual ET and potential ET (median of 2015-2024, mm), and ESA WorldCover 2021 land-cover shares around each point | `src/fieldshift/ingest/fetch_input_checks.py` (reads the open Planetary Computer copies) |
| `et0_check.json` | The engine's yearly reference evapotranspiration against MOD16 potential ET (ratio per site) | the water engine and the file above |
| `modis_phenology_check.json` | NASA MCD12Q2 phenology (green-up and dormancy dates) against the wheat calendar assumptions | `scripts/phenology_mcd12q2.py` |

These are consistency checks against another NASA product, not weather-station validation (see `docs/methodology.md`).
