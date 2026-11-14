"""Wheat calendar engine (draft, before gate G3).

Question it answers: if wheat is sown on a given date at a given place, how much heat
does it meet while the grain is filling, judged over every season in the NASA POWER
record (1990-2025)?

Two transparent methods:
  A "fixed":   maturity = sowing + a fixed number of days.
  B "thermal": maturity when accumulated degree-days reach a target that is calibrated
               so the recommended sowing date matures on the usual local date.
Both then count days in the grain-filling window with Tmax at or above a threshold.

Inputs come from satellite-era reanalysis (NASA POWER, about 50 km cells), not from the
farmer's field. Outputs support, and do not replace, local expertise.
"""
from __future__ import annotations

import datetime as dt
import json
import pathlib
import statistics
from dataclasses import dataclass

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]


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

    def seasons(self):
        """Seasons (year of the autumn sowing) with a full record to the following June."""
        years = sorted({d.year for d in self.tmax})
        return [y for y in years if dt.date(y + 1, 6, 30) in self.tmax and dt.date(y, 9, 1) in self.tmax]


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
    """First day on which degree-days accumulated since sowing reach the target; None if never."""
    acc, d = 0.0, sow
    while d in w.tmax:
        acc += _gdd(w, d, base)
        if acc >= target:
            return d
        d += dt.timedelta(days=1)
    return None


def calibrate_gdd(w, cfg):
    """Degree-days from the recommended sowing date to the usual maturity date, median over seasons."""
    r, t, base = cfg["recommended_sowing"], cfg["phenology"]["calibration_target_maturity"], cfg["phenology"]["base_temp_c"]
    totals = []
    for s in w.seasons():
        d, end, acc = sowing_date(s, r["month"], r["day"]), dt.date(s + 1, t["month"], t["day"]), 0.0
        while d <= end:
            acc += _gdd(w, d, base)
            d += dt.timedelta(days=1)
        totals.append(acc)
    return statistics.median(totals)


def grain_fill_window(w, sow, cfg, method, gdd_target=None):
    """(start, end) of the assumed grain-filling window, or None if it cannot be computed."""
    ph, gf = cfg["phenology"], cfg["grain_filling"]
    if method == "fixed":
        end = maturity_fixed(sow, ph["days_to_maturity_fixed"])
        start = end - dt.timedelta(days=gf["last_days"])
    elif method == "thermal":
        end = maturity_thermal(w, sow, gdd_target, ph["base_temp_c"])
        if end is None:
            return None
        start_target = gdd_target * (1 - gf["last_gdd_fraction"])
        start = maturity_thermal(w, sow, start_target, ph["base_temp_c"])
    else:
        raise ValueError("method must be 'fixed' or 'thermal'")
    if start not in w.tmax or end not in w.tmax:
        return None
    return start, end


def heat_risk(w, month, day, cfg, method="thermal", threshold=None):
    """Heat exposure during grain filling for wheat sown on (month, day), across all seasons.

    Returns a dict with per-season heat-day counts and summary statistics. Raises
    ValueError for sowing dates outside 1 October to 28/29 February.
    """
    if month not in (10, 11, 12, 1, 2):
        raise ValueError("sowing month must be between October and February")
    thr = cfg["heat"]["tmax_threshold_c"] if threshold is None else threshold
    target = None
    if method == "thermal":
        target = cfg["phenology"].get("gdd_to_maturity") or calibrate_gdd(w, cfg)
    per, mats, lens = {}, [], []
    for s in w.seasons():
        sow = sowing_date(s, month, day)
        win = grain_fill_window(w, sow, cfg, method, target)
        if win is None:
            continue
        start, end = win
        n = sum(1 for i in range((end - start).days + 1) if w.tmax[start + dt.timedelta(days=i)] >= thr)
        per[s] = n
        mats.append(end.timetuple().tm_yday)
        lens.append((end - sow).days)
    if not per:
        raise ValueError("no complete season in the weather record for this sowing date")
    counts = sorted(per.values())
    med_doy = int(statistics.median(mats))
    return {
        "method": method,
        "threshold_c": thr,
        "seasons": len(per),
        "heat_days_median": statistics.median(counts),
        "heat_days_p10": counts[int(0.1 * (len(counts) - 1))],
        "heat_days_p90": counts[int(round(0.9 * (len(counts) - 1)))],
        "share_seasons_10plus_heat_days": round(sum(1 for c in counts if c >= 10) / len(counts), 2),
        "median_maturity": (dt.date(2001, 1, 1) + dt.timedelta(days=med_doy - 1)).strftime("%d %b"),
        "median_season_length_days": int(statistics.median(lens)),
        "gdd_target": None if target is None else round(target),
        "per_season": per,
        "provenance": {
            "temperature": "NASA POWER daily T2M_MAX/T2M_MIN (reanalysis, about 50 km cell)",
            "phenology": "model assumption, calibrated to the recommended sowing date; not observed",
            "threshold": "literature-style placeholder, low confidence",
        },
        "notice": "Supports, does not replace, the farmer's judgement and local agricultural advice.",
    }
