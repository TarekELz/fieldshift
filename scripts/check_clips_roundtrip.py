"""Round-trip accuracy screen for the recorded voice lines (app/assets/audio): transcribe each clip with Gemini's audio input and compare it with
the text we meant. This is the same idea the Arabic TTS evaluation repos use (synthesize, transcribe, compare), as a cheap way to find clips that
are garbled or misread so a person listens to those first. It is a SCREEN, not proof: the transcriber can also be wrong, and it does not judge
accent or naturalness.

Output: docs/checks/tts_roundtrip.csv (text, similarity 0 to 1, what the transcriber heard). Keys come from .env (GEMINI_API_KEY, _2, ...), never printed.
Run from the repository root:  python scripts/check_clips_roundtrip.py [--limit N]
"""

import argparse
import base64
import csv
import difflib
import json
import re
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "app" / "assets" / "audio"
OUT = ROOT / "docs" / "checks" / "tts_roundtrip.csv"
MODEL = "gemini-3.1-flash-lite"
PROMPT = (
    "Transcribe this short Egyptian Arabic audio exactly as spoken. Write it in Arabic script without diacritics. "
    "Write numbers as digits. Output only the transcript, nothing else."
)


def keys():
    out = []
    for line in (ROOT / ".env").read_text(encoding="utf8").splitlines():
        if re.match(r"GEMINI_API_KEY(_\d+)?=", line):
            v = line.split("=", 1)[1].strip()
            if v:
                out.append(v)
    return out


def norm(s):
    s = s.translate(str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789"))
    s = re.sub("[ً-ْـ]", "", s)  # diacritics, tatweel
    s = re.sub("[أإآ]", "ا", s).replace("ة", "ه").replace("ى", "ي").replace("ؤ", "و").replace("ئ", "ي")
    s = re.sub(r"[^\w\s]", " ", s)  # punctuation
    return re.sub(r"\s+", " ", s).strip().lower()


def transcribe(wav, ks, i):
    body = {"contents": [{"parts": [{"text": PROMPT}, {"inline_data": {"mime_type": "audio/wav", "data": base64.b64encode(wav).decode()}}]}]}
    last = ""
    for n in range(len(ks)):
        k = ks[(i + n) % len(ks)]
        r = requests.post(f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent", headers={"x-goog-api-key": k}, json=body, timeout=90)
        if r.ok:
            try:
                return r.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
            except (KeyError, IndexError):
                last = "no text"
        else:
            last = f"HTTP {r.status_code}"
            time.sleep(2)
    return "ERROR " + last


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    index = json.loads((AUDIO / "index.json").read_text(encoding="utf8"))
    ks = keys()
    rows = []
    for i, (text, fn) in enumerate(sorted(index.items())):
        if a.limit and i >= a.limit:
            break
        heard = transcribe((AUDIO / fn).read_bytes(), ks, i)
        sim = 0.0 if heard.startswith("ERROR") else difflib.SequenceMatcher(None, norm(text), norm(heard)).ratio()
        rows.append({"text": text, "heard": heard, "similarity": round(sim, 2), "file": fn})
        print(f"{sim:.2f}  {text[:60]}  ->  {heard[:60]}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=["similarity", "text", "heard", "file"])
        w.writeheader()
        w.writerows(sorted(rows, key=lambda r: r["similarity"]))
    ok = [r["similarity"] for r in rows if r["similarity"] > 0]
    print(f"clips {len(rows)}  mean similarity {sum(ok) / max(len(ok), 1):.2f}  below 0.7: {sum(1 for s in ok if s < 0.7)}  wrote {OUT}")


if __name__ == "__main__":
    main()
