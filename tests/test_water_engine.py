"""Tests for the water engine: FAO-56 building blocks, crop curve, season sums and arithmetic."""
import datetime as dt
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import water_engine as we  # noqa: E402

P = we.load_params()


def test_fao56_worked_values():
    assert we.sat_vp(20) == pytest.approx(2.338, abs=0.001)             # Table 2.3
    assert we.slope_vp(20) == pytest.approx(0.1447, abs=0.0005)         # Table 2.4
    assert we.pressure(1800) == pytest.approx(81.8, abs=0.1)            # Example 2
    assert we.extraterrestrial_radiation(-20, 246) == pytest.approx(32.2, abs=0.1)  # Example 8


def base(**kw):
    a = dict(lat=30.9, z=5, doy=180, tmax=38, tmin=24, rh_mean=45, u2=2.0, rs=28)
    a.update(kw)
    return we.et0_day(**a)


def test_et0_responds_in_the_right_direction():
    assert base(tmax=40, tmin=26) > base()
    assert base(u2=4.0) > base()
    assert base(rh_mean=70) < base()
    assert base(rs=20) < base()


def test_et0_is_never_negative():
    assert base(tmax=2, tmin=-3, rs=3, doy=355) >= 0


def test_kc_curve_follows_the_four_stages():
    c = P["crops"]["rice"]
    assert we.kc_for_day(c, 0) == c["kc"]["ini"]
    assert we.kc_for_day(c, 30 + 15) == pytest.approx((c["kc"]["ini"] + c["kc"]["mid"]) / 2)
    assert we.kc_for_day(c, 30 + 30 + 10) == c["kc"]["mid"]
    assert we.kc_for_day(c, 149) == pytest.approx(c["kc"]["end"], abs=0.03)


class Flat:
    """Weather with constant ET0 of 5 mm/day for a whole year."""
    lat, z = 30.9, 5
    et0 = {dt.date(2001, 1, 1) + dt.timedelta(days=i): 5.0 for i in range(800)}
    years = [2001]


def test_season_sum_equals_integral_of_kc_times_et0():
    c = P["crops"]["maize"]
    r = we.season_need(Flat, c, 2001)
    expected = sum(we.kc_for_day(c, n) * 5.0 for n in range(sum(c["stage_days"])))
    assert r["etc_mm"] == pytest.approx(expected)
    assert r["peak_daily_mm"] == pytest.approx(c["kc"]["mid"] * 5.0)


def test_season_returns_none_when_record_is_short():
    assert we.season_need(Flat, P["crops"]["cotton"], 2003) is None  # fake record ends in March 2003


def test_turn_check_is_plain_arithmetic():
    need = {"peak_daily_mm_median": 10.0}
    assert we.turn_check(need, 10)["mm_needed_per_turn_at_peak"] == 100
    assert "not modelled" in we.turn_check(need, 10)["note"]


def test_rice_lists_what_it_excludes():
    assert any("percolation" in x for x in P["crops"]["rice"]["excludes"])


@pytest.mark.skipif(not (ROOT / "data/raw/power/gharbia_daily.json").exists(), reason="POWER files not downloaded")
def test_real_data_summer_crops_have_positive_need_and_no_missing_seasons():
    w = we.SiteWeather(ROOT / "data/raw/power/gharbia_daily.json")
    for c in P["crops"]:
        r = we.crop_water_need(w, P, c)
        assert r["etc_mm_median"] > 500 and r["seasons"] >= 30
