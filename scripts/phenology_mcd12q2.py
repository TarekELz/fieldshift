"""Read NASA MCD12Q2 v061 (MODIS land cover dynamics, yearly phenology, 500 m, tile h20v05) at the Delta points and summarise when crops green up,
peak and senesce, per cycle and year. Input: the HDF4 files Tarek downloaded (data/raw/mcd12q2_user_2026-11-15/, gitignored). Needs pyhdf.

Output: data/interim/phenology_sites.csv (site, year, cycle, greenup, peak, maturity, senescence, dormancy as dates) and a printed summary
(median day of year per cycle). This is NASA's own satellite phenology: it says WHEN the land is green, not WHICH crop grows, and cycles are numbered by
the algorithm (cycle 1 / 2 in the year), not by crop. It is a cross-check and context for the calendar, not a farmer-facing number yet.

Run: .venv/Scripts/python scripts/phenology_mcd12q2.py
"""
import csv
import datetime as dt
import glob
import math
import pathlib
import re
import statistics

import numpy as np
import yaml
from pyhdf.SD import SD, SDC

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "data" / "raw" / "mcd12q2_user_2026-11-15"
OUT = ROOT / "data" / "interim"
R = 6371007.181
PIX = 463.31271653
H, V = 20, 5
X0 = -20015109.354 + H * 1111950.5196666666
Y0 = 10007554.677 - V * 1111950.5196666666
LAYERS = ["Greenup", "Peak", "Maturity", "Senescence", "Dormancy"]
FILL = 32767
EPOCH = dt.date(1970, 1, 1)


def rowcol(lat, lon):
    x = math.radians(lon) * R * math.cos(math.radians(lat))
    y = math.radians(lat) * R
    return int((Y0 - y) / PIX), int((x - X0) / PIX)


def main():
    sites = yaml.safe_load((ROOT / "models" / "sites.yaml").read_text(encoding="utf8"))["sites"]
    files = {}
    for f in sorted(glob.glob(str(SRC / "*" / "*.hdf"))):
        y = int(re.search(r"\.A(\d{4})001\.", f).group(1))
        files[y] = f  # for 2025 two production versions exist: the later file name sorts last and wins
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for y, f in sorted(files.items()):
        sd = SD(f, SDC.READ)
        arr = {k: sd.select(k).get() for k in LAYERS + ["NumCycles"]}
        for key, s in sites.items():
            r, c = rowcol(s["lat"], s["lon"])
            if not (1 <= r < 2399 and 1 <= c < 2399):
                continue
            ncyc = int(np.median(arr["NumCycles"][r - 1:r + 2, c - 1:c + 2]))
            for m in (0, 1):
                vals = {}
                for k in LAYERS:
                    w = arr[k][r - 1:r + 2, c - 1:c + 2, m].astype(float)
                    w = w[(w != FILL) & (w > 0)]
                    vals[k] = (EPOCH + dt.timedelta(days=int(np.median(w)))).isoformat() if w.size >= 4 else ""
                if any(vals.values()):
                    rows.append({"site": key, "year": y, "numcycles": ncyc, "cycle": m + 1, **{k.lower(): v for k, v in vals.items()}})
    with open(OUT / "phenology_sites.csv", "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=["site", "year", "numcycles", "cycle", "greenup", "peak", "maturity", "senescence", "dormancy"])
        w.writeheader()
        w.writerows(rows)
    print("years:", sorted(files), "rows:", len(rows))
    for key in sites:
        print(key)
        for cyc in (1, 2):
            rs = [r for r in rows if r["site"] == key and r["cycle"] == cyc]
            if not rs:
                continue
            doy = lambda col: [dt.date.fromisoformat(r[col]).timetuple().tm_yday for r in rs if r[col]]
            med = lambda col: (lambda d: round(statistics.median(d)) if d else None)(doy(col))
            nc = statistics.median(r["numcycles"] for r in rs)
            print(f"  cycle {cyc}: {len(rs)} years, median day of year: greenup {med('greenup')}, peak {med('peak')}, maturity {med('maturity')}, senescence {med('senescence')}, dormancy {med('dormancy')}; NumCycles median {nc}")


if __name__ == "__main__":
    main()
