"""Water engine (draft, before gate G3 confirmation): crop water need from NASA POWER weather.

Method (FAO Irrigation and Drainage Paper 56, "Penman-Monteith"):
  ET0  reference evapotranspiration, computed daily from POWER temperature, humidity, wind, solar radiation.
  ETc  crop evapotranspiration = Kc(stage) * ET0, summed over the growing season.

This is crop water DEMAND by the atmosphere. It does NOT include rice ponding, percolation or
seepage, irrigation losses, leaching, or rain (rain is nearly zero in the Delta in summer). The
canal supply to a field cannot be seen by any satellite; it comes from the farmer.

The farmer-turn rule is plain arithmetic: water needed between two turns = daily need x days
between turns. No soil-storage assumption is made.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import pathlib
import statistics

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
SIGMA = 4.903e-9  # MJ K-4 m-2 day-1 (Stefan-Boltzmann, FAO-56 eq. 39)


# ---- FAO-56 building blocks -------------------------------------------------------------
def sat_vp(t):
    """Saturation vapour pressure, kPa (eq. 11)."""
    return 0.6108 * math.exp(17.27 * t / (t + 237.3))


def slope_vp(t):
    """Slope of the saturation vapour pressure curve, kPa/degC (eq. 13)."""
    return 4098 * sat_vp(t) / (t + 237.3) ** 2


def pressure(z):
    """Atmospheric pressure, kPa, at elevation z metres (eq. 7)."""
    return 101.3 * ((293 - 0.0065 * z) / 293) ** 5.26


def extraterrestrial_radiation(lat_deg, doy):
    """Ra, MJ m-2 day-1 (eqs. 21-25)."""
    phi = math.radians(lat_deg)
    dr = 1 + 0.033 * math.cos(2 * math.pi * doy / 365)
    delta = 0.409 * math.sin(2 * math.pi * doy / 365 - 1.39)
    ws = math.acos(max(-1.0, min(1.0, -math.tan(phi) * math.tan(delta))))
    return (24 * 60 / math.pi) * 0.0820 * dr * (ws * math.sin(phi) * math.sin(delta) + math.cos(phi) * math.cos(delta) * math.sin(ws))


def et0_day(lat, z, doy, tmax, tmin, rh_mean, u2, rs):
    """FAO-56 Penman-Monteith ET0, mm/day, daily step, soil heat flux G = 0."""
    tmean = (tmax + tmin) / 2
    es = (sat_vp(tmax) + sat_vp(tmin)) / 2
    ea = rh_mean / 100 * es  # eq. 19-20 form using mean relative humidity
    ra = extraterrestrial_radiation(lat, doy)
    rso = (0.75 + 2e-5 * z) * ra
    rns = (1 - 0.23) * rs
    ratio = min(1.0, rs / rso) if rso > 0 else 0.5
    rnl = SIGMA * (((tmax + 273.16) ** 4 + (tmin + 273.16) ** 4) / 2) * (0.34 - 0.14 * math.sqrt(max(ea, 0))) * (1.35 * ratio - 0.35)
    rn = rns - rnl
    gamma = 0.000665 * pressure(z)
    d = slope_vp(tmean)
    num = 0.408 * d * rn + gamma * 900 / (tmean + 273) * u2 * (es - ea)
    return max(0.0, num / (d + gamma * (1 + 0.34 * u2)))


# ---- weather loading --------------------------------------------------------------------
class SiteWeather:
    def __init__(self, path):
        j = json.loads(pathlib.Path(path).read_text())
        lon, self.lat, self.z = j["geometry"]["coordinates"]
        p = j["properties"]["parameter"]
        self.et0 = {}
        for k in p["T2M_MAX"]:
            vals = [p[n][k] for n in ("T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "ALLSKY_SFC_SW_DWN")]
            if any(v < -900 for v in vals):
                continue
            tmax, tmin, rh, u2, rs = vals
            day = dt.date(int(k[:4]), int(k[4:6]), int(k[6:]))
            self.et0[day] = et0_day(self.lat, self.z, day.timetuple().tm_yday, tmax, tmin, rh, u2, rs)
        self.years = sorted({d.year for d in self.et0})


def load_params(path=None):
    return yaml.safe_load((pathlib.Path(path) if path else ROOT / "models" / "water_crops.yaml").read_text(encoding="utf8"))


# ---- crop season -----------------------------------------------------------------------
def kc_for_day(crop, n):
    """Kc on day n (0-based) after sowing: FAO-56 piecewise-linear curve through the four stages."""
    ini, dev, mid, late = crop["stage_days"]
    k_ini, k_mid, k_end = crop["kc"]["ini"], crop["kc"]["mid"], crop["kc"]["end"]
    if n < ini:
        return k_ini
    if n < ini + dev:
        return k_ini + (n - ini) / dev * (k_mid - k_ini)
    if n < ini + dev + mid:
        return k_mid
    if n < ini + dev + mid + late:
        return k_mid + (n - ini - dev - mid) / late * (k_end - k_mid)
    return k_end


def season_need(w, crop, year, sow_month=None, sow_day=None):
    """Total ETc (mm), peak 10-day ETc (mm) and length for one crop sown in a given year; None if the record is short."""
    m = sow_month or crop["sowing"]["month"]
    dd = sow_day or crop["sowing"]["day"]
    sow = dt.date(year, m, dd)
    n_days = sum(crop["stage_days"])
    daily = []
    for n in range(n_days):
        d = sow + dt.timedelta(days=n)
        if d not in w.et0:
            return None
        daily.append(kc_for_day(crop, n) * w.et0[d])
    peak10 = max(sum(daily[i:i + 10]) for i in range(len(daily) - 9))
    return {"etc_mm": sum(daily), "peak_10day_mm": peak10, "days": n_days, "peak_daily_mm": max(daily)}


def crop_water_need(w, params, crop_name, sow_month=None, sow_day=None):
    """Seasonal crop water demand statistics across all complete years in the weather record."""
    crop = params["crops"][crop_name]
    rows = [r for r in (season_need(w, crop, y, sow_month, sow_day) for y in w.years) if r]
    if not rows:
        raise ValueError("no complete season in the weather record")
    tot = sorted(r["etc_mm"] for r in rows)
    peak = sorted(r["peak_10day_mm"] for r in rows)
    pd = sorted(r["peak_daily_mm"] for r in rows)
    pick = lambda xs, q: xs[int(round(q * (len(xs) - 1)))]
    return {
        "crop": crop_name, "seasons": len(rows), "season_days": rows[0]["days"],
        "etc_mm_median": round(statistics.median(tot)), "etc_mm_p10": round(pick(tot, 0.1)), "etc_mm_p90": round(pick(tot, 0.9)),
        "peak_10day_mm_median": round(statistics.median(peak)), "peak_daily_mm_median": round(statistics.median(pd), 1),
        "excludes": crop.get("excludes", []),
        "provenance": {"weather": "NASA POWER daily (reanalysis, about 50 km cell)", "method": "FAO-56 Penman-Monteith ET0 x Kc",
                       "kc_and_stages": crop.get("evidence_note", "see models/water_crops.yaml"), "sowing_date": crop["sowing"].get("note", "")},
    }


def turn_check(need, interval_days):
    """Water the field must receive at each turn so that the crop's demand is met between turns (ET only)."""
    return {"days_between_turns": interval_days,
            "mm_needed_per_turn_at_peak": round(need["peak_daily_mm_median"] * interval_days),
            "note": "Crop demand only. Add irrigation losses, and for rice ponding and percolation, which are not modelled."}
