"""Add Arabic diacritics (tashkeel) to Eyad's spoken lines so the Egyptian voice pronounces them correctly (for example دَوْرِتَك, not a guess).
Gemini adds the marks with a guard: the output with diacritics removed must equal the input exactly (no letter or word may change). Result: scripts/spoken_tashkeel.json
({line: voweled line}); scripts/hamsa_tts.py speaks the voweled text while the app still looks lines up by the plain text. Lines the team edits by hand in the review
(scripts/spoken_tashkeel_manual.json) win over Gemini's. Keys from .env (GEMINI_API_KEY*), gitignored.
Run: .venv/Scripts/python scripts/add_tashkeel.py [--force]
"""
import json
import pathlib
import re
import sys
import time

import requests

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL = "gemini-3.1-flash-lite"
MARKS = re.compile(r"[ً-ْٰـ]")
SYSTEM = ("You add Arabic diacritics (tashkeel) to short Egyptian colloquial Arabic sentences so that a text-to-speech voice pronounces them in natural Egyptian Arabic, not formal Arabic. "
          "STRICT: do not add, remove, replace or reorder any letter, word or punctuation mark; only insert diacritics (fatha, damma, kasra, sukun, shadda, tanween). "
          "Use Egyptian pronunciation (for example ج as in جَمَل, no formal case endings at word ends, ق as in the sentence's usual Egyptian reading). Keep digits and Latin letters unchanged. "
          "Output only the voweled sentence.")


def keys():
    out = []
    for l in (ROOT / ".env").read_text().splitlines():
        if re.match(r"GEMINI_API_KEY(_\d+)?=", l) and l.split("=", 1)[1].strip():
            out.append(l.split("=", 1)[1].strip())
    return out


FINAL = re.compile(r"([ء-ي])[ً-ْٰ]+(?=$|[\s،؟.,!:;()\"'])")


def egyptian(s):
    """Egyptian Arabic has no case endings: drop every mark on the last letter of a word (a model tends to add formal endings such as the final damma in الصَّيْفِيُّ)."""
    return FINAL.sub(r"", s)


def plain(s):
    return MARKS.sub("", s).strip()


def ask(ks, text):
    for k in ks:
        try:
            r = requests.post(f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent", headers={"x-goog-api-key": k},
                              json={"systemInstruction": {"parts": [{"text": SYSTEM}]}, "contents": [{"role": "user", "parts": [{"text": text}]}],
                                    "generationConfig": {"temperature": 0.0, "maxOutputTokens": 400}}, timeout=60)
            r.raise_for_status()
            return "".join(p.get("text", "") for p in r.json()["candidates"][0]["content"]["parts"]).strip()
        except Exception:
            continue
    return None


def main():
    lines = json.loads((ROOT / "scripts" / "spoken_lines.json").read_text(encoding="utf8"))
    out_path = ROOT / "scripts" / "spoken_tashkeel.json"
    done = json.loads(out_path.read_text(encoding="utf8")) if out_path.exists() and "--force" not in sys.argv else {}
    ks = keys()
    bad = 0
    for i, line in enumerate(lines):
        if line in done:
            continue
        v = ask(ks, line)
        if v and plain(v) == plain(line) and v != plain(line):
            done[line] = egyptian(v)
        else:
            bad += 1
            print("kept plain (guard or model failed):", line[:50])
        if i % 10 == 0:
            out_path.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf8")
        time.sleep(0.3)
    out_path.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf8")
    print(len(done), "of", len(lines), "lines voweled;", bad, "kept plain")


if __name__ == "__main__":
    main()
