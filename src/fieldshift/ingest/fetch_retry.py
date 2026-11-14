"""Retry the three failed open-data downloads: MODIS NDVI (chunked), PRISM yearly grids, CDL crop history."""
import json, math, re, pathlib, datetime
import requests

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw"
SITES = {"us_mead_ne": (41.165, -96.477), "eg_nile_delta": (30.79, 31.00)}
S = requests.Session(); S.headers["User-Agent"] = "fieldshift-hackathon/0.1"
log = {}


def albers5070(lon, lat):
    a = 6378137.0; f = 1 / 298.257222101; e = math.sqrt(2 * f - f * f)
    p1, p2, p0, l0 = map(math.radians, (29.5, 45.5, 23.0, -96.0))
    m = lambda p: math.cos(p) / math.sqrt(1 - e * e * math.sin(p) ** 2)
    def q(p):
        s = math.sin(p)
        return (1 - e * e) * (s / (1 - e * e * s * s) - (1 / (2 * e)) * math.log((1 - e * s) / (1 + e * s)))
    n = (m(p1) ** 2 - m(p2) ** 2) / (q(p2) - q(p1))
    C = m(p1) ** 2 + n * q(p1); r0 = a * math.sqrt(C - n * q(p0)) / n
    r = a * math.sqrt(C - n * q(math.radians(lat))) / n; th = n * (math.radians(lon) - l0)
    return r * math.sin(th), r0 - r * math.cos(th)


def _get(url, **kw):
    import time
    for i in range(4):
        try:
            r = S.get(url, timeout=240, **kw); r.raise_for_status(); return r
        except Exception:
            if i == 3: raise
            time.sleep(5 * (i + 1))


def modis():
    for site, (lat, lon) in SITES.items():
        base = "https://modis.ornl.gov/rst/api/v1/MOD13Q1"
        dates = _get(f"{base}/dates", params=dict(latitude=lat, longitude=lon)).json()["dates"]
        dates = [d["modis_date"] for d in dates if "A2015" <= d["modis_date"] <= "A2025366"]
        rows = []
        for i in range(0, len(dates), 10):
            ch = dates[i:i + 10]
            for band in ("250m_16_days_NDVI", "250m_16_days_pixel_reliability"):
                r = _get(f"{base}/subset", params=dict(latitude=lat, longitude=lon, band=band, startDate=ch[0],
                          endDate=ch[-1], kmAboveBelow=0, kmLeftRight=0), headers={"Accept": "application/json"})
                for s in r.json()["subset"]:
                    rows.append({"band": band, "modis_date": s["modis_date"], "calendar_date": s["calendar_date"], "data": s["data"]})
        (RAW / "modis_ndvi").mkdir(exist_ok=True)
        (RAW / "modis_ndvi" / f"{site}_MOD13Q1_2015_2025.json").write_text(json.dumps({"scale": 0.0001, "rows": rows}))
        log[f"modis_{site}"] = f"{len(rows)} rows, {dates[0]}..{dates[-1]}"


def prism():
    (RAW / "prism").mkdir(exist_ok=True)
    for f in (RAW / "prism").glob("*.zip"):
        if f.stat().st_size < 5000: f.unlink()  # remove error-page 'zips' from first attempt
    n = 0
    for y in range(2015, 2025):
        for v in ("ppt", "tmean"):
            p = RAW / "prism" / f"prism_{v}_us_4km_{y}.zip"
            if p.exists(): continue
            r = S.get(f"https://services.nacse.org/prism/data/get/us/4km/{v}/{y}", timeout=180); r.raise_for_status()
            p.write_bytes(r.content); n += 1
    log["prism"] = f"{n} new yearly grids (US only)"


def cdl():
    lat, lon = SITES["us_mead_ne"]
    x0, y0 = albers5070(lon, lat)
    out = []
    for dx, dy in [(0, 0), (500, 0), (-500, 0), (0, 500), (0, -500)]:
        for yr in range(2008, 2025):
            r = S.get(f"https://nassgeodata.gmu.edu/axis2/services/CDLService/GetCDLValue",
                      params=dict(year=yr, x=round(x0 + dx, 1), y=round(y0 + dy, 1)), timeout=90)
            m = re.search(r'value: (\d+), category: "([^"]*)"', r.text)
            out.append({"dx": dx, "dy": dy, "year": yr, "code": int(m.group(1)) if m else None, "crop": m.group(2) if m else None})
    (RAW / "cdl").mkdir(exist_ok=True)
    (RAW / "cdl" / "us_mead_ne_cdl_2008_2024.json").write_text(json.dumps(out, indent=1))
    log["cdl"] = f"{len(out)} point-year values"


for fn in (modis,):
    try: fn()
    except Exception as e: log[fn.__name__] = "FAILED " + repr(e)[:250]
    print(fn.__name__, log.get(fn.__name__) or {k: v for k, v in log.items() if fn.__name__ in k})
(RAW / "_retry_log.json").write_text(json.dumps(log, indent=1))
