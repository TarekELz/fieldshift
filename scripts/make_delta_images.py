"""Render two real NASA MODIS greenness images of the Nile Delta for the app (hero pictures).

Source: MOD13Q1 v061 NDVI rasters in data/raw/modis_delta_tif (NASA LP DAAC, clipped to the Delta by fetch_modis_delta.py).
For each season the pixel-wise MEDIAN over the 2015-2022 composites at that time of year is coloured:
  winter peak = composites nearest 2 February (wheat, berseem, vegetables are green)
  summer      = composites nearest 13 August (rice, maize, cotton are green)
Output: app/assets/img/delta_winter.jpg and delta_summer.jpg (data art, not a map: no borders, no labels).
Run: .venv/Scripts/python scripts/make_delta_images.py
"""
import glob
import pathlib
import re

import numpy as np
import rasterio
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = sorted(glob.glob(str(ROOT / "data/raw/modis_delta_tif/250m_16_days_NDVI/*.tif")))
OUT = ROOT / "app" / "assets" / "img"
OUT.mkdir(parents=True, exist_ok=True)

# colour ramp (NDVI -> colour): water, bare desert, sparse, green, deep green
STOPS = [(-0.2, (8, 20, 38)), (0.0, (14, 34, 58)), (0.12, (58, 48, 36)), (0.25, (120, 98, 52)), (0.4, (150, 150, 60)), (0.55, (70, 150, 70)), (0.7, (24, 120, 60)), (0.85, (10, 80, 44))]


def colour(a):
    xs = np.array([s[0] for s in STOPS])
    out = np.zeros(a.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(a, xs, [s[1][c] for s in STOPS])
    return out.astype(np.uint8)


def season(target_doy):
    stack = []
    for f in FILES:
        m = re.search(r"_(\d{4})(\d{3})\.tif", f)
        y, d = int(m.group(1)), int(m.group(2))
        if 2015 <= y <= 2022 and abs(d - target_doy) <= 8:
            with rasterio.open(f) as s:
                a = s.read(1).astype(float)
            a[a == -3000] = np.nan
            stack.append(a * 1e-4)
    print("composites used:", len(stack))
    return np.nanmedian(np.stack(stack), axis=0)


for name, doy in (("winter", 33), ("summer", 225)):
    ndvi = np.nan_to_num(season(doy), nan=-0.2)
    img = Image.fromarray(colour(ndvi))
    w, h = img.size
    img = img.resize((w * 3 // 2, h * 3 // 2), Image.BICUBIC)  # smooth, not blocky
    dest = OUT / f"delta_{name}.jpg"
    img.save(dest, quality=88)
    print(name, img.size, dest.stat().st_size // 1024, "KB")
