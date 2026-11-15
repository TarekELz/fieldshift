"""Print the markdown result tables used in docs/methodology.md, computed from the engines and the POWER files."""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import calendar_engine as cal, water_engine as wat, salt_engine as salt

cfg = cal.load_config()
dates = [(11, 1), (11, 15), (12, 1), (12, 15), (1, 10)]
print("### Wheat heat by sowing date (32 C, method B; median hot days in grain filling, 10th-90th percentile; extra days vs 15 Nov at 30/32/34 C)\n")
print("| Sown | Gharbia | Kafr El-Sheikh | Beheira | Menoufia / Sharqia (same cell) |\n|---|---|---|---|---|")
sites = ["gharbia", "kafr_el_sheikh", "beheira", "menoufia"]
W = {s: cal.Weather.from_power_json(ROOT / "data/raw/power" / f"{s}_daily.json") for s in sites}
CMP = {s: cal.compare_sowing(W[s], dates, cfg) for s in sites}
for i, (m, d) in enumerate(dates):
    cells = []
    for s in sites:
        r = CMP[s]["rows"][i]; e = r["extra_vs_baseline"]
        cells.append(f"{r['heat_days_median']:.0f} ({r['heat_days_p10_p90'][0]:.0f}-{r['heat_days_p10_p90'][1]:.0f}); {e[30.0]:+d}/{e[32.0]:+d}/{e[34.0]:+d}")
    print(f"| {d:02d}/{m:02d} | " + " | ".join(cells) + " |")
print("\nMedian maturity for a 15 Nov sowing (one thermal constant for all sites): " + ", ".join(f"{s} {cal.heat_risk(W[s], 11, 15, cfg)['median_maturity']}" for s in sites))
print(f"\nReference thermal-time constant: {round(cal.reference_gdd())} degree-days (base {cfg['phenology']['base_temp_c']} C) from sowing to maturity.")
print("\n### Summer crop water need (FAO-56 ETc, mm per season, median and 10th-90th percentile over 1990-2024)\n")
print("| Crop | Gharbia | Kafr El-Sheikh | Beheira | Menoufia / Sharqia |\n|---|---|---|---|---|")
P = wat.load_params(); SW = {s: wat.SiteWeather(ROOT / "data/raw/power" / f"{s}_daily.json") for s in sites}
for c in P["crops"]:
    cells = []
    for s in sites:
        r = wat.crop_water_need(SW[s], P, c); cells.append(f"{r['etc_mm_median']} ({r['etc_mm_p10']}-{r['etc_mm_p90']})")
    print(f"| {c} ({P['crops'][c]['sowing']['day']:02d}/{P['crops'][c]['sowing']['month']:02d}, {sum(P['crops'][c]['stage_days'])} d) | " + " | ".join(cells) + " |")
import statistics as st
a = {}
for d, v in SW["gharbia"].et0.items(): a.setdefault(d.year, 0); a[d.year] += v
print(f"\nGharbia annual reference ET0 (mean of full years): {round(st.mean(v for y, v in a.items() if y < 2025))} mm.")
print("\n### Salt: yield potential (%) by soil salinity, FAO paper 29 table linearly interpolated\n")
T = salt.load_table(); ec = [2, 4, 6, 8, 12]
print("| Crop | " + " | ".join(f"ECe {e}" for e in ec) + " |\n|---|" + "---|" * len(ec))
for c in ["wheat", "rice", "maize", "cotton", "berseem"]:
    print(f"| {c} | " + " | ".join(("n/a (<50)" if (y := salt.yield_potential(T[c]['points'], e)) is None else f"{y:.0f}") for e in ec) + " |")
