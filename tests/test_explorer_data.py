"""The explorer website (docs/explorer) must show the same tables as the app. Its data files are copies, so this test catches drift.

- every table it shares with the app (app/assets/data/*.json) is identical;
- each .js wrapper (used so the page works from disk) holds the same data as its .json file, except egypt_map, which keeps only the Delta features.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app" / "assets" / "data"
EXP = ROOT / "docs" / "explorer" / "data"
WRAP = re.compile(r"^window\.FS=window\.FS\|\|\{\};window\.FS\.(\w+)=(.*);\s*$", re.S)


def test_shared_tables_equal_the_apps():
    shared = sorted(p.name for p in EXP.glob("*.json") if (APP / p.name).exists())
    assert len(shared) == 9, shared
    for name in shared:
        assert json.loads((EXP / name).read_text(encoding="utf8")) == json.loads((APP / name).read_text(encoding="utf8")), name


def test_js_wrappers_match_their_json():
    for js in sorted(EXP.glob("*.js")):
        if js.stem == "egypt_map":  # a smaller Delta-only copy of the map
            continue
        m = WRAP.match(js.read_text(encoding="utf8"))
        assert m, js.name
        assert json.loads(m.group(2)) == json.loads((EXP / f"{js.stem}.json").read_text(encoding="utf8")), js.name


def test_the_page_makes_no_third_party_request():
    html = (ROOT / "docs" / "explorer" / "index.html").read_text(encoding="utf8")
    urls = set(re.findall(r"https?://[^\"' )>]+", html))
    assert all("w3.org" in u for u in urls), urls  # only the SVG namespace
    for js in (ROOT / "docs" / "explorer" / "js").glob("*.js"):
        assert "googleapis" not in js.read_text(encoding="utf8")
