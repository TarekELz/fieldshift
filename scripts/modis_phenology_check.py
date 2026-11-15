"""Plausibility check of the wheat calendar against NASA MODIS NDVI (MOD13Q1, data/raw/modis_delta_tif).
For each data point: median NDVI of a 9x9 pixel window (about 2 km), 2015-2022 composites, then the date of the winter peak
and the date NDVI has fallen halfway to the summer minimum. A 250 m pixel mixes wheat, berseem and vegetables, so this is a
direction check only. Writes data/interim/modis_phenology_check.json. Run: .venv/Scripts/python scripts/modis_phenology_check.py"""
import glob, re, datetime as dt, json, pathlib, statistics as st
import numpy as np, rasterio
from rasterio.warp import transform

ROOT = pathlib.Path(__file__).resolve().parents[1]
sites = {"gharbia": (30.86, 31.05), "kafr_el_sheikh": (31.10, 30.91), "beheira": (30.94, 30.15), "menoufia": (30.54, 30.95), "sharqia": (30.49, 31.43)}
files = sorted(glob.glob(str(ROOT / "data/raw/modis_delta_tif/250m_16_days_NDVI/*.tif")))
rel = {re.search(r"_(\d{7})\.tif", f).group(1): f.replace("250m_16_days_NDVI", "250m_16_days_pixel_reliability") for f in files}
series = {k: {} for k in sites}
for f in files:
    day = re.search(r"_(\d{4})(\d{3})\.tif", f); y, d = int(day.group(1)), int(day.group(2))
    date = dt.date(y, 1, 1) + dt.timedelta(days=d - 1)
    if not pathlib.Path(rel[day.group(1) + day.group(2)]).exists():
        continue  # this date is still being downloaded
    with rasterio.open(f) as s, rasterio.open(rel[day.group(1) + day.group(2)]) as sr:
        a = s.read(1).astype(float); q = sr.read(1)
        for k, (lat, lon) in sites.items():
            x, yv = transform("EPSG:4326", s.crs, [lon], [lat])
            r, c = s.index(x[0], yv[0])
            win = a[r - 4:r + 5, c - 4:c + 5]; qw = q[r - 4:r + 5, c - 4:c + 5]
            ok = (win != -3000) & (qw <= 1)  # 0 good data, 1 marginal
            if ok.sum() >= 20:
                series[k][date] = float(np.median(win[ok]) * 1e-4)
out = {}
for k in sites:
    sr = series[k]
    byd = {}
    for d, v in sr.items():
        if 2015 <= d.year <= 2022:  # complete years only
            doy = (d - dt.date(d.year, 1, 1)).days + 1
            byd.setdefault(((doy - 1) // 16), []).append(v)
    clim = {i: st.median(v) for i, v in sorted(byd.items()) if len(v) >= 5}
    days = {i: (i * 16 + 1) for i in clim}
    pk_i = max((i for i in clim if days[i] < 130), key=lambda i: clim[i])  # winter-season peak (before May)
    summer_min = min(v for i, v in clim.items() if 120 <= days[i] <= 200)
    half = (clim[pk_i] + summer_min) / 2
    drop = next((i for i in sorted(clim) if i > pk_i and clim[i] <= half), None)
    fmt = lambda i: (dt.date(2021, 1, 1) + dt.timedelta(days=days[i] - 1)).strftime("%d %b")
    out[k] = {"winter_peak": fmt(pk_i), "peak_ndvi": round(clim[pk_i], 2), "summer_min_ndvi": round(summer_min, 2), "halfway_down": fmt(drop) if drop is not None else None}
    print(f"{k:16s} winter peak ~{fmt(pk_i)} (NDVI {clim[pk_i]:.2f}) | halfway down to the summer minimum ({summer_min:.2f}) ~{fmt(drop) if drop is not None else 'n/a'} | composites used {sum(len(v) for v in byd.values())}")
pathlib.Path(ROOT / "data/interim").mkdir(exist_ok=True)
(ROOT / "data/interim/modis_phenology_check.json").write_text(json.dumps(out, indent=1))
