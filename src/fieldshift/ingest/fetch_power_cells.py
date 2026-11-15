"""Download NASA POWER daily weather (1990-2025) for every MERRA-2 cell that covers the Nile Delta and its edges (decision D15/D16).

POWER cells are 0.5 deg latitude by 0.625 deg longitude, centred on multiples of those steps. One request per cell centre, so each file is
exactly one cell (the cell is the data's own resolution; no interpolation). Output: data/raw/power_cells/cell_<lat>_<lon>_daily.json (gitignored).
No account needed. Safe to re-run: existing files are skipped.
Run: .venv/Scripts/python src/fieldshift/ingest/fetch_power_cells.py
"""
import pathlib
import sys
import time

import requests

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "power_cells"
PARAMS = "T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,ALLSKY_SFC_SW_DWN,RH2M,WS2M,GWETTOP,GWETROOT,GWETPROF,EVPTRNS"
URL = "https://power.larc.nasa.gov/api/temporal/daily/point"
LATS = [30.0, 30.5, 31.0, 31.5]
LONS = [29.375, 30.0, 30.625, 31.25, 31.875, 32.5]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bad = 0
    for lat in LATS:
        for lon in LONS:
            dest = OUT / f"cell_{lat:.3f}_{lon:.3f}_daily.json"
            if dest.exists():
                print(dest.name, "exists")
                continue
            q = dict(parameters=PARAMS, community="AG", longitude=lon, latitude=lat, start="19900101", end="20251231", format="JSON")
            for attempt in range(4):
                try:
                    r = requests.get(URL, params=q, timeout=240)
                    r.raise_for_status()
                    dest.write_bytes(r.content)
                    print(dest.name, len(r.content), "bytes", flush=True)
                    break
                except requests.RequestException as e:
                    if attempt == 3:
                        print(dest.name, "FAILED", repr(e)[:120], flush=True)
                        bad += 1
                    time.sleep(10 * (attempt + 1))
            time.sleep(2)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
