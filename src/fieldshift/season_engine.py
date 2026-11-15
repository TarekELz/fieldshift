"""Season engine (draft, decision D17): is a crop sown at the right time of year for this place? A temperature screen.

For a crop sown on a date at a place, over every year of NASA POWER weather (1990-2025), it counts the share of the crop's growing days whose
mean temperature is
  ideal      inside the crop's optimal range (EcoCrop TOPMN..TOPMX),
  tolerable  outside optimal but inside the absolute range (TMIN..TMAX),
  bad        outside the absolute range, and
  frost      days whose minimum temperature is below the crop's killing temperature (KTMP); None when EcoCrop gives no KTMP (unknown, not zero).
Each share is the median over years, taken separately, so the three can differ from 100 by a point or two.
It then scans sowing dates through the year (1st and 15th of each month) and reports the best window and how much better it is.

Sources: crop temperatures and cycle length from the FAO EcoCrop database (models/ecocrop_subset.csv: generic global values, not Egypt-specific);
NASA POWER daily T2M and T2M_MIN. The cycle length comes from the source named in CYCLE_DAYS.

WHAT IT IS NOT: no yield or money prediction. Temperature only: no water, salt, day length, vernalisation, pests or market. EcoCrop ranges are
coarse (for example wheat TMAX 27 C is below the grain-filling heat that Delta wheat often meets), so use the result as a screen and a comparison
between sowing dates, not as an absolute truth. The labels (right season / so-so / wrong season) compare the sowing date with the best date of the
year; their thresholds are a TEAM ASSUMPTION (not from a source), and MIN_SPREAD was chosen after looking at Gharbia and Beheira (checked at both).

NOT JUDGED (answer "cannot judge" with a fixed reason): perennials (no sowing season: the cycle starts at bud-break or planting once), and crops where
the temperature screen gave results a reviewer found misleading for Egypt (see UNRELIABLE).
"""
from __future__ import annotations

import csv
import datetime as dt
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parents[2]

# cycle length in days and where it comes from. rice, maize, cotton: the totals the water engine uses (FAO-56 Table 11); wheat: the calendar engine's
# fixed days to maturity; onion, potato: the FAO-56 Table 11 row for the Mediterranean (onion's row is April-sown, so it is only a rough length for
# other sowing months); barley, sorghum: the midpoint of the EcoCrop cycle range.
CYCLE_DAYS = {"wheat": (160, "calendar engine, fixed days to maturity"), "rice": (150, "FAO-56 Table 11, water engine"), "maize": (150, "FAO-56 Table 11, water engine"),
              "cotton": (195, "FAO-56 Table 11, water engine"), "onion": (150, "FAO-56 Table 11 (April-sown row)"), "potato": (130, "FAO-56 Table 11"),
              "barley": (165, "EcoCrop midpoint"), "sorghum": (195, "EcoCrop midpoint"),
              "sugar_beet": (230, "FAO-56 Table 11 (November row)"), "faba_bean": (100, "FAO-56 Table 11 (spring row, not the Delta autumn sowing)"),
              "tomato": (145, "FAO-56 Table 11"), "berseem": (180, "EcoCrop midpoint"), "grape": (210, "FAO-56 Table 11"),
              "orange": (365, "FAO-56 Table 11"), "date_palm": (365, "EcoCrop")}
PERENNIAL = {"orange", "grape", "date_palm"}
# Found misleading by the independent review of 2026-11-15: faba bean's cycle is the spring row, so the usual autumn sowing is called "wrong season";
# sugar beet, tomato and berseem have a flat or implausible temperature signal (berseem's best sowing came out as June, tomato's as June).
UNRELIABLE = {"faba_bean": "the cycle in our table is for a spring sowing, but Delta faba bean is sown in autumn",
              "sugar_beet": "the temperature score hardly changes through the year for this crop",
              "tomato": "the temperature score does not separate the seasons for this crop (it is grown in several seasons)",
              "berseem": "the temperature score hardly changes through the year for this crop"}
# Team assumption (not from a source): how a sowing date is described to the farmer, relative to the BEST date of the year for the same crop.
# (A fixed threshold fails because EcoCrop's optimal ranges are narrow: wheat sown on its best date still has only about 55% ideal days.)
RIGHT_WITHIN, SO_SO_WITHIN, BAD_SHARE_WRONG = 10, 25, 20
# Team assumption: if the score barely changes through the year, temperature cannot tell the right season, and the engine says so instead of guessing.
MIN_SPREAD = 40
MIN_SEASONS = 20


def load_params(path=None):
    out = {}
    with open(path or ROOT / "models" / "ecocrop_subset.csv", encoding="utf8") as f:
        lines = [l for l in f if not l.startswith("#")]
    for r in csv.DictReader(lines):
        num = lambda v: None if v in ("NA", "", None) else float(v)
        out[r["crop"]] = {"tmin": num(r["tmin"]), "topmn": num(r["topmn"]), "topmx": num(r["topmx"]), "tmax": num(r["tmax"]), "ktmp": num(r["ktmp"]),
                          "gmin": num(r["gmin"]), "gmax": num(r["gmax"])}
    return out


class SiteTemps:
    """Daily mean and minimum temperature from a NASA POWER daily JSON file."""

    def __init__(self, path):
        p = json.loads(pathlib.Path(path).read_text())["properties"]["parameter"]
        self.tmean, self.tmin = {}, {}
        for k, v in p["T2M"].items():
            lo = p["T2M_MIN"][k]
            if v > -900 and lo > -900:
                d = dt.date(int(k[:4]), int(k[4:6]), int(k[6:]))
                self.tmean[d], self.tmin[d] = v, lo
        self.years = sorted({d.year for d in self.tmean})


def season_fit(w, params, crop, month, day, cycle_days=None):
    """Median over all complete years of the share (%) of growing days that are ideal, tolerable, bad, and the number of frost days (None if unknown)."""
    c = params[crop]
    n = cycle_days or CYCLE_DAYS[crop][0]
    if (month, day) == (2, 29):
        day = 28  # a 29 February sowing would use only the leap years
    rows = []
    for y in w.years:
        sow = dt.date(y, month, day)
        ds = [sow + dt.timedelta(days=i) for i in range(n)]
        if any(d not in w.tmean for d in ds):
            continue
        ideal = sum(c["topmn"] <= w.tmean[d] <= c["topmx"] for d in ds)
        ok = sum(c["tmin"] <= w.tmean[d] <= c["tmax"] for d in ds)
        frost = sum(w.tmin[d] < c["ktmp"] for d in ds) if c["ktmp"] is not None else None
        rows.append((100 * ideal / n, 100 * (ok - ideal) / n, 100 * (n - ok) / n, frost))
    if len(rows) < MIN_SEASONS:
        raise ValueError("fewer than %d complete seasons in the weather record" % MIN_SEASONS)
    med = lambda i: statistics.median(r[i] for r in rows)
    return {"crop": crop, "sowing": (month, day), "cycle_days": n, "seasons": len(rows), "ideal_pct": round(med(0)), "tolerable_pct": round(med(1)),
            "bad_pct": round(med(2)), "frost_days": None if c["ktmp"] is None else round(med(3))}


def scan_year(w, params, crop):
    """Season fit for a sowing every 15 days (1st and 15th of each month)."""
    return [season_fit(w, params, crop, m, d) for m in range(1, 13) for d in (1, 15)]


def _cannot(reason, now=None):
    return {"label": "cannot judge", "now": now, "best": None, "spread": None, "gain_ideal_points": None, "gain_bad_points": None, "note": reason}


def verdict(w, params, crop, month, day):
    """The farmer's sowing date against the best date in the year for the same crop (temperature only)."""
    if crop in PERENNIAL:
        return _cannot("This is a tree or vine: it has no sowing season, so a temperature screen of the sowing date does not apply.")
    if crop in UNRELIABLE:
        return _cannot("Temperature cannot judge the season for this crop here (" + UNRELIABLE[crop] + "). Ask a local agricultural engineer.")
    now = season_fit(w, params, crop, month, day)
    scan = scan_year(w, params, crop)
    best = max(scan, key=lambda r: (r["ideal_pct"], -r["bad_pct"]))
    spread = best["ideal_pct"] - min(r["ideal_pct"] for r in scan)
    if spread < MIN_SPREAD:
        return _cannot("Temperature alone cannot tell the right sowing season for this crop (the score barely changes through the year). Ask a local agricultural engineer.", now)
    gap = best["ideal_pct"] - now["ideal_pct"]
    label = "wrong season" if (now["bad_pct"] >= BAD_SHARE_WRONG or gap > SO_SO_WITHIN) else ("right season" if gap <= RIGHT_WITHIN else "so-so")
    return {"label": label, "now": now, "best": best, "spread": spread, "gain_ideal_points": gap, "gain_bad_points": now["bad_pct"] - best["bad_pct"],
            "note": "Temperature only (EcoCrop ranges, NASA POWER 1990-2025). Not a yield forecast; water, salt, day length and market are not in this number."}
