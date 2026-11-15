"""Re-generate recorded lines whose round-trip similarity is low and keep the best of a few takes (synthesis is slightly random, so a bad take can be replaced).

Reads docs/checks/tts_roundtrip.csv (from scripts/check_clips_roundtrip.py), and for each line below the threshold makes up to N new takes with the same voweled
text, scores each take by the same round trip, overwrites the clip only if a take scores better, and updates the csv row. A person should still listen to the
lines that stay low: the transcriber can be the one that is wrong (for example it may hear a short word as another).
Run from the repository root:  python scripts/retry_weak_clips.py [--below 0.85] [--takes 3]
"""

import argparse
import csv
import difflib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_clips_roundtrip as rt  # noqa: E402
import hamsa_tts  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CSV = ROOT / "docs" / "checks" / "tts_roundtrip.csv"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--below", type=float, default=0.85)
    ap.add_argument("--takes", type=int, default=3)
    a = ap.parse_args()
    rows = list(csv.DictReader(open(CSV, encoding="utf8")))
    vowels = {}
    for name in ("spoken_tashkeel.json", "spoken_tashkeel_manual.json"):
        f = ROOT / "scripts" / name
        if f.exists():
            vowels.update(json.loads(f.read_text(encoding="utf8")))
    hk, gk = hamsa_tts.keys(), rt.keys()
    for row in rows:
        best = float(row["similarity"])
        if best >= a.below:
            continue
        text = row["text"]
        for t in range(a.takes):
            data, url, _ = hamsa_tts.generate(vowels.get(text, text), hk)
            wav = hamsa_tts.fix_wav(data) if ".wav" in url.lower().split("?")[0] else data
            heard = rt.transcribe(wav, gk, t)
            sim = 0.0 if heard.startswith("ERROR") else difflib.SequenceMatcher(None, rt.norm(text), rt.norm(heard)).ratio()
            print(f"{text[:36]}  take {t + 1}: {sim:.2f}  (best so far {best:.2f})  {heard[:36]}")
            if sim > best:
                best = sim
                (ROOT / "app" / "assets" / "audio" / row["file"]).write_bytes(wav)
                row["similarity"], row["heard"] = round(sim, 2), heard
            if best >= a.below:
                break
    rows.sort(key=lambda r: float(r["similarity"]))
    with open(CSV, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=["similarity", "text", "heard", "file"])
        w.writeheader()
        w.writerows(rows)
    s = [float(r["similarity"]) for r in rows]
    print(f"clips {len(rows)}  mean similarity {sum(s) / len(s):.3f}  below {a.below}: {sum(1 for x in s if x < a.below)}")


if __name__ == "__main__":
    main()
