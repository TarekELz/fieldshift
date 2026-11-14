"""Download MODIS MOD13Q1 v061 rasters for the Nile Delta, clipped to the Delta box.

Source: Microsoft Planetary Computer, which mirrors NASA LP DAAC MOD13Q1.061 granules as
cloud-optimized GeoTIFFs. No account is needed. Only the Delta window is read from each
file, so nothing outside the box is downloaded.

Granules are taken from the AppEEARS granule list in data/raw/appeears_delta_ndvi/ so the
dates match the team's AppEEARS request (nile_delta_ndvi, 2014-12-19..2025-12-19).

Output: data/raw/modis_delta_tif/<layer>/MOD13Q1_<layer>_<YYYYDDD>.tif
        (int16/uint8, MODIS sinusoidal projection, 250 m; NDVI and EVI scale factor 0.0001)
Run:    .venv/Scripts/python src/fieldshift/ingest/fetch_modis_delta.py [--limit N]
Safe to re-run: existing files are skipped.
"""
import argparse
import json
import pathlib
import re
import sys
import time

import rasterio
import requests
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw"
OUT = RAW / "modis_delta_tif"
GRANULES = RAW / "appeears_delta_ndvi" / "nile-delta-ndvi-granule-list.txt"
BBOX = (29.63547, 30.208557, 32.494189, 31.667542)  # lon/lat box of the AppEEARS request
LAYERS = ["250m_16_days_NDVI", "250m_16_days_EVI", "250m_16_days_pixel_reliability"]
STAC = "https://planetarycomputer.microsoft.com/api/stac/v1/collections/modis-13Q1-061/items/"
SIGN = "https://planetarycomputer.microsoft.com/api/sas/v1/sign"
S = requests.Session()
S.headers["User-Agent"] = "fieldshift-hackathon/0.1"


def get(url, **kw):
    for i in range(5):
        try:
            r = S.get(url, timeout=120, **kw)
            if r.status_code == 429:
                time.sleep(20 * (i + 1))
                continue
            r.raise_for_status()
            return r
        except requests.RequestException:
            if i == 4:
                raise
            time.sleep(5 * (i + 1))
    raise RuntimeError("too many retries: " + url)


def clip(href, dest):
    signed = get(SIGN, params={"href": href}).json()["href"]
    with rasterio.open(signed) as src:
        bounds = transform_bounds("EPSG:4326", src.crs, *BBOX, densify_pts=21)
        win = from_bounds(*bounds, transform=src.transform).round_offsets().round_lengths()
        data = src.read(1, window=win)
        prof = src.profile.copy()
        prof.update(driver="GTiff", height=data.shape[0], width=data.shape[1],
                    transform=src.window_transform(win), compress="deflate", tiled=False)
        prof.pop("blockxsize", None)
        prof.pop("blockysize", None)
        tmp = dest.with_suffix(".part")
        with rasterio.open(tmp, "w", **prof) as dst:
            dst.write(data, 1)
            dst.update_tags(**src.tags())
        tmp.replace(dest)
    return data.shape


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="only the first N granules (for testing)")
    a = ap.parse_args()
    ids = [u.strip().rsplit("/", 1)[-1][:-4] for u in GRANULES.read_text().splitlines() if u.strip().endswith(".hdf")]
    if a.limit:
        ids = ids[: a.limit]
    log = {"source": "Planetary Computer modis-13Q1-061 (mirror of NASA LP DAAC MOD13Q1.061)", "bbox": BBOX, "done": [], "failed": {}}
    for n, gid in enumerate(ids, 1):
        day = re.search(r"\.A(\d{7})\.", gid).group(1)
        todo = [l for l in LAYERS if not (OUT / l / f"MOD13Q1_{l}_{day}.tif").exists()]
        if not todo:
            log["done"].append(gid)
            continue
        try:
            assets = get(STAC + gid).json()["assets"]
            for l in todo:
                (OUT / l).mkdir(parents=True, exist_ok=True)
                shape = clip(assets[l]["href"], OUT / l / f"MOD13Q1_{l}_{day}.tif")
            log["done"].append(gid)
            print(f"{n}/{len(ids)} {day} ok {shape}", flush=True)
        except Exception as e:  # keep going; failures are listed in the log
            log["failed"][gid] = repr(e)[:200]
            print(f"{n}/{len(ids)} {day} FAILED {repr(e)[:120]}", flush=True)
    (OUT / "_fetch_log.json").write_text(json.dumps(log, indent=1))
    print("done", len(log["done"]), "failed", len(log["failed"]))
    return 1 if log["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
