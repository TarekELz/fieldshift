"""Advice layer: code selects the blueprint; the guard decides whether a model rewrite may be shown. No network is used here."""
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import advice, rotation, season_engine as se  # noqa: E402

GH = ROOT / "data" / "raw" / "power" / "gharbia_daily.json"
needs_data = pytest.mark.skipif(not GH.exists(), reason="NASA POWER files not present (data/raw is not in git)")
BP = advice.load_blueprints()


def facts(**kw):
    f = {"sea": False, "summer_crop": "rice", "summer_date": (6, 15), "wheat_date": (11, 15), "gap": 40, "heat_extra": 0, "salt_known": True, "salt_summer": "fine",
         "salt_wheat": "fine", "summer_label": "right season", "wheat_label": "right season", "summer_best": None, "wheat_best": None, "alt_crop": "maize",
         "alt_pct": 85, "alt_water_pct": 85, "alt_salt_ok": True}
    f.update(kw)
    return f


def top(**kw):
    return advice.select(facts(**kw), BP)[0]["id"]


def test_every_blueprint_has_both_languages_and_valid_conditions():
    ids = set()
    for b in BP["blueprints"]:
        assert b["ar"] and b["en"] and b["id"] not in ids
        ids.add(b["id"])
        for c in b["must"] + b["bonus"]:
            assert "f" in c and any(k in c for k in ("in", "lt", "lte", "gt", "gte", "truthy"))


def test_selection_by_code():
    assert top(sea=True) == "sea_cell"
    assert top(salt_summer="not advised") == "salt_not_advised_alt"
    assert top(salt_summer="not advised", alt_salt_ok=False) == "salt_not_advised"
    assert top(salt_summer="not advised", heat_extra=6) == "combo_late_salt"
    assert top(heat_extra=6) == "wheat_late"
    assert top(gap=5) == "tight_gap"
    assert top(summer_label="wrong season", summer_best=(5, 15)) == "summer_off_season"
    assert top(salt_summer="reduced") == "salt_reduced"
    assert top(salt_known=False, salt_summer=None, summer_crop="maize") == "on_track"
    assert top() == "water_heavy" or top() == "on_track"


def test_salt_problem_is_never_called_fine():
    """The failure seen with the free model: rice on salty soil called fine. The selected blueprint must be about salt."""
    for kw in ({"salt_summer": "not advised"}, {"salt_summer": "not advised", "alt_salt_ok": False}):
        assert "salt" in top(**kw)


def test_closeness_is_a_share():
    r = advice.select(facts(salt_summer="not advised"), BP)[0]
    assert 0 < r["closeness"] <= 100


def test_fill_puts_engine_numbers_in_arabic_and_english():
    f = facts(gap=5)
    b = next(x for x in BP["blueprints"] if x["id"] == "tight_gap")
    ar, en = advice.fill(b, f, "ar"), advice.fill(b, f, "en")
    assert "خمس أيام" in ar and "{" not in ar
    assert "5 days" in en and "{" not in en
    b2 = next(x for x in BP["blueprints"] if x["id"] == "wheat_late")
    assert advice.fill(b2, facts(heat_extra=6), "ar") == b2["ar"]  # no slots: the advice is the same words every time


def _case(bid="tight_gap", **kw):
    f = facts(gap=5, **kw)
    b = next(x for x in BP["blueprints"] if x["id"] == bid)
    return f, b, advice.fill(b, f, "ar")


def test_guard_accepts_faithful_rewrite_and_rejects_changes():
    f, b, filled = _case()
    good = filled + " ده مهم."
    assert advice.guard(good, filled, b, BP, "ar")[0]
    assert "missing day count" in advice.guard(filled.replace("خمس أيام", "أربع أيام"), filled, b, BP, "ar")[1]
    assert "new number" in advice.guard(good + " ٣٠", filled, b, BP, "ar")[1]
    assert "forbidden" in advice.guard(good + " وهتكسب فلوس", filled, b, BP, "ar")[1]
    assert not advice.guard("", filled, b, BP, "ar")[0]
    assert not advice.guard(good * 6, filled, b, BP, "ar")[0]
    f2, b2, filled2 = _case("water_heavy", alt_pct=85)  # a text with a digit number: it must survive
    assert "missing number" in advice.guard(filled2.replace("٨٥", "ثمانين"), filled2, b2, BP, "ar")[1]
    assert "missing key word" in advice.guard("الرز بياخد كتير.", filled2, b2, BP, "ar")[1] or "missing number" in advice.guard("الرز بياخد كتير.", filled2, b2, BP, "ar")[1]


def test_tailor_uses_model_only_when_guard_passes_and_falls_back():
    f = facts(gap=5)
    _, b, filled = _case()
    good = filled + " ده مهم."
    r = advice.tailor(f, "ar", caller=lambda k, t, l, to: good, key_list=["k"], bp=BP)
    assert r["source"] == "ai" and r["text"] == good and r["blueprint_id"] == "tight_gap"
    bad = advice.tailor(f, "ar", caller=lambda k, t, l, to: "الوقت تمام ومفيش مشكلة", key_list=["k"], bp=BP)
    assert bad["source"] == "blueprint" and "خمس أيام" in bad["text"] and bad["reason"] != "ok"
    boom = advice.tailor(f, "ar", caller=lambda k, t, l, to: (_ for _ in ()).throw(TimeoutError()), key_list=["k1", "k2"], bp=BP)
    assert boom["source"] == "blueprint"
    assert advice.tailor(f, "ar", key_list=[], bp=BP)["reason"] == "no key"


def test_next_key_is_tried_when_the_first_fails():
    f = facts(gap=5)
    _, _, filled = _case()
    good = filled + " ده مهم."
    calls = []

    def caller(k, t, l, to):
        calls.append(k)
        if k == "k1":
            raise RuntimeError("quota")
        return good

    r = advice.tailor(f, "ar", caller=caller, key_list=["k1", "k2"], bp=BP)
    assert calls == ["k1", "k2"] and r["source"] == "ai"


@needs_data
def test_end_to_end_with_real_engines_rice_on_patches_is_a_salt_advice():
    res = rotation.compare_rotations("gharbia", rotation.DEMO, signs="patches", interval_days=10)
    w, p = se.SiteTemps(GH), se.load_params()
    f = advice.facts_from(res, se.verdict(w, p, "rice", 6, 15), se.verdict(w, p, "wheat", 12, 1))
    assert f["salt_summer"] == "not advised" and f["alt_crop"] == "cotton"  # cotton is the alternative that is fine on this salt
    out = advice.tailor(f, "ar", key_list=[], bp=BP)
    # late wheat AND salty soil: the combined blueprint is the main advice; the cotton option comes as the second advice
    assert out["blueprint_id"] == "combo_late_salt" and "الملوحة" in out["text"] and "الرز" in out["text"]
    assert any(a["id"] == "salt_not_advised_alt" and "القطن" in a["text"] for a in out["also"])
