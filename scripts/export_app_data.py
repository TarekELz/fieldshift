"""Export the engines' results as small JSON lookup tables for the Flutter app (works offline, no server).

Writes app/assets/data/:
  heat.json    heat[site][wheat sowing "MM-DD"] = hot days in grain filling (median, p10, p90, extra days vs 15 Nov at 30/32/34 C)
  water.json   water[site][crop][summer sowing "MM-DD"] = crop evapotranspiration (median, p10, p90, peak daily, season days)
  salt.json    FAO paper 29 table points per crop, and the assumed ECe per sign class
  meta.json    sites with captions and caveats, crop stage lengths, notices, generation stamp
and app/test/fixtures/rotation_cases.json: full Python comparisons that the Dart code must reproduce.

Run: .venv/Scripts/python scripts/export_app_data.py
"""
import datetime as dt
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import advice, calendar_engine as cal, rotation, salt_engine as salt, season_engine as se, water_engine as wat  # noqa: E402

OUT = ROOT / "app" / "assets" / "data"
FIX = ROOT / "app" / "test" / "fixtures"
SITES = ["gharbia", "kafr_el_sheikh", "beheira", "menoufia", "sharqia", "damietta", "dakahlia"]
SOWING_WINDOWS = {"rice": ((5, 1), (6, 30)), "maize": ((4, 15), (5, 31)), "cotton": ((3, 15), (5, 15))}


GRID_DAYS = (1, 10, 15, 20, 25)  # early, 10th, middle, 20th, late month: how a farmer says a date


def days(start, end, _step=None):
    """Grid dates between start and end (month, day), inclusive, crossing the year end if needed."""
    d = dt.date(2001, *start)
    e = dt.date(2001 if end >= start else 2002, *end)
    while d <= e:
        if d.day in GRID_DAYS:
            yield d.month, d.day
        d += dt.timedelta(days=1)


def key(m, d):
    return f"{m:02d}-{d:02d}"


def _advice_ids(res, w, sparams):
    """Which blueprints the Python advice layer selects (the Dart code must select the same ones)."""
    ex = res["rotations"][0]
    sm, sd = (int(x) for x in reversed(ex["summer_sowing"].split("/")))
    wm, wd = (int(x) for x in reversed(ex["wheat_sowing"].split("/")))
    f = advice.facts_from(res, se.verdict(w, sparams, ex["summer_crop"], sm, sd), se.verdict(w, sparams, "wheat", wm, wd))
    sel = advice.select(f)
    return {"primary": sel[0]["id"], "closeness": sel[0]["closeness"], "also": [s["id"] for s in sel[1:]]}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    FIX.mkdir(parents=True, exist_ok=True)
    cfg, params, sites = cal.load_config(), wat.load_params(), rotation.load_sites()
    wheat_dates = list(days((11, 1), (1, 31)))
    heat, water = {}, {}
    for s in SITES:
        w = cal.Weather.from_power_json(ROOT / "data/raw/power" / f"{s}_daily.json")
        c = cal.compare_sowing(w, wheat_dates, cfg)
        heat[s] = {}
        for (m, d), row in zip(wheat_dates, c["rows"]):
            e = row["extra_vs_baseline"]
            per = cal.heat_risk(w, m, d, cfg)["per_season"]  # hot days in each season, for the sparkline
            heat[s][key(m, d)] = {"median": row["heat_days_median"], "p10": row["heat_days_p10_p90"][0], "p90": row["heat_days_p10_p90"][1],
                                  "extra": {"30": e[30.0], "32": e[32.0], "34": e[34.0]}, "dropped": row["seasons_dropped"],
                                  "series": [per[y] for y in sorted(per)], "first_season": min(per)}
        sw = wat.SiteWeather(ROOT / "data/raw/power" / f"{s}_daily.json")
        water[s] = {}
        for crop, (a, b) in SOWING_WINDOWS.items():
            water[s][crop] = {}
            for m, d in days(a, b, 5):
                r = wat.crop_water_need(sw, params, crop, m, d)
                water[s][crop][key(m, d)] = {"etc": r["etc_mm_median"], "p10": r["etc_mm_p10"], "p90": r["etc_mm_p90"], "peak_daily": r["peak_daily_mm_median"], "days": r["season_days"]}
    table = salt.load_table()
    saltj = {"crops": {c: {"points": v["points"], "source": v["source"], "note": v["note"]} for c, v in table.items()},
             "sign_to_ece": salt.SIGN_TO_ECE, "sign_note": salt.SIGN_NOTE}
    meta = {
        "generated": dt.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "sites": {s: {"name_en": sites[s]["name_en"], "caveat": sites[s].get("weather_caveat"), "caveat_kind": sites[s].get("caveat_kind"), "shares_cell_with": sites[s].get("shares_cell_with"), "lat": sites[s]["lat"], "lon": sites[s]["lon"]} for s in SITES},
        "delta_bbox": [29.6, 30.0, 32.6, 31.7],  # lon_min, lat_min, lon_max, lat_max: where the data points apply
        "crops": {c: {"stage_days": params["crops"][c]["stage_days"], "excludes": params["crops"][c].get("excludes", [])} for c in params["crops"]},
        "not_modelled": rotation.NOT_MODELLED,
        "baseline_wheat_sowing": "11-15",
        "data_note": "Weather: NASA POWER daily 1990-2025 (reanalysis, about 50 km cell). Salt: farmer input + FAO paper 29. No NASA product measures soil salinity.",
    }
    climate = {}
    for s in SITES:
        raw = json.loads((ROOT / "data/raw/power" / f"{s}_daily.json").read_text())["properties"]["parameter"]
        monthly = {}
        for var in ("T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "PRECTOTCORR", "ALLSKY_SFC_SW_DWN"):
            by_m = {m: [] for m in range(1, 13)}
            for k, v in raw[var].items():
                if v > -900 and k < "20260101":
                    by_m[int(k[4:6])].append(v)
            monthly[var] = [round(sum(by_m[m]) / len(by_m[m]), 1) for m in range(1, 13)]
        days_in = [31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        monthly["RAIN_MM_MONTH"] = [round(monthly["PRECTOTCORR"][i] * days_in[i], 1) for i in range(12)]
        climate[s] = monthly
    meta["climate_note"] = "Monthly means of NASA POWER daily values, 1990-2025 (reanalysis, about 50 km cell)"
    for name, obj in (("heat", heat), ("water", water), ("salt", saltj), ("meta", meta), ("climate", climate)):
        (OUT / f"{name}.json").write_text(json.dumps(obj, ensure_ascii=False, indent=None, separators=(",", ":")), encoding="utf8")
    # season scores (temperature screen, decision D17) and the blueprint advices (D16/D18)
    sparams, season, stemps = se.load_params(), {}, {}
    for s in SITES:
        stemps[s] = se.SiteTemps(ROOT / "data/raw/power" / f"{s}_daily.json")
        season[s] = {c: [[r["sowing"][0], r["sowing"][1], r["ideal_pct"], r["bad_pct"]] for r in se.scan_year(stemps[s], sparams, c)] for c in ("wheat", "rice", "maize", "cotton")}
    (OUT / "season.json").write_text(json.dumps({"sites": season, "min_spread": se.MIN_SPREAD, "right_within": se.RIGHT_WITHIN, "so_so_within": se.SO_SO_WITHIN, "bad_share_wrong": se.BAD_SHARE_WRONG},
                                                separators=(",", ":")), encoding="utf8")
    (OUT / "blueprints.json").write_bytes((ROOT / "models" / "blueprints.json").read_bytes())
    # golden cases for the Dart tests
    cases = []
    for site in ("gharbia", "beheira", "kafr_el_sheikh", "dakahlia"):
        for signs, interval in ((None, None), ("patches", 10), ("crust", 14)):
            res = rotation.compare_rotations(site, rotation.DEMO, signs=signs, interval_days=interval)
            cases.append({"site": site, "signs": signs, "interval_days": interval,
                          "sequences": [{"summer_crop": s["summer_crop"], "summer_sowing": list(s["summer_sowing"]), "wheat_sowing": list(s["wheat_sowing"])} for s in rotation.DEMO],
                          "expected": [{"etc": r["water"]["etc_mm_median"], "ratio": r["water"]["ratio_to_existing"], "heat_median": r["wheat_heat"]["heat_days_median_at_32c"],
                                        "extra32": r["wheat_heat"]["extra_heat_days_vs_15_nov"][32.0], "gap": r["days_between_harvest_and_wheat"], "harvest": r["summer_harvest_estimate"],
                                        "turn_mm": r["water"].get("turn_check", {}).get("mm_needed_per_turn_at_peak"),
                                        "salt_summer": (r["salt"] or {}).get("summer", {}).get("status"), "salt_wheat": (r["salt"] or {}).get("wheat", {}).get("status")} for r in res["rotations"]],
                          "advice": _advice_ids(res, stemps[site], sparams)})
    (FIX / "rotation_cases.json").write_text(json.dumps(cases, indent=1), encoding="utf8")
    sizes = {n: (OUT / f"{n}.json").stat().st_size for n in ("heat", "water", "salt", "meta", "climate")}
    print("wrote", sizes, "and", len(cases), "golden cases")


if __name__ == "__main__":
    main()
