"""Terrain check of the 19 NASA POWER data points with NASA SRTM (SRTMGL1 v003, 1 arc-second, about 30 m).

Why: the app warns that some weather cells are "desert edge" (mostly plateau, so the cell's weather is not the farmland's weather). That warning was
based on POWER's own average height for the cell. SRTM lets us measure it: for each data point, the height at the point itself and the share of the
whole ~50 km weather cell (0.5 deg latitude x 0.625 deg longitude, the POWER grid) that is low flat land (the Nile floodplain, below 30 m) and the
share that is plateau (above 100 m).

Output: docs/checks/srtm_terrain.csv (small, committed). Inputs (not in the repository): data/raw/srtm/N3?E0??.SRTMGL1.hgt.zip.
Run from the repository root:  python scripts/srtm_terrain_check.py
This is a terrain description, not a validation of weather. It changes no number the farmer sees.
"""

import csv
import io
import zipfile
from pathlib import Path

import numpy as np
import yaml

ROOT = Path(__file__).resolve().parent.parent
SRTM = ROOT / "data" / "raw" / "srtm"
OUT = ROOT / "docs" / "checks" / "srtm_terrain.csv"
N = 3601  # samples per tile side (1 arc-second tiles)
_tiles = {}


def tile(lat0, lon0):
    key = (lat0, lon0)
    if key not in _tiles:
        base = f"N{lat0:02d}E{lon0:03d}"
        with zipfile.ZipFile(SRTM / f"{base}.SRTMGL1.hgt.zip") as z:
            a = np.frombuffer(z.read(f"{base}.hgt"), dtype=">i2").reshape(N, N).astype(np.int16)
        _tiles[key] = a
    return _tiles[key]


def window(lat_a, lat_b, lon_a, lon_b, step=4):
    """Heights (m) in a lat/lon box, subsampled every `step` samples (about 120 m), voids removed. The tiles hold 30 to 32 N, 29 to 33 E only."""
    lat_a, lat_b, lon_a, lon_b = max(lat_a, 30.0), min(lat_b, 32.0 - 1e-6), max(lon_a, 29.0), min(lon_b, 33.0 - 1e-6)
    parts = []
    for lat0 in range(int(np.floor(lat_a)), int(np.ceil(lat_b))):
        for lon0 in range(int(np.floor(lon_a)), int(np.ceil(lon_b))):
            t = tile(lat0, lon0)
            r0 = int(round((lat0 + 1 - min(lat_b, lat0 + 1)) * (N - 1)))
            r1 = int(round((lat0 + 1 - max(lat_a, lat0)) * (N - 1)))
            c0 = int(round((max(lon_a, lon0) - lon0) * (N - 1)))
            c1 = int(round((min(lon_b, lon0 + 1) - lon0) * (N - 1)))
            parts.append(t[r0 : r1 + 1 : step, c0 : c1 + 1 : step].ravel())
    a = np.concatenate(parts)
    return a[a > -1000]  # -32768 marks a void


def cell_box(lat, lon):
    """The POWER (MERRA-2) cell that contains a point: 0.5 deg latitude by 0.625 deg longitude, centres on the grid."""
    clat = round(lat / 0.5) * 0.5
    clon = round((lon + 180) / 0.625) * 0.625 - 180
    return clat - 0.25, clat + 0.25, clon - 0.3125, clon + 0.3125


def main():
    sites = yaml.safe_load((ROOT / "models" / "sites.yaml").read_text(encoding="utf8"))["sites"]
    cells = yaml.safe_load((ROOT / "models" / "cells.yaml").read_text(encoding="utf8"))["cells"]
    points = [(k, v["lat"], v["lon"], v.get("caveat_kind") or "", "named") for k, v in sites.items()]
    points += [(k, v["lat"], v["lon"], v.get("caveat_kind") or "", "cell") for k, v in cells.items()]
    rows = []
    for key, lat, lon, caveat, kind in points:
        at = window(lat - 0.009, lat + 0.009, lon - 0.009, lon + 0.009, step=1)  # about 2 km box around the point
        la, lb, oa, ob = cell_box(lat, lon)
        cell = window(la, lb, oa, ob)
        covered = (min(lb, 32.0) - max(la, 30.0)) / (lb - la) * (min(ob, 33.0) - max(oa, 29.0)) / (ob - oa)
        rows.append(
            {
                "point": key,
                "kind": kind,
                "lat": lat,
                "lon": lon,
                "app_caveat": caveat,
                "height_at_point_m": int(np.median(at)),
                "cell_median_m": int(np.median(cell)),
                "cell_p90_m": int(np.percentile(cell, 90)),
                "cell_share_below_30m": round(float((cell < 30).mean()), 2),
                "cell_share_above_100m": round(float((cell > 100).mean()), 2),
                "cell_covered_by_tiles": round(covered, 2),
            }
        )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    for r in rows:
        print(f"{r['point']:24} {r['app_caveat']:12} at point {r['height_at_point_m']:4} m  cell median {r['cell_median_m']:4} m  low {r['cell_share_below_30m']:.2f}  plateau {r['cell_share_above_100m']:.2f}")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
