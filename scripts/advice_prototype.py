"""Prototype: farmer-readable advice written by a language model, GROUNDED on the engines' output.

The model never calculates. It receives only the facts the engines produced (rotation comparison) and may only rephrase
them in simple Egyptian Arabic. A guard then rejects any answer that contains a number that is not in the facts.
Needs GEMINI_API_KEY in .env (gitignored). Only the engine facts are sent: no name, no phone data, no exact location.

Run: .venv/Scripts/python scripts/advice_prototype.py [site] [signs: none|patches|crust] [interval_days]
"""
import json
import pathlib
import re
import sys

import requests

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import rotation  # noqa: E402

MODEL = "gemini-3.1-flash-lite"
AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")

SYSTEM = """You write advice for an Egyptian farmer in the Nile Delta who may not read well. Write in simple Egyptian colloquial Arabic (مصري عامي), short sentences, no technical words.
STRICT RULES:
1. Use ONLY the facts in the JSON. Do not add any fact, crop, number, price or yield. Do not predict yield or money.
2. Every number you write must appear in the JSON. Do not invent or round to new numbers. Write numbers with Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩).
3. Structure, each as one or two short sentences, with these exact headings:
   اللي ماشي كويس:
   اللي ممكن يتحسن:
   جرّب تقارن بـ:
   خلّي بالك:
4. 'جرّب تقارن بـ' only names an alternative rotation that is in the JSON, and says what the facts show (less water, fewer hot days, or salt problem). If an alternative is not better on any fact, say so honestly.
5. 'خلّي بالك' says one honest limit from 'limits' in the JSON, in plain words, and that an agricultural engineer's opinion comes first.
6. Maximum 90 words in total. No emojis, no markdown."""


def facts(site, signs, interval):
    r = rotation.compare_rotations(site, rotation.DEMO, signs=signs, interval_days=interval)
    out = {"place": r["site_name"], "rotations": [], "limits": [
        "الأرقام بتقارن بين الاختيارات ومش بتتنبأ بالمحصول",
        "الطقس من قمر ناسا بدقة حوالي ٥٠ كم، وماتقارنش بمحطات",
        "علامات الملوحة تقدير، وتحليل التربة أحسن"]}
    for x in r["rotations"]:
        out["rotations"].append({
            "name": x["name"], "role": x["role"], "summer_crop": x["summer_crop"], "summer_sowing": x["summer_sowing"],
            "wheat_sowing": x["wheat_sowing"], "days_between_harvest_and_wheat": x["days_between_harvest_and_wheat"],
            "summer_water_vs_current_rotation": x["water"]["ratio_to_existing"],
            "hot_days_in_wheat_grain_filling": x["wheat_heat"]["heat_days_median_at_32c"],
            "extra_hot_days_vs_wheat_15_nov": x["wheat_heat"]["extra_heat_days_vs_15_nov"][32.0],
            "salt_summer_crop": (x["salt"] or {}).get("summer", {}).get("status"), "salt_wheat": (x["salt"] or {}).get("wheat", {}).get("status"),
            "warnings": x["warnings"]})
    return out


def key():
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("GEMINI_API_KEY missing in .env")


def numbers(text):
    return set(re.findall(r"\d+(?:\.\d+)?", text.translate(AR_DIGITS)))


def ask(f):
    body = {"systemInstruction": {"parts": [{"text": SYSTEM}]},
            "contents": [{"role": "user", "parts": [{"text": json.dumps(f, ensure_ascii=False)}]}],
            "generationConfig": {"temperature": 0.3, "maxOutputTokens": 800}}
    r = requests.post(f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent", headers={"x-goog-api-key": key()}, json=body, timeout=120)
    if not r.ok:
        raise SystemExit(f"HTTP {r.status_code}: {r.text[:200]}")
    return r.json()["candidates"][0]["content"]["parts"][0]["text"].strip()


def main():
    site = sys.argv[1] if len(sys.argv) > 1 else "gharbia"
    signs = sys.argv[2] if len(sys.argv) > 2 else "patches"
    interval = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    f = facts(site, signs, interval)
    allowed = numbers(json.dumps(f, ensure_ascii=False))
    text = ask(f)
    extra = numbers(text) - allowed
    print(text)
    print("\nwords:", len(text.split()), "| numbers not in the facts:", sorted(extra) or "none", "| verdict:", "REJECT (fall back to the fixed text)" if extra else "ok")


if __name__ == "__main__":
    main()
