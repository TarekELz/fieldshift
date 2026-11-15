"""Apply the answers from the text-review page to the Flutter source.

Input: the JSON that the review page exports (text_review_answers.json). For every answer marked "No, change it" with a new
wording, the matching string literal in app/lib/*.dart is rewritten (everywhere that exact literal appears). Placeholders
such as {arSite} must be kept: a new wording that drops or adds one is rejected and reported, never half-applied.

Usage:
  .venv/Scripts/python scripts/apply_text_review.py path/to/text_review_answers.json            # dry run: shows what would change
  .venv/Scripts/python scripts/apply_text_review.py path/to/text_review_answers.json --apply    # writes the files
Then: cd app && flutter analyze && flutter test
"""
import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIB = ROOT / "app" / "lib"
RAW_PH = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")
SHOW_PH = re.compile(r"\{[^}]*\}")


def to_raw(original_raw, original_text, new_text, quote):
    """Turn the reviewer's text back into Dart source text, restoring each placeholder's original code."""
    raw_tokens = RAW_PH.findall(original_raw)
    show_tokens = SHOW_PH.findall(original_text)
    if len(raw_tokens) != len(show_tokens):
        raise ValueError("could not map the placeholders of the original text")
    new_tokens = SHOW_PH.findall(new_text)
    if sorted(new_tokens) != sorted(show_tokens):
        raise ValueError(f"placeholders must stay the same: expected {show_tokens}, found {new_tokens}")
    pool = {}
    for s, r in zip(show_tokens, raw_tokens):
        pool.setdefault(s, []).append(r)
    counters = {}

    def sub_ph(m):
        s = m.group(0)
        k = counters.get(s, 0)
        counters[s] = k + 1
        lst = pool[s]
        return "\u0000" + str(lst[min(k, len(lst) - 1)].replace("\\", "\\\\")) + "\u0001"

    marked = SHOW_PH.sub(sub_ph, new_text)
    out = marked.replace("\\", "\\\\").replace("$", "\\$").replace(quote, "\\" + quote).replace("\n", "\\n")
    return out.replace("\u0000", "").replace("\u0001", "").replace("\\\\\\\\", "\\\\")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("answers")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    data = json.loads(pathlib.Path(args.answers).read_text(encoding="utf8"))
    changes, problems = [], []
    for a in data["answers"]:
        if a["status"] != "no":
            continue
        for lang in ("ar", "en"):
            side = a.get(lang)
            if not side or side.get("new") in (None, "") or side["new"] == side["original"]:
                continue
            changes.append((a["id"], lang, side))
    files = {f: f.read_bytes().decode("utf8") for f in LIB.glob("*.dart")}
    crlf = {f: b"\r\n" in f.read_bytes() for f in files}
    texts = {f: t.replace("\r\n", "\n") for f, t in files.items()}
    done = 0
    for id_, lang, side in changes:
        hit = False
        for f in texts:
            for q in ("'", '"'):
                old_lit = q + side["raw"] + q
                if old_lit in texts[f]:
                    try:
                        new_raw = to_raw(side["raw"], side["original"], side["new"], q)
                    except ValueError as e:
                        problems.append(f"#{id_} ({lang}): {e}")
                        hit = True
                        break
                    texts[f] = texts[f].replace(old_lit, q + new_raw + q)
                    print(f"#{id_} {lang} {f.name}: {side['original'][:50]!r} -> {side['new'][:50]!r}")
                    hit = True
                    done += 1
            if hit and problems and problems[-1].startswith(f"#{id_} ({lang})"):
                break
        if not hit:
            problems.append(f"#{id_} ({lang}): the original text was not found in the source (already changed?)")
    print(f"\n{done} replacements; {len(problems)} problems")
    for p in problems:
        print("  PROBLEM", p)
    notes = [(a["id"], a["note"]) for a in data["answers"] if a.get("note")]
    for i, n in notes:
        print(f"  NOTE #{i}: {n}")
    if args.apply and done:
        for f, t in texts.items():
            f.write_bytes((t.replace("\n", "\r\n") if crlf[f] else t).encode("utf8"))
        print("written. Now run: cd app && flutter analyze && flutter test")
    elif not args.apply:
        print("(dry run: nothing written; add --apply to write)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
