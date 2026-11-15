"""Advice layer (decisions D16, D18): blueprint advices selected by CODE from the engines' facts, optionally tailored by a language model, with a guard.

Flow
  1. facts_from(...)   turn the engines' output (rotation comparison + season verdicts) into a flat facts dict.
  2. select(...)       evaluate every blueprint's conditions (models/blueprints.json); the highest-priority blueprint whose 'must' conditions hold wins.
                       closeness = share of that blueprint's conditions met. The MODEL NEVER CHOOSES.
  3. fill(...)         put the engines' numbers into the blueprint text. This text is always available, offline, and is the fallback.
  4. tailor(...)       (optional) ask Gemini to rephrase the filled text for this farmer in simple Egyptian Arabic. The answer is shown only if the GUARD
                       passes: every number of the filled text is kept, no new number appears, no forbidden (yield or money) word, the key word stems are kept,
                       and the length is bounded. If the model is slow, down, or fails the guard, the filled blueprint text is shown instead.
The model receives only the filled blueprint text (engine facts), never the farmer's sentence or location.
Keys: GEMINI_API_KEY, GEMINI_API_KEY_2, ... from .env (gitignored); tried in order when one fails or runs out.
"""
from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import time

from . import rotation

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODEL = "gemini-3.1-flash-lite"
AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
TO_AR = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")
MONTH_AR = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
MONTH_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
CROP_AR = {"rice": "الرز", "maize": "الذرة", "cotton": "القطن", "wheat": "القمح"}
CROP_EN = {"rice": "rice", "maize": "maize", "cotton": "cotton", "wheat": "wheat"}


def load_blueprints(path=None):
    return json.loads((pathlib.Path(path) if path else ROOT / "models" / "blueprints.json").read_text(encoding="utf8"))


# ---- facts ------------------------------------------------------------------------------------------------------------------------
def _date(s):
    """'dd/mm' or (m, d) -> (m, d)"""
    if isinstance(s, str):
        d, m = s.split("/")
        return int(m), int(d)
    return tuple(s)


def facts_from(comparison, season_summer=None, season_wheat=None):
    """Flat facts from compare_rotations output (first row = the farmer's own rotation) and season verdicts (season_engine.verdict dicts, or None)."""
    ex, alts = comparison["rotations"][0], comparison["rotations"][1:]
    salt = ex["salt"]
    f = {"sea": rotation.load_sites().get(comparison["site"], {}).get("caveat_kind") == "sea",
         "summer_crop": ex["summer_crop"], "summer_date": _date(ex["summer_sowing"]), "wheat_date": _date(ex["wheat_sowing"]),
         "gap": ex["days_between_harvest_and_wheat"], "heat_extra": ex["wheat_heat"]["extra_heat_days_vs_15_nov"][32.0],
         "salt_known": salt is not None, "salt_summer": salt["summer"]["status"] if salt else None, "salt_wheat": salt["wheat"]["status"] if salt else None,
         "summer_label": (season_summer or {}).get("label", "cannot judge"), "wheat_label": (season_wheat or {}).get("label", "cannot judge"),
         "summer_best": None, "wheat_best": None, "alt_crop": None, "alt_pct": None, "alt_water_pct": None, "alt_salt_ok": False}
    if season_summer and season_summer.get("best"):
        f["summer_best"] = tuple(season_summer["best"]["sowing"])
    if season_wheat and season_wheat.get("best"):
        f["wheat_best"] = tuple(season_wheat["best"]["sowing"])
    cands = [a for a in alts if a["summer_crop"] != ex["summer_crop"]]
    if cands:
        okc = [a for a in cands if a["salt"] and a["salt"]["summer"]["status"] == "fine"]
        pick = min(okc or cands, key=lambda a: a["water"]["ratio_to_existing"])
        f["alt_crop"] = pick["summer_crop"]
        f["alt_pct"] = f["alt_water_pct"] = round(100 * pick["water"]["ratio_to_existing"])
        f["alt_salt_ok"] = bool(okc)
    return f


# ---- selection --------------------------------------------------------------------------------------------------------------------
def _test(cond, facts):
    v = facts.get(cond["f"])
    if "in" in cond:
        return v in cond["in"]
    if "truthy" in cond:
        return bool(v) == cond["truthy"]
    if v is None or isinstance(v, (str, bool)):
        return False
    for op, fn in (("lt", lambda a, b: a < b), ("lte", lambda a, b: a <= b), ("gt", lambda a, b: a > b), ("gte", lambda a, b: a >= b)):
        if op in cond and not fn(v, cond[op]):
            return False
    return True


def select(facts, bp=None, how_many=2):
    """Blueprints that apply, highest priority first: [{id, closeness, blueprint}]. The first is the main advice."""
    bp = bp or load_blueprints()
    out = []
    for b in bp["blueprints"]:
        if all(_test(c, facts) for c in b["must"]):
            total = len(b["must"]) + len(b["bonus"])
            met = len(b["must"]) + sum(_test(c, facts) for c in b["bonus"])
            out.append({"id": b["id"], "priority": b["priority"], "closeness": round(100 * met / total) if total else None, "blueprint": b})
    out.sort(key=lambda r: -r["priority"])
    keep, used = [], set()
    for r in out:
        fam = set(bp.get("families", {}).get(r["id"], [r["id"]]))
        if keep and (r["id"] in ("generic", "on_track") or fam & used):
            continue  # a second advice must be on a different topic, and "looks fine" is never a second advice
        keep.append(r)
        used |= fam
        if len(keep) >= how_many:
            break
    return keep


# ---- filling ----------------------------------------------------------------------------------------------------------------------
def _fmt_date(md, lang):
    return None if md is None else (f"{md[1]} {MONTH_AR[md[0] - 1]}".translate(TO_AR) if lang == "ar" else f"{md[1]} {MONTH_EN[md[0] - 1]}")


EG_DAYS = {1: "يوم", 2: "يومين", 3: "تلات أيام", 4: "أربع أيام", 5: "خمس أيام", 6: "ست أيام", 7: "سبع أيام", 8: "تمان أيام", 9: "تسع أيام", 10: "عشر أيام", 11: "حداشر يوم",
           12: "اتناشر يوم", 13: "تلتاشر يوم", 14: "أربعتاشر يوم", 15: "خمستاشر يوم", 16: "ستاشر يوم", 17: "سبعتاشر يوم", 18: "تمنتاشر يوم", 19: "تسعتاشر يوم", 20: "عشرين يوم"}


def days(n, lang):
    """A count of days as Egyptians say it in a sentence (ست أيام); English: 6 days."""
    if lang != "ar":
        return "1 day" if n == 1 else f"{n} days"
    return EG_DAYS.get(n) or f"{str(n).translate(TO_AR)} يوم"


def fill(blueprint, facts, lang="ar"):
    names = CROP_AR if lang == "ar" else CROP_EN
    num = (lambda n: str(n).translate(TO_AR)) if lang == "ar" else str
    slots = {"crop": names.get(facts["summer_crop"], facts["summer_crop"]), "summer_date": _fmt_date(facts["summer_date"], lang), "wheat_date": _fmt_date(facts["wheat_date"], lang),
             "gap": num(facts["gap"]), "heat_extra": num(facts["heat_extra"]), "gap_days": days(facts["gap"], lang), "heat_extra_days": days(facts["heat_extra"], lang), "alt_crop": names.get(facts["alt_crop"], facts["alt_crop"] or ""),
             "alt_pct": num(facts["alt_pct"]) if facts["alt_pct"] is not None else "", "summer_best": _fmt_date(facts["summer_best"], lang) or "",
             "wheat_best": _fmt_date(facts["wheat_best"], lang) or ""}
    text = blueprint[lang]
    for k, v in slots.items():
        text = text.replace("{" + k + "}", str(v))
    if lang == "en":  # a slot such as a crop name can start a sentence
        text = re.sub(r"(^|[.!?] )([a-z])", lambda m: m.group(1) + m.group(2).upper(), text)
    return text


# ---- guard ------------------------------------------------------------------------------------------------------------------------
def numbers(text):
    return re.findall(r"\d+(?:\.\d+)?", text.translate(AR_DIGITS))


def guard(tailored, filled, blueprint, bp_all, lang="ar"):
    """(ok, reason). The tailored text must keep every number of the filled text, add none, avoid forbidden words, keep key stems, stay short."""
    t = (tailored or "").strip()
    if not t:
        return False, "empty"
    if "\n\n" in t or len(t) > 1.7 * len(filled) + 40:
        return False, "too long"
    have, want = numbers(t), numbers(filled)
    if set(have) - set(want):
        return False, "new number: " + ",".join(sorted(set(have) - set(want)))
    if set(want) - set(have):
        return False, "missing number: " + ",".join(sorted(set(want) - set(have)))
    # day counts are written as words (ست أيام), so digits cannot protect them: each day phrase of the filled text must survive
    for ph in sorted(set(EG_DAYS.values()), key=len, reverse=True):
        if lang == "ar" and ph in filled and ph not in t:
            return False, "missing day count: " + ph
    for w in bp_all["forbidden_" + lang]:
        if w in t.lower():
            return False, "forbidden word: " + w
    if lang == "ar":
        for stem in blueprint.get("keep", []):
            if stem not in t:
                return False, "missing key word: " + stem
    return True, "ok"


# ---- model ------------------------------------------------------------------------------------------------------------------------
SYSTEM = {"ar": ("You rewrite a short advice text for an Egyptian farmer who may not read well. Write in simple Egyptian colloquial Arabic, short sentences. "
                 "STRICT: keep every number and every fact exactly as given; add NO new fact, number, crop, date, price, yield or promise; "
                 "keep the same meaning and the same advice. At most 60 words. Output only the rewritten text, no quotes, no markdown."),
          "en": ("You rewrite a short advice text for a farmer in simple, friendly English. STRICT: keep every number and fact exactly as given; add NO new fact, number, "
                 "crop, date, price, yield or promise; keep the same advice. At most 60 words. Output only the rewritten text.")}


def keys(env_path=None):
    out = []
    for line in (pathlib.Path(env_path) if env_path else ROOT / ".env").read_text().splitlines():
        if re.match(r"GEMINI_API_KEY(_\d+)?=", line):
            v = line.split("=", 1)[1].strip()
            if v:
                out.append(v)
    return out


def _call_gemini(key, text, lang, timeout):
    import requests
    body = {"systemInstruction": {"parts": [{"text": SYSTEM[lang]}]}, "contents": [{"role": "user", "parts": [{"text": text}]}],
            "generationConfig": {"temperature": 0.3, "maxOutputTokens": 400}}
    r = requests.post(f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent", headers={"x-goog-api-key": key}, json=body, timeout=timeout)
    r.raise_for_status()
    return "".join(p.get("text", "") for p in r.json()["candidates"][0]["content"]["parts"]).strip()


def tailor(facts, lang="ar", budget_s=6.0, caller=None, key_list=None, bp=None):
    """Advice for the facts. Returns {text, source ('ai' or 'blueprint'), blueprint_id, closeness, also, reason}. Never raises."""
    bp = bp or load_blueprints()
    sel = select(facts, bp)
    main = sel[0]
    filled = fill(main["blueprint"], facts, lang)
    res = {"text": filled, "source": "blueprint", "blueprint_id": main["id"], "closeness": main["closeness"], "reason": "not tried",
           "also": [{"id": s["id"], "text": fill(s["blueprint"], facts, lang)} for s in sel[1:]]}
    caller = caller or _call_gemini
    try:
        ks = key_list if key_list is not None else keys()
    except OSError:
        ks = []
    start = time.time()
    for k in ks:
        left = budget_s - (time.time() - start)
        if left <= 0.5:
            res["reason"] = "time budget used"
            break
        try:
            out = caller(k, filled, lang, left)
        except Exception as e:  # network, quota, 5xx: try the next key
            res["reason"] = "model error: " + type(e).__name__
            continue
        ok, why = guard(out, filled, main["blueprint"], bp, lang)
        res["reason"] = why
        if ok:
            res["text"], res["source"] = out, "ai"
        break
    else:
        if not ks:
            res["reason"] = "no key"
    return res
