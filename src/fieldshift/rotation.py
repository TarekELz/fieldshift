"""Rotation comparison (draft): joins the wheat calendar, water and salt engines.

A rotation here is one summer crop followed by wheat. For each sequence the farmer states the summer
crop, optionally when it is sown, and when the wheat goes in. The module compares the sequences on:
  - summer water demand (FAO-56 on NASA POWER weather), as a ratio to the first sequence (the farmer's
    existing rotation) because absolute millimetres are not checked against ground data yet;
  - heat met by the following wheat during grain filling (calendar engine), relative to a mid-November
    sowing;
  - salt fit of both crops for the farmer's soil (salt engine);
and states, for every sequence, why it was included, what supports it, the gaps, and the risks that
need local review. It never ranks sequences into a single "best": the trade-offs are shown.

NOT modelled: nitrogen fixation or soil organic matter, pests and disease, market prices and income,
labour and machinery, rice ponding and percolation, and the farmer's actual canal supply.
Supports, and does not replace, the farmer's judgement and local agricultural advice.
"""
from __future__ import annotations

import datetime as dt
import pathlib

import yaml

from . import calendar_engine as cal
from . import salt_engine as salt
from . import water_engine as wat

ROOT = pathlib.Path(__file__).resolve().parents[2]
SUMMER = ("rice", "maize", "cotton")
NOT_MODELLED = ["nitrogen fixation and soil organic matter", "pests and disease", "market prices and income",
                "labour and machinery", "rice ponding and percolation", "the farmer's canal supply (ask the farmer)"]


def load_sites():
    """The named sites (models/sites.yaml) plus the extra NASA cells (models/cells.yaml, written by scripts/build_cells.py), if that file exists."""
    sites = yaml.safe_load((ROOT / "models" / "sites.yaml").read_text(encoding="utf8"))["sites"]
    cells = ROOT / "models" / "cells.yaml"
    if cells.exists():
        sites = {**sites, **(yaml.safe_load(cells.read_text(encoding="utf8")) or {}).get("cells", {})}
    return sites


def power_dir_for(site, power_dir=None):
    """Where a site's NASA POWER daily file lives: data/raw/power for named sites, data/raw/power_cells for extra cells."""
    if power_dir:
        return pathlib.Path(power_dir)
    return ROOT / "data" / "raw" / ("power_cells" if site.startswith("cell_") else "power")


def _harvest(crop_params, month, day, year=2001):
    sow = dt.date(year, month, day)
    return sow + dt.timedelta(days=sum(crop_params["stage_days"]))


def compare_rotations(site, sequences, ece=None, signs=None, interval_days=None, power_dir=None):
    """Compare sequences for a site. Each sequence is a dict:
        {"name": str, "summer_crop": "rice|maize|cotton", "summer_sowing": (m, d) optional, "wheat_sowing": (m, d)}
    The first sequence is treated as the farmer's existing rotation (baseline for ratios).
    """
    if not sequences:
        raise ValueError("give at least one sequence")
    sites = load_sites()
    if site not in sites:
        raise ValueError("unknown site: " + site)
    power = power_dir_for(site, power_dir)
    ccfg, params = cal.load_config(), wat.load_params()
    cw = cal.Weather.from_power_json(power / f"{site}_daily.json")
    ww = wat.SiteWeather(power / f"{site}_daily.json")
    table = salt.load_table()
    wheat_dates = [tuple(s["wheat_sowing"]) for s in sequences]
    heat = cal.compare_sowing(cw, wheat_dates, ccfg)
    rows, base_etc = [], None
    for i, s in enumerate(sequences):
        crop = s["summer_crop"]
        if crop not in params["crops"]:
            raise ValueError(f"summer crop must be one of {', '.join(SUMMER)}")
        cp = params["crops"][crop]
        sm, sd = s.get("summer_sowing") or (cp["sowing"]["month"], cp["sowing"]["day"])
        need = wat.crop_water_need(ww, params, crop, sm, sd)
        base_etc = base_etc or need["etc_mm_median"]
        harvest = _harvest(cp, sm, sd)
        wm, wd = s["wheat_sowing"]
        wheat_sow = dt.date(2001 if wm >= 10 else 2002, wm, wd)
        gap = (wheat_sow - harvest).days
        h = heat["rows"][i]
        salt_res = None
        if ece is not None or signs is not None:
            a = salt.assess([crop if crop in table else "maize", "wheat"], ece=ece, signs=signs, table=table)
            salt_res = {"ece_ds_m": a["ece_ds_m"], "basis": a["basis"], "summer": a["crops"][crop if crop in table else "maize"], "wheat": a["crops"]["wheat"]}
        warns = []
        if gap < 0:
            warns.append(f"wheat is sown {-gap} days before the summer crop would finish; check the dates")
        if gap < 14 and gap >= 0:
            warns.append(f"only {gap} days between the summer harvest and wheat sowing")
        row = {
            "name": s.get("name", f"{crop} then wheat"), "role": "existing rotation" if i == 0 else "alternative",
            "summer_crop": crop, "summer_sowing": f"{sd:02d}/{sm:02d}", "summer_harvest_estimate": harvest.strftime("%d %b"),
            "wheat_sowing": f"{wd:02d}/{wm:02d}", "days_between_harvest_and_wheat": gap,
            "water": {"etc_mm_median": need["etc_mm_median"], "etc_mm_p10_p90": (need["etc_mm_p10"], need["etc_mm_p90"]),
                      "ratio_to_existing": round(need["etc_mm_median"] / base_etc, 2), "peak_daily_mm": need["peak_daily_mm_median"],
                      "excludes": need["excludes"], "absolute_mm_checked_against_ground_data": False},
            "wheat_heat": {"heat_days_median_at_32c": h["heat_days_median"], "p10_p90": h["heat_days_p10_p90"],
                           "extra_heat_days_vs_15_nov": h["extra_vs_baseline"], "baseline_sowing": heat["baseline"],
                           "seasons_dropped": h["seasons_dropped"]},
            "salt": salt_res, "warnings": warns,
        }
        if interval_days:
            row["water"]["turn_check"] = wat.turn_check({"peak_daily_mm_median": need["peak_daily_mm_median"]}, interval_days)
        row["why_included"] = ("This is the farmer's current rotation, used as the baseline." if i == 0 else
                               f"Alternative summer crop ({crop}) and wheat date, to compare water need and wheat heat with the current rotation.")
        row["evidence"] = [
            {"claim": "Later wheat sowing meets more heat during grain filling in NASA POWER 1990-2025 temperatures", "tag": "NASA POWER (model)", "confidence": "medium for direction, low for the numbers"},
            {"claim": "In field trials wheat sown 7-13 January lost about 40% yield versus mid-November sowing, partly through more rust", "tag": "literature: elbasyoni2018 (full text)", "confidence": "medium"},
            {"claim": "Summer crop water need from FAO-56 Penman-Monteith with NASA POWER weather", "tag": "NASA POWER + FAO-56", "confidence": "medium for ratios, unchecked for millimetres"},
        ]
        row["gaps"] = ["The 32 C heat threshold, grain-filling window and thermal-time constant are assumptions (see models/wheat_calendar.yaml)",
                       "NASA POWER cells are about 50 km; temperatures have not been checked against Delta weather stations",
                       "Summer sowing dates are assumed unless the farmer gave them"]
        row["risks"] = ["Heat days are not converted to yield loss: no source for the conversion", "Not modelled: " + "; ".join(NOT_MODELLED),
                        "Check with the local extension agent before changing a rotation"]
        rows.append(row)
    s_ = sites[site]
    return {"site": site, "site_name": s_["name_en"], "site_caveat": s_.get("weather_caveat"),
            "rotations": rows, "not_modelled": NOT_MODELLED,
            "data_note": "Weather: NASA POWER daily 1990-2025 (reanalysis, about 50 km cell). Salt: farmer input + FAO paper 29. No NASA product measures soil salinity.",
            "notice": "Supports, does not replace, the farmer's judgement and local agricultural expertise."}


def render_text(res):
    """Plain-language summary used by the command line and as the grounding text for the assistant."""
    out = [f"{res['site_name']}"]
    if res["site_caveat"]:
        out.append("CAUTION: " + res["site_caveat"])
    for r in res["rotations"]:
        w, h = r["water"], r["wheat_heat"]
        out.append(f"\n[{r['role']}] {r['name']}: summer {r['summer_crop']} sown {r['summer_sowing']}, harvest about {r['summer_harvest_estimate']}; wheat sown {r['wheat_sowing']} ({r['days_between_harvest_and_wheat']} days later)")
        floor = any("percolation" in x for x in w["excludes"])
        out.append(f"  water: {r['summer_crop']} needs about {w['etc_mm_median']} mm of crop evapotranspiration ({w['ratio_to_existing']}x the existing rotation); millimetres not checked against ground data"
                   + ("; this is a FLOOR for rice (ponding and percolation are not included), so comparisons with rice understate the other crops' relative advantage" if floor else ""))
        if "turn_check" in w:
            tc = w["turn_check"]
            out.append(f"  canal turns: with {tc['days_between_turns']} days between turns, each turn must supply at least {tc['mm_needed_per_turn_at_peak']} mm at the peak (crop use only, no losses)")
        ex = h["extra_heat_days_vs_15_nov"]
        out.append(f"  wheat heat: median {h['heat_days_median_at_32c']} days at or above 32 C during grain filling (10th-90th percentile {h['p10_p90'][0]:.0f}-{h['p10_p90'][1]:.0f}); against a {h['baseline_sowing']} sowing that is {ex[30.0]:+d}/{ex[32.0]:+d}/{ex[34.0]:+d} days at 30/32/34 C (a comparison of dates, not a forecast)")
        if r["salt"]:
            s = r["salt"]
            out.append(f"  salt (ECe {s['ece_ds_m']} dS/m): summer crop {s['summer']['status']}, wheat {s['wheat']['status']}  [{s['basis']}]")
        for wmsg in r["warnings"]:
            out.append("  WARNING: " + wmsg)
    out.append("\nNot modelled: " + "; ".join(res["not_modelled"]))
    out.append(res["notice"])
    return "\n".join(out)


DEMO = [
    {"name": "Late rice then wheat", "summer_crop": "rice", "summer_sowing": (6, 15), "wheat_sowing": (12, 1)},
    {"name": "Maize then wheat", "summer_crop": "maize", "summer_sowing": (5, 1), "wheat_sowing": (11, 15)},
    {"name": "Cotton then wheat", "summer_crop": "cotton", "summer_sowing": (4, 1), "wheat_sowing": (11, 15)},
]

if __name__ == "__main__":
    import argparse
    import json
    ap = argparse.ArgumentParser(description="Compare three demo rotations (illustrative farmer inputs, not data)")
    ap.add_argument("--site", default="gharbia")
    ap.add_argument("--ece", type=float)
    ap.add_argument("--signs", choices=list(salt.SIGN_TO_ECE))
    ap.add_argument("--interval-days", type=int)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    r = compare_rotations(a.site, DEMO, ece=a.ece, signs=a.signs, interval_days=a.interval_days)
    print(json.dumps(r, indent=1, default=str) if a.json else render_text(r))
