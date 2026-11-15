"""apply_text_review.to_raw must reproduce every app string exactly when the wording is left unchanged (so applying answers can
never corrupt the Dart source), and must reject a wording that drops a placeholder."""
import importlib.util
import json
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("apply_text_review", ROOT / "scripts" / "apply_text_review.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

ITEMS = json.loads((ROOT / "docs" / "text_review" / "texts.json").read_text(encoding="utf8"))
SOURCES = {f.name: f.read_bytes().decode("utf8").replace("\r\n", "\n") for f in (ROOT / "app" / "lib").glob("*.dart")}


def sides():
    for it in ITEMS:
        for lang in ("ar", "en"):
            if it.get(lang):
                yield it["id"], lang, it[lang]


# Texts reworded on purpose AFTER the review page (docs/text_review/index.html) was sent to friends. texts.json stays frozen so
# their answers still match by id; these items therefore no longer appear in the source in their old form.
REWORDED_AFTER_SENDING = {63, 81, 131}


@pytest.mark.parametrize("id_,lang,side", list(sides()))
def test_round_trip_unchanged(id_, lang, side):
    text = SOURCES[side["file"]]
    quotes = [q for q in ("'", '"') if q + side["raw"] + q in text]
    if not quotes and id_ in REWORDED_AFTER_SENDING:
        pytest.skip("reworded after the review page was sent")
    assert quotes, f"#{id_} {lang}: literal not found in {side['file']}"
    assert mod.to_raw(side["raw"], side["text"], side["text"], quotes[0]) == side["raw"]


def test_dropping_a_placeholder_is_rejected():
    withph = next(s for _, _, s in sides() if "{" in s["text"])
    with pytest.raises(ValueError):
        mod.to_raw(withph["raw"], withph["text"], "no placeholder here", "'")


def test_special_characters_are_escaped():
    out = mod.to_raw("plain", "plain", "it's a $5 \\ line\nnext", "'")
    assert out == "it\\'s a \\$5 \\\\ line\\nnext"
