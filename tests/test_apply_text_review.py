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
# Reworded on purpose after Tarek's one-question-at-a-time Arabic review (2026-11-15): دورتك -> اللي بتزرعه دلوقتي, the goal question.
# #36 is the "Understood:" label that was removed from the question screen (the dialogue's own note already says it).
REWORDED_AFTER_SENDING = {8, 12, 36, 63, 81, 117, 118, 119, 120, 131, 133}


@pytest.mark.parametrize("id_,lang,side", list(sides()))
def test_round_trip_unchanged(id_, lang, side):
    if side["file"] not in SOURCES:
        pytest.skip("that screen was replaced (result_view.dart -> result_pages.dart); the frozen review list refers to the old screen")
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
