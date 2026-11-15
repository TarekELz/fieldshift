"""Two independent input checks for the 7 Delta points, read from the open Microsoft Planetary Computer service (no account).

1. NASA MOD16A3GF v061 (Terra, yearly gap-filled evapotranspiration, 500 m): actual ET and PET in mm per year, 2015-2024, median of
   the 3x3 pixels around each point. Compared with the engine's yearly reference evapotranspiration (ET0 from NASA POWER), this is
   the missing check on "ET0 looks high". MOD16's PET is itself a model product (MERRA-2 meteorology), so agreement is a sanity check,
   not validation against measurements.
2. ESA WorldCover 2021 (10 m land cover, European Space Agency, CC BY 4.0; NOT NASA): share of cropland (class 40), built-up (50),
   water (80) within about 2.5 km of each point, to confirm the points are farmland.

Output: data/raw/nasa_extra/mod16_site_years.csv, worldcover_sites.csv; data/interim/input_checks.json (none of it is committed).
Run: .venv/Scripts/python src/fieldshift/ingest/fetch_input_checks.py
"""
import csv
import json
import pathlib
import re
import statistics as st
import time

import numpy as np
import rasterio
import requests
import yaml
from rasterio.warp import transform
from rasterio.windows import Window

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "nasa_extra"
INTERIM = ROOT / "data" / "interim"
B = "https://planetarycomputer.microsoft.com/api/stac/v1"
SIGN = "https://planetarycomputer.microsoft.com/api/sas/v1/sign"
S = requests.Session()
S.headers["User-Agent"] = "fieldshift-hackathon/0.1"


_QUERY = {}  # container -> read token (the query string of the first signed link works for every file in that container)


def signed(href, collection=None):
    """Sign one link with the open sign endpoint, waiting when the service says it is rate limited; reuse the token per container."""
    container = href.split("?")[0].rsplit("/", 5)[0] if False else "/".join(href.split("/")[:4])
    if container in _QUERY:
        return href + "?" + _QUERY[container]
    for _ in range(12):
        r = S.get(SIGN, params={"href": href}, timeout=60)
        if r.status_code == 429:
            m = re.search(r"in (\d+) seconds", r.text)
            time.sleep(int(m.group(1)) + 3 if m else 30)
            continue
        r.raise_for_status()
        out = r.json()["href"]
        _QUERY[container] = out.split("?", 1)[1]
        return out
    raise RuntimeError("the sign endpoint kept rate limiting")


def search(collection, bbox, datetime, limit=100):
    r = S.post(f"{B}/search", json={"collections": [collection], "bbox": bbox, "datetime": datetime, "limit": limit}, timeout=90)
    r.raise_for_status()
    return r.json()["features"]


def window_values(href, lon, lat, half, collection):
    with rasterio.open(signed(href, collection)) as src:
        x, y = transform("EPSG:4326", src.crs, [lon], [lat])
        r, c = src.index(x[0], y[0])
        win = Window(c - half, r - half, 2 * half + 1, 2 * half + 1)
        return src.read(1, window=win), src.nodata


def main():
    sites = yaml.safe_load((ROOT / "models" / "sites.yaml").read_text(encoding="utf8"))["sites"]
    OUT.mkdir(parents=True, exist_ok=True)
    INTERIM.mkdir(parents=True, exist_ok=True)
    rows, summary = [], {}
    # 1. MOD16A3GF
    for key, s in sites.items():
        feats = [f for f in search("modis-16A3GF-061", [s["lon"], s["lat"], s["lon"], s["lat"]], "2015-01-01/2024-12-31") if f["id"].startswith("MOD16A3GF")]
        et_years, pet_years = {}, {}
        for f in sorted(feats, key=lambda f: f["id"]):
            year = int(f["id"].split(".A")[1][:4])
            for asset, store in (("ET_500m", et_years), ("PET_500m", pet_years)):
                a, nodata = window_values(f["assets"][asset]["href"], s["lon"], s["lat"], 1, "modis-16A3GF-061")
                v = a.astype(float)
                v[v > 32760] = np.nan  # fill values (water, urban, barren, no data)
                if np.isfinite(v).sum() >= 4:
                    store[year] = float(np.nanmedian(v)) * 0.1  # scale 0.1: kg m-2 per year = mm per year
        for y in sorted(set(et_years) | set(pet_years)):
            rows.append({"site": key, "year": y, "ET_mm": round(et_years.get(y, float("nan")), 0), "PET_mm": round(pet_years.get(y, float("nan")), 0)})
        summary[key] = {"years": len(et_years), "ET_median_mm": round(st.median(et_years.values())) if et_years else None, "PET_median_mm": round(st.median(pet_years.values())) if pet_years else None}
        print(key, summary[key])
    with open(OUT / "mod16_site_years.csv", "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=["site", "year", "ET_mm", "PET_mm"])
        w.writeheader()
        w.writerows(rows)
    # 2. ESA WorldCover 2021 around each point (about 2.5 km each way: 10 m pixels)
    wc = {}
    for key, s in sites.items():
        feats = search("esa-worldcover", [s["lon"], s["lat"], s["lon"], s["lat"]], "2021-01-01/2021-12-31")
        feats = [f for f in feats if f["properties"].get("esa_worldcover:version", "").startswith("2.")] or feats
        a, _ = window_values(feats[0]["assets"]["map"]["href"], s["lon"], s["lat"], 250, "esa-worldcover")
        tot = a.size
        share = {c: round(float((a == c).sum()) / tot, 3) for c in (10, 20, 30, 40, 50, 60, 80)}
        wc[key] = {"cropland": share[40], "built_up": share[50], "water": share[80], "trees": share[10], "grass_shrub": share[20] + share[30], "bare": share[60]}
        print(key, wc[key])
    with open(OUT / "worldcover_sites.csv", "w", newline="", encoding="utf8") as f:
        w = csv.writer(f)
        w.writerow(["site", "cropland", "built_up", "water", "trees", "grass_shrub", "bare"])
        for k, v in wc.items():
            w.writerow([k, v["cropland"], v["built_up"], v["water"], v["trees"], v["grass_shrub"], v["bare"]])
    (INTERIM / "input_checks.json").write_text(json.dumps({"mod16": summary, "worldcover_2021": wc}, indent=1), encoding="utf8")


if __name__ == "__main__":
    main()
