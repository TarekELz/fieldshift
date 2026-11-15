"""Tally the wording votes.

Put each person's file (text_vote_<name>.json, sent from the vote page) in docs/text_vote_answers/ (not committed: names and opinions).
Run: .venv/Scripts/python scripts/collect_text_votes.py
Prints, for every text, how many votes A, B, C and 'own wording' got, who wrote their own wording, and the reasons given.
Writes docs/text_vote_answers/tally.md. Options: --dir <folder>
"""
import argparse
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ANS = ROOT / "docs" / "text_vote_answers"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(ANS))
    args = ap.parse_args()
    meta = json.loads((ROOT / "docs" / "text_vote" / "items.json").read_text(encoding="utf8"))
    version, items = meta["version"], {i["id"]: i for i in meta["items"]}
    votes = {}
    voters = []
    for f in sorted(pathlib.Path(args.dir).glob("*.json")):
        d = json.loads(f.read_text(encoding="utf8"))
        if d.get("version") != version:
            print(f"WARNING {f.name}: different version of the vote page ({d.get('version')} vs {version}); skipped")
            continue
        voters.append(d.get("voter") or f.stem)
        for a in d["answers"]:
            votes.setdefault(a["id"], []).append({"who": d.get("voter") or f.stem, **a})
    lines = [f"# Wording vote: {len(voters)} voters ({', '.join(voters) or 'none'})\n"]
    for id_, it in items.items():
        v = votes.get(id_, [])
        count = {k: [x["who"] for x in v if x["pick"] == k] for k in ("A", "B", "C", "own")}
        lines.append(f"## {id_}. {it['where']}")
        for o in it["options"]:
            lines.append(f"- **{o['key']}** ({len(count[o['key']])}: {', '.join(count[o['key']]) or '-'}) {o['ar']} | {o['en']}")
        if count["own"]:
            lines.append(f"- **own wording** ({len(count['own'])})")
            for x in (y for y in v if y["pick"] == "own"):
                lines.append(f"  - {x['who']}: {x.get('own_ar', '')} | {x.get('own_en', '')}")
        for x in v:
            if x.get("why"):
                lines.append(f"  - why ({x['who']}, {x['pick']}): {x['why']}")
        lines.append("")
    ANS.mkdir(exist_ok=True)
    (ANS / "tally.md").write_text("\n".join(lines), encoding="utf8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
