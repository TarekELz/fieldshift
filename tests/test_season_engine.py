"""Season engine checks: directions that must hold for the Nile Delta (temperature screen only, not yield). Checked at two sites."""
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import season_engine as s  # noqa: E402

FILES = {"gharbia": ROOT / "data" / "raw" / "power" / "gharbia_daily.json", "beheira": ROOT / "data" / "raw" / "power" / "beheira_daily.json"}
pytestmark = pytest.mark.skipif(not all(f.exists() for f in FILES.values()), reason="NASA POWER files not present (data/raw is not in git)")


@pytest.fixture(scope="module", params=sorted(FILES))
def ctx(request):
    return s.SiteTemps(FILES[request.param]), s.load_params()


def test_params_load_and_cover_crops():
    p = s.load_params()
    assert {"wheat", "rice", "maize", "cotton", "berseem", "sugar_beet", "faba_bean", "orange", "date_palm"} <= set(p)
    assert p["wheat"]["tmin"] < p["wheat"]["topmn"] < p["wheat"]["topmx"] < p["wheat"]["tmax"]
    assert p["cotton"]["topmx"] == 32  # Gossypium barbadense (Egyptian long-staple), not upland G. hirsutum (36)


def test_rice_in_november_is_wrong_and_may_is_right(ctx):
    w, p = ctx
    assert s.verdict(w, p, "rice", 11, 1)["label"] == "wrong season"
    assert s.verdict(w, p, "rice", 5, 15)["label"] == "right season"


def test_wheat_mid_november_is_right_and_march_is_wrong(ctx):
    w, p = ctx
    assert s.verdict(w, p, "wheat", 11, 15)["label"] == "right season"
    assert s.verdict(w, p, "wheat", 3, 1)["label"] == "wrong season"


def test_gain_is_zero_when_already_at_best_and_positive_otherwise(ctx):
    w, p = ctx
    best = s.verdict(w, p, "maize", 5, 1)
    assert best["gain_ideal_points"] >= 0 and best["label"] == "right season"
    assert s.verdict(w, p, "rice", 11, 1)["gain_ideal_points"] > 30


def test_shares_add_up_to_about_100(ctx):
    w, p = ctx
    r = s.season_fit(w, p, "cotton", 4, 1)
    assert abs(r["ideal_pct"] + r["tolerable_pct"] + r["bad_pct"] - 100) <= 2


@pytest.mark.parametrize("crop,sow", [("berseem", (10, 15)), ("tomato", (2, 1)), ("sugar_beet", (11, 1)), ("faba_bean", (11, 1)),
                                      ("orange", (1, 15)), ("grape", (2, 1)), ("date_palm", (3, 1))])
def test_unreliable_and_perennial_crops_are_not_judged(ctx, crop, sow):
    w, p = ctx
    v = s.verdict(w, p, crop, *sow)
    assert v["label"] == "cannot judge" and v["gain_ideal_points"] is None and v["note"]


def test_faba_bean_normal_autumn_sowing_is_never_called_wrong(ctx):
    w, p = ctx
    assert s.verdict(w, p, "faba_bean", 10, 15)["label"] != "wrong season"


def test_frost_is_unknown_not_zero_when_ecocrop_has_no_killing_temperature(ctx):
    w, p = ctx
    assert p["rice"]["ktmp"] is None and s.season_fit(w, p, "rice", 6, 1)["frost_days"] is None
    assert s.season_fit(w, p, "wheat", 11, 15)["frost_days"] == 0  # wheat has KTMP 0 and the Delta does not freeze at these sites


def test_29_february_uses_all_years_not_only_leap_years(ctx):
    w, p = ctx
    leap = s.season_fit(w, p, "wheat", 2, 29)
    assert leap["seasons"] >= 30 and leap["sowing"] == (2, 28)


def test_too_few_seasons_is_refused():
    p = s.load_params()

    class Short:
        years = [2000, 2001]
        tmean = {}
        tmin = {}

    with pytest.raises(ValueError):
        s.season_fit(Short(), p, "wheat", 11, 15)
