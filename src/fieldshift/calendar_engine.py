"""Wheat calendar engine (draft; review fixes applied 2026-11-15).

Question it answers: if wheat is sown on a given date at a given place, how does the heat
met during grain filling compare with other sowing dates, over every season in the NASA
POWER record (1990-2025)?

Read the results as a RELATIVE comparison of sowing dates, not as a forecast of heat days or
of yield. The only supporting evidence is the direction found in field trials (elbasyoni2018).

Two transparent methods:
  A "fixed":   maturity = sowing + a fixed number of days.
  B "thermal": maturity when accumulated degree-days (base temperature from the YAML) reach one
               target for the whole Delta, calibrated once on a reference site so that the
               recommended sowing date matures on the usual date there. The calibration is an
               assumption, so the maturity date at the reference site is true by construction
               and is NOT a result.
Both then count days in the grain-filling window with Tmax at or above a threshold.

Inputs are reanalysis temperatures (NASA POWER, about 50 km cells), not field measurements.
Outputs support, and do not replace, local expertise.
"""
from __future__ import annotations

import datetime as dt
import functools
import json
import pathlib
import statistics
from dataclasses import dataclass

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
ONE_DAY = dt.timedelta(days=1)


@dataclass
class Weather:
    tmax: dict  # date -> deg C
    tmin: dict

    @classmethod
    def from_power_json(cls, path):
        p = json.loads(pathlib.Path(path).read_text())["properties"]["parameter"]

        def conv(d):
            return {dt.date(int(k[:4]), int(k[4:6]), int(k[6:])): v for k, v in d.items() if v > -900}

        return cls(conv(p["T2M_MAX"]), conv(p["T2M_MIN"]))

    def has(self, day):
        return day in self.tmax and day in self.tmin

    def seasons(self):
        """Seasons (year of the autumn sowing) whose record runs from 1 Sep to 30 Jun of the next year."""
        years = sorted({d.year for d in self.tmax})
        return [y for y in years if self.has(dt.date(y + 1, 6, 30)) and self.has(dt.date(y, 9, 1))]


def load_config(path=None):
    return yaml.safe_load((pathlib.Path(path) if path else ROOT / "models" / "wheat_calendar.yaml").read_text(encoding="utf8"))


def sowing_date(season, month, day):
    """Sowing date for a season. Months January-June belong to the following calendar year."""
    year = season + 1 if month <= 6 else season
    if month == 2 and day == 29:
        try:
            return dt.date(year, 2, 29)
        except ValueError:
            return dt.date(year, 2, 28)
    return dt.date(year, month, day)


def _gdd(w, day, base):
    return max(0.0, (w.tmax[day] + w.tmin[day]) / 2.0 - base)


def maturity_fixed(sow, days):
    return sow + dt.timedelta(days=days)


def maturity_thermal(w, sow, target, base):
    """First day on which degree-days accumulated since sowing reach the target; None if never or data gap."""
    acc, d = 0.0, sow
    while w.has(d):
        acc += _gdd(w, d, base)
        if acc >= target:
            return d
        d += ONE_DAY
    return None


def calibrate_gdd(w, cfg):
    """Degree-days from the recommended sowing date to the target maturity date, median over seasons."""
    r, t, base = cfg["recommended_sowing"], cfg["phenology"]["calibration_target_maturity"], cfg["phenology"]["base_temp_c"]
    totals = []
    for s in w.seasons():
        d, end, acc, ok = sowing_date(s, r["month"], r["day"]), dt.date(s + 1, t["month"], t["day"]), 0.0, True
        while d <= end:
            if not w.has(d):
                ok = False
                break
            acc += _gdd(w, d, base)
            d += ONE_DAY
        if ok:
            totals.append(acc)
    if not totals:
        raise ValueError("cannot calibrate: no complete season")
    return statistics.median(totals)


@functools.lru_cache(maxsize=1)
def reference_gdd():
    """The single thermal-time target used for every site, calibrated on the reference site in the YAML."""
    cfg = load_config()
    site = cfg["phenology"]["calibration_site"]
    return calibrate_gdd(Weather.from_power_json(ROOT / "data" / "raw" / "power" / f"{site}_daily.json"), cfg)


def grain_fill_window(w, sow, cfg, method, gdd_target=None):
    """(start, end) of the assumed grain-filling window, or None if it cannot be computed (gap or short record)."""
    ph, gf = cfg["phenology"], cfg["grain_filling"]
    if method == "fixed":
        end = maturity_fixed(sow, ph["days_to_maturity_fixed"])
        start = end - dt.timedelta(days=gf["last_days"])
    elif method == "thermal":
        end = maturity_thermal(w, sow, gdd_target, ph["base_temp_c"])
        if end is None:
            return None
        start = maturity_thermal(w, sow, gdd_target * (1 - gf["last_gdd_fraction"]), ph["base_temp_c"])
        if start is None:
            return None
    else:
        raise ValueError("method must be 'fixed' or 'thermal'")
    n = (end - start).days + 1
    if any(not w.has(start + dt.timedelta(days=i)) for i in range(n)):
        return None
    return start, end


def _percentiles(values):
    """10th and 90th percentile (inclusive method); the single value if fewer than two."""
    if len(values) < 2:
        return values[0], values[0]
    q = statistics.quantiles(values, n=10, method="inclusive")
    return q[0], q[8]


def _doy_noleap(d):
    return (dt.date(2001, d.month, 28 if (d.month == 2 and d.day == 29) else d.day) - dt.date(2001, 1, 1)).days + 1


def heat_risk(w, month, day, cfg, method="thermal", threshold=None, gdd_target=None):
    """Heat exposure during grain filling for wheat sown on (month, day), across all seasons.

    Thermal method: `gdd_target` defaults to the config value, else the reference-site calibration
    (reference_gdd()). Pass gdd_target explicitly to calibrate on other weather (used in tests).
    Raises ValueError for sowing dates outside 1 October to 28/29 February, or if no season is usable.
    """
    if month not in (10, 11, 12, 1, 2):
        raise ValueError("sowing month must be between October and February")
    thr = cfg["heat"]["tmax_threshold_c"] if threshold is None else threshold
    if method == "thermal" and gdd_target is None:
        gdd_target = cfg["phenology"].get("gdd_to_maturity") or reference_gdd()
    per, mats, lens, dropped = {}, [], [], 0
    for s in w.seasons():
        sow = sowing_date(s, month, day)
        win = grain_fill_window(w, sow, cfg, method, gdd_target)
        if win is None:
            dropped += 1
            continue
        start, end = win
        per[s] = sum(1 for i in range((end - start).days + 1) if w.tmax[start + dt.timedelta(days=i)] >= thr)
        mats.append(_doy_noleap(end))
        lens.append((end - sow).days)
    if not per:
        raise ValueError("no complete season in the weather record for this sowing date")
    counts = sorted(per.values())
    p10, p90 = _percentiles(counts)
    med_doy = int(statistics.median(mats))
    return {
        "method": method,
        "threshold_c": thr,
        "seasons": len(per),
        "seasons_dropped": dropped,
        "heat_days_median": statistics.median(counts),
        "heat_days_p10": p10,
        "heat_days_p90": p90,
        "share_seasons_10plus_heat_days": round(sum(1 for c in counts if c >= 10) / len(counts), 2),
        "median_maturity": (dt.date(2001, 1, 1) + dt.timedelta(days=med_doy - 1)).strftime("%d %b"),
        "median_season_length_days": int(statistics.median(lens)),
        "gdd_target": None if gdd_target is None else round(gdd_target),
        "per_season": per,
        "provenance": {
            "temperature": "NASA POWER daily T2M_MAX/T2M_MIN (reanalysis, about 50 km cell)",
            "phenology": "model assumption, one thermal-time constant calibrated on the reference site; maturity dates are not observed",
            "threshold": "placeholder, low confidence; see sensitivity",
        },
        "notice": "Supports, does not replace, the farmer's judgement and local agricultural advice.",
    }


def compare_sowing(w, dates, cfg, baseline=None, method="thermal"):
    """Heat comparison of several sowing dates, each relative to a baseline (default: the recommended date).

    `dates` is a list of (month, day). Returns one row per date with heat days at 30, 32 and 34 C
    so the ranking can be checked at every threshold.
    """
    r = cfg["recommended_sowing"]
    base = baseline or (r["month"], r["day"])
    ref = {t: heat_risk(w, base[0], base[1], cfg, method, t)["heat_days_median"] for t in cfg["heat"]["sensitivity_thresholds_c"]}
    rows = []
    for m, d in dates:
        by_thr, main = {}, None
        for t in cfg["heat"]["sensitivity_thresholds_c"]:
            h = heat_risk(w, m, d, cfg, method, t)
            by_thr[t] = h["heat_days_median"]
            if t == cfg["heat"]["tmax_threshold_c"]:
                main = h
        rows.append({"sowing": f"{d:02d}/{m:02d}", "heat_days_median": main["heat_days_median"],
                     "heat_days_p10_p90": (main["heat_days_p10"], main["heat_days_p90"]),
                     "extra_vs_baseline": {t: by_thr[t] - ref[t] for t in by_thr}, "by_threshold": by_thr,
                     "seasons_dropped": main["seasons_dropped"]})
    return {"baseline": f"{base[1]:02d}/{base[0]:02d}", "rows": rows}
