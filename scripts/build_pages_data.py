"""Build docs/site/data.json for the project page (GitHub Pages): season scores per site and crop from the season engine (NASA POWER 1990-2025 + FAO
EcoCrop) and NASA MCD12Q2 phenology medians per site. Nothing here is invented: every number comes from the engines and the data files.

Run: .venv/Scripts/python scripts/build_pages_data.py   (needs data/raw/power and data/interim/phenology_sites.csv; run scripts/phenology_mcd12q2.py first)
"""
import csv
import datetime as dt
import json
import pathlib
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import season_engine as se  # noqa: E402

SITES = ["gharbia", "kafr_el_sheikh", "beheira", "menoufia", "sharqia", "damietta", "dakahlia"]
JUDGED = ["wheat", "rice", "maize", "cotton", "onion", "potato", "barley", "sorghum"]
NAMES = {"gharbia": "Gharbia", "kafr_el_sheikh": "Kafr El-Sheikh", "beheira": "Beheira", "menoufia": "Menoufia", "sharqia": "Sharqia", "damietta": "Damietta (sea-edge cell)", "dakahlia": "Dakahlia"}


def main():
    params = se.load_params()
    out = {"generated": dt.date.today().isoformat(), "sites": {}, "crops": JUDGED,
           "not_judged": {c: (se.UNRELIABLE.get(c) or "tree or vine: no sowing season") for c in ("berseem", "sugar_beet", "tomato", "faba_bean", "orange", "grape", "date_palm")}}
    ph = list(csv.DictReader(open(ROOT / "data" / "interim" / "phenology_sites.csv", encoding="utf8")))
    for s in SITES:
        w = se.SiteTemps(ROOT / "data" / "raw" / "power" / f"{s}_daily.json")
        crops = {}
        for c in JUDGED:
            scan = se.scan_year(w, params, c)
            crops[c] = {"cycle_days": se.CYCLE_DAYS[c][0], "scan": [[r["sowing"][0], r["sowing"][1], r["ideal_pct"], r["bad_pct"]] for r in scan]}
        cyc = {}
        for k in (1, 2):
            rs = [r for r in ph if r["site"] == s and int(r["cycle"]) == k]
            if len(rs) >= 4:
                doy = lambda col: round(statistics.median(dt.date.fromisoformat(r[col]).timetuple().tm_yday for r in rs if r[col]))
                cyc[str(k)] = {"years": len(rs), "greenup": doy("greenup"), "peak": doy("peak"), "senescence": doy("senescence"), "dormancy": doy("dormancy")}
        out["sites"][s] = {"name": NAMES[s], "crops": crops, "phenology": cyc, "sea_edge": s == "damietta"}
    dest = ROOT / "docs" / "site"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "data.json").write_text(json.dumps(out, separators=(",", ":")), encoding="utf8")
    print("wrote", dest / "data.json", (dest / "data.json").stat().st_size, "bytes")
    # the app's exported tables, for the "Try Eyad" playground (same numbers as the app)
    (dest / "data").mkdir(exist_ok=True)
    for n in ("heat", "water", "salt", "meta", "blueprints", "season"):
        (dest / "data" / f"{n}.json").write_bytes((ROOT / "app" / "assets" / "data" / f"{n}.json").read_bytes())
    print("copied the app tables to", dest / "data")


if __name__ == "__main__":
    main()
