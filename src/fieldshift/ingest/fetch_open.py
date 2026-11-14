"""Download login-free datasets for the two pilot sites. Idempotent; logs to data/raw/_fetch_log.json."""
import json, time, pathlib, sys
import requests

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw"
SITES = {
    "us_mead_ne": {"lat": 41.165, "lon": -96.477, "note": "Mead NE (AmeriFlux US-Ne1), corn/soy rotation"},
    "eg_nile_delta": {"lat": 30.79, "lon": 31.00, "note": "Nile Delta near Tanta, irrigated"},
}
log = {}
S = requests.Session()
S.headers["User-Agent"] = "fieldshift-hackathon/0.1"


def save(path, content, mode="wb"):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, mode) as f:
        f.write(content)
    return path.stat().st_size


def step(name):
    def deco(fn):
        def run(*a, **k):
            t = time.time()
            try:
                out = fn(*a, **k)
                log[name] = {"ok": True, "detail": out, "sec": round(time.time() - t, 1)}
            except Exception as e:  # keep going; record failure
                log[name] = {"ok": False, "error": repr(e)[:300]}
            print(name, log[name].get("ok"), str(log[name].get("detail") or log[name].get("error"))[:140])
        return run
    return deco


@step("power")
def power(site):
    s = SITES[site]
    params = "T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,ALLSKY_SFC_SW_DWN,RH2M,WS2M,GWETTOP,GWETROOT,GWETPROF,EVPTRNS"
    url = ("https://power.larc.nasa.gov/api/temporal/daily/point?parameters=%s&community=AG&longitude=%s&latitude=%s"
           "&start=19900101&end=20251231&format=JSON" % (params, s["lon"], s["lat"]))
    r = S.get(url, timeout=180); r.raise_for_status()
    n = save(RAW / "power" / f"{site}_daily.json", r.content)
    return f"{n} bytes"


@step("modis_ndvi")
def modis(site):
    s = SITES[site]
    base = "https://modis.ornl.gov/rst/api/v1/MOD13Q1/subset"
    out = []
    for y in range(2015, 2026):
        p = dict(latitude=s["lat"], longitude=s["lon"], band="250m_16_days_NDVI",
                 startDate=f"A{y}001", endDate=f"A{y}365", kmAboveBelow=1, kmLeftRight=1)
        r = S.get(base, params=p, headers={"Accept": "application/json"}, timeout=120)
        r.raise_for_status()
        out.append(r.json())
    n = save(RAW / "modis_ndvi" / f"{site}_MOD13Q1_NDVI_2015_2025.json", json.dumps(out).encode())
    return f"{n} bytes"


@step("soilgrids")
def soilgrids(site):
    s = SITES[site]
    props = "&".join(f"property={p}" for p in ["sand", "silt", "clay", "soc", "phh2o", "nitrogen", "bdod", "cec"])
    depths = "&".join(f"depth={d}" for d in ["0-5cm", "5-15cm", "15-30cm", "30-60cm", "60-100cm"])
    url = f"https://rest.isric.org/soilgrids/v2.0/properties/query?lon={s['lon']}&lat={s['lat']}&{props}&{depths}&value=mean"
    r = S.get(url, timeout=120); r.raise_for_status()
    return f"{save(RAW / 'soilgrids' / f'{site}.json', r.content)} bytes"


@step("ssurgo_sda")
def ssurgo():
    s = SITES["us_mead_ne"]
    wkt = f"POINT({s['lon']} {s['lat']})"
    q = f"""SELECT mu.mukey, mu.muname, co.compname, co.comppct_r, co.hydgrp, co.drainagecl, co.slope_r,
      ch.hzname, ch.hzdept_r, ch.hzdepb_r, ch.sandtotal_r, ch.silttotal_r, ch.claytotal_r, ch.om_r, ch.awc_r, ch.ksat_r, ch.ph1to1h2o_r
      FROM mapunit mu JOIN component co ON co.mukey=mu.mukey LEFT JOIN chorizon ch ON ch.cokey=co.cokey
      WHERE mu.mukey IN (SELECT * FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('{wkt}'))"""
    r = S.post("https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest",
               data={"query": q, "format": "JSON+COLUMNNAME"}, timeout=120)
    r.raise_for_status()
    return f"{save(RAW / 'ssurgo' / 'us_mead_ne_sda.json', r.content)} bytes"


@step("cdl")
def cdl():
    s = SITES["us_mead_ne"]
    out = []
    for y in range(2015, 2025):
        d = 0.02
        # CropScape point-stat service returns small XML w/ crop code at point
        url = (f"https://nassgeodata.gmu.edu/axis2/services/CDLService/GetCDLValue?year={y}"
               f"&x={s['lon']}&y={s['lat']}&epsg=4326")
        r = S.get(url, timeout=60)
        out.append({"year": y, "status": r.status_code, "body": r.text[:400]})
    save(RAW / "cdl" / "us_mead_ne_cdl_values.json", json.dumps(out).encode())
    return out[-1]["body"][:120]


@step("prism_normals")
def prism():
    for v in ["ppt", "tmean"]:
        url = f"https://services.nacse.org/prism/data/public/normals/4km/{v}/annual"
        r = S.get(url, timeout=180); r.raise_for_status()
        save(RAW / "prism" / f"prism_normal_4km_{v}_annual.zip", r.content)
    return "ppt,tmean annual normals"


@step("nwis")
def nwis():
    url = ("https://waterservices.usgs.gov/nwis/site/?format=rdb&bBox=-96.60,41.05,-96.35,41.28"
           "&siteType=GW,ST&hasDataTypeCd=dv")
    r = S.get(url, timeout=60); r.raise_for_status()
    return f"{save(RAW / 'nwis' / 'sites_near_mead.rdb', r.content)} bytes"


if __name__ == "__main__":
    for site in SITES:
        for fn in (power, modis, soilgrids):
            fn(site)  # logged under step name; last site wins in log, files are per site
    ssurgo(); cdl(); prism(); nwis()
    save(RAW / "_fetch_log.json", json.dumps(log, indent=2).encode())
