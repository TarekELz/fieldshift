"""Build scripts/spoken_lines.json: every line Eyad can say that does not depend on the farmer's numbers, so each can have a pre-generated Egyptian-voice clip.
= the dialogue's sentences (scripts/spoken_dialogue.json, written by `DUMP_SPOKEN=1 flutter test test/spoken_lines_test.dart` in app/)
+ the blueprint advices whose only slots are the crop names (each crop and each alternative crop filled in).
Run: .venv/Scripts/python scripts/build_spoken_lines.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import advice  # noqa: E402


def main():
    lines = json.loads((ROOT / "scripts" / "spoken_dialogue.json").read_text(encoding="utf8"))
    bp = advice.load_blueprints()
    crops = ["rice", "maize", "cotton"]
    base = {"summer_crop": "rice", "summer_date": (6, 15), "wheat_date": (11, 15), "gap": 40, "heat_extra": 0, "alt_crop": None, "alt_pct": None, "summer_best": None, "wheat_best": None}
    for b in bp["blueprints"]:
        ph = set(re.findall(r"\{(\w+)\}", b["ar"]))
        if not ph:
            lines.append(b["ar"])
        elif ph <= {"crop"}:
            lines += [advice.fill(b, {**base, "summer_crop": c}, "ar") for c in crops]
        elif ph <= {"crop", "alt_crop"}:
            lines += [advice.fill(b, {**base, "summer_crop": c, "alt_crop": a}, "ar") for c in crops for a in crops if a != c]
    seen = []
    for x in lines:
        if x not in seen:
            seen.append(x)
    (ROOT / "scripts" / "spoken_lines.json").write_text(json.dumps(seen, ensure_ascii=False, indent=1), encoding="utf8")
    print(len(seen), "lines,", sum(len(x) for x in seen), "characters")


if __name__ == "__main__":
    main()
