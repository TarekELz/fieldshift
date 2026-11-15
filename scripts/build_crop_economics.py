"""Build models/crop_economics.csv from the FAOSTAT bulk files (Egypt): national average yield and producer price per crop.

Inputs (not committed): data/raw/faostat/production/Production_Crops_Livestock_E_All_Data_(Normalized).csv and
data/raw/faostat/prices/Prices_E_All_Data_(Normalized).csv, downloaded from https://bulks-faostat.fao.org/production/ (FAO, open statistics).
Yield: mean of 2020-2024, kg/ha. Price: producer price in Egyptian pounds per tonne, annual mean (months averaged) for ONE common year, 2022, so crops are
comparable: FAOSTAT's Egypt prices are patchy (some years are a single annual value, some are monthly, a few years have obvious errors such as Orange and Grape 2023).
These are NATIONAL AVERAGES: gross income before any cost, not a forecast for a field. Run: .venv/Scripts/python scripts/build_crop_economics.py
"""
import csv
import pathlib
import statistics
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "faostat"
ITEMS = {"rice": "Rice", "wheat": "Wheat", "maize": "Maize (corn)", "cotton": "Seed cotton, unginned", "sugar_beet": "Sugar beet",
         "onion": "Onions and shallots, dry (excluding dehydrated)", "potato": "Potatoes", "tomato": "Tomatoes", "orange": "Oranges",
         "faba_bean": "Broad beans and horse beans, dry", "grape": "Grapes", "date_palm": "Dates", "barley": "Barley", "sorghum": "Sorghum"}
PRICE_YEAR = 2022
YIELD_YEARS = range(2020, 2025)


def egypt(path):
    with open(path, encoding="latin-1", newline="") as f:
        for r in csv.DictReader(f):
            if r["Area"] == "Egypt":
                yield r


def main():
    prod = list(egypt(RAW / "production" / "Production_Crops_Livestock_E_All_Data_(Normalized).csv"))
    price = list(egypt(RAW / "prices" / "Prices_E_All_Data_(Normalized).csv"))
    out = []
    for key, item in ITEMS.items():
        ys = [float(r["Value"]) for r in prod if r["Item"] == item and r["Element"] == "Yield" and r["Value"] and int(r["Year"]) in YIELD_YEARS]
        pm = defaultdict(list)
        for r in price:
            if r["Item"] == item and r["Element"] == "Producer Price (LCU/tonne)" and r["Value"]:
                pm[int(r["Year"])].append(float(r["Value"]))
        if len(ys) < 3 or PRICE_YEAR not in pm:
            print("skipped", key, "(not enough FAOSTAT data)")
            continue
        out.append({"crop": key, "faostat_item": item, "yield_kg_ha": round(statistics.mean(ys)), "yield_years": f"{min(YIELD_YEARS)}-{max(YIELD_YEARS)}",
                    "price_egp_per_t": round(statistics.mean(pm[PRICE_YEAR])), "price_year": PRICE_YEAR, "price_values_averaged": len(pm[PRICE_YEAR])})
    path = ROOT / "models" / "crop_economics.csv"
    with open(path, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
        f.write("# Source: FAOSTAT (FAO), Egypt: crops and livestock products (yield) and producer prices (LCU per tonne). National averages, gross before costs. Not NASA data.\n")
    print("wrote", path, len(out), "crops")


if __name__ == "__main__":
    main()
