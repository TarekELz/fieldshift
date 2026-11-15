"""Crop economics (decision D20): a national-average gross income per feddan for each crop, adjusted for the farmer's soil salt.

gross income per feddan = national yield (FAOSTAT, 2020-2024 mean) x 0.42 ha x producer price (FAOSTAT, Egypt, 2022 annual mean) x salt factor.
The salt factor is FAO paper 29's relative yield potential at the farmer's soil salinity (1.0 with no salt problem; at most 0.5 when the table gives no value).
WHAT IT IS NOT: a forecast for a field, a profit (no costs are known), or NASA data. National averages hide large differences between fields; vegetables and
orchards cost far more to grow than field crops; prices have moved since 2022. Use it to compare crops with each other, never as a promise.
"""
from __future__ import annotations

import csv
import pathlib

import yaml

from . import salt_engine as salt

ROOT = pathlib.Path(__file__).resolve().parents[2]
SALT_UNKNOWN_FACTOR = 0.5  # FAO-29 gives no value above the 50% point: at most half


def load():
    """{crop: {en, ar, group, salt_key, season, water, aliases, yield_kg_ha, price_egp_per_t, ...}} for crops that have FAOSTAT numbers, plus the feddan size."""
    reg = yaml.safe_load((ROOT / "models" / "crops.yaml").read_text(encoding="utf8"))
    with open(ROOT / "models" / "crop_economics.csv", encoding="utf8") as f:
        rows = {r["crop"]: r for r in csv.DictReader(l for l in f if not l.startswith("#"))}
    out = {}
    for k, c in reg["crops"].items():
        if k in rows:
            r = rows[k]
            out[k] = {**c, "yield_kg_ha": int(r["yield_kg_ha"]), "price_egp_per_t": int(r["price_egp_per_t"]), "price_year": int(r["price_year"]), "yield_years": r["yield_years"]}
    return out, float(reg["feddan_ha"])


def salt_factor(crop, ece, crops, table=None):
    """(factor 0..1, pct or None, known). Unknown when there is no soil information or no FAO-29 row for the crop."""
    key = crops[crop]["salt_key"]
    table = table or salt.load_table()
    if ece is None or key is None or key not in table:
        return 1.0, None, False
    y = salt.yield_potential(table[key]["points"], ece)
    return (SALT_UNKNOWN_FACTOR, None, True) if y is None else (y / 100.0, round(y), True)


def gross_per_feddan(crop, ece=None, crops=None, feddan_ha=None, table=None):
    if crops is None:
        crops, feddan_ha = load()
    f, pct, known = salt_factor(crop, ece, crops, table)
    c = crops[crop]
    base = c["yield_kg_ha"] / 1000.0 * feddan_ha * c["price_egp_per_t"]
    return {"crop": crop, "gross_egp": round(base * f), "base_egp": round(base), "salt_pct": pct, "salt_known": known, "tonnes_per_feddan": round(c["yield_kg_ha"] / 1000.0 * feddan_ha * f, 1)}


def rank(group=None, ece=None, crops=None, feddan_ha=None, table=None):
    """Crops (of one group, or all) ordered by salt-adjusted gross income per feddan, highest first."""
    if crops is None:
        crops, feddan_ha = load()
    rows = [gross_per_feddan(k, ece, crops, feddan_ha, table) for k, c in crops.items() if group is None or c["group"] == group]
    return sorted(rows, key=lambda r: -r["gross_egp"])
