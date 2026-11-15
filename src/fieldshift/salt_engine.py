"""Salt engine (draft): which crops can the farmer's soil take?

Source of crop tolerance: FAO Irrigation and Drainage Paper 29 Rev.1, Table 4, soil salinity ECe in
dS/m at 100%, 90%, 75% and 50% yield potential (models/salt_tolerance.csv). Values were read from the
FAO web page on 2026-11-15; re-check against the PDF before quoting. The source states that these
are a guide to RELATIVE tolerance: absolute tolerance varies with climate, soil and practice.

No NASA product measures soil salinity. The input is a soil test (ECe) from the farmer or, if there
is none, one of three sign classes whose ECe values are a TEAM ASSUMPTION (low confidence), not a
measurement. A soil test is always recommended.
"""
from __future__ import annotations

import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]

# Team assumption (not from a source): representative ECe for what a farmer can observe.
SIGN_TO_ECE = {"none": 2.0, "patches": 6.0, "crust": 12.0}
SIGN_NOTE = "Assumed ECe for what the farmer sees (none 2, patches 6, white crust 12 dS/m). Judgement only: get a soil test."


def load_table(path=None):
    rows = csv.DictReader(open(path or ROOT / "models" / "salt_tolerance.csv", encoding="utf8"))
    out = {}
    for r in rows:
        out[r["crop"]] = {"points": [(float(r["ece_100"]), 100.0), (float(r["ece_90"]), 90.0), (float(r["ece_75"]), 75.0), (float(r["ece_50"]), 50.0)],
                          "source": r["source"], "note": r["note"]}
    return out


def yield_potential(points, ece):
    """Relative yield potential (%) at soil salinity ece, linear between the four published points.

    Below the 100% point returns 100. Above the 50% point the table gives no value; returns None.
    """
    if ece < 0:
        raise ValueError("ECe cannot be negative")
    if ece <= points[0][0]:
        return 100.0
    for (e0, y0), (e1, y1) in zip(points, points[1:]):
        if ece <= e1:
            return y0 + (y1 - y0) * (ece - e0) / (e1 - e0)
    return None


def status(y):
    if y is None:
        return "not advised"
    if y >= 90:
        return "fine"
    if y >= 75:
        return "reduced"
    return "not advised"


def assess(crops=None, ece=None, signs=None, table=None):
    """Assess crops for a soil salinity given as ECe (dS/m) or as a sign class: 'none', 'patches' or 'crust'."""
    if (ece is None) == (signs is None):
        raise ValueError("give exactly one of ece or signs")
    basis = "soil test (ECe given by the farmer)"
    if ece is None:
        if signs not in SIGN_TO_ECE:
            raise ValueError("signs must be one of: " + ", ".join(SIGN_TO_ECE))
        ece, basis = SIGN_TO_ECE[signs], SIGN_NOTE
    table = table or load_table()
    wanted = crops or list(table)
    unknown = [c for c in wanted if c not in table]
    if unknown:
        raise ValueError("no tolerance data for: " + ", ".join(unknown))
    res = {}
    for c in wanted:
        y = yield_potential(table[c]["points"], ece)
        res[c] = {"yield_potential_pct": None if y is None else round(y), "status": status(y), "source": table[c]["source"], "note": table[c]["note"]}
    return {"ece_ds_m": ece, "basis": basis, "crops": res,
            "caveats": ["FAO table is a guide to relative tolerance, steady-state, saturated-paste ECe.",
                        "No NASA product measures soil salinity; this comes from the farmer and the FAO table.",
                        "Shallow saline groundwater can re-salinise a leached field (hagage2024).",
                        "Rice is grown partly to leach salt but is the heaviest water user (ghazouani2014; kotb2000 abstract only)."]}
