"""Tests for the wheat calendar engine. Synthetic weather unless a test says it uses the real POWER files."""
import datetime as dt
import math
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift.calendar_engine import (Weather, _percentiles, calibrate_gdd, compare_sowing,  # noqa: E402
                                        heat_risk, load_config, maturity_thermal, reference_gdd, sowing_date)


def synthetic(years=range(2000, 2006), shift=0.0):
    """Smooth yearly cycle: coldest mid-January, hottest mid-July. Tmax = Tmin + 12."""
    tmax, tmin = {}, {}
    d = dt.date(min(years), 1, 1)
    while d <= dt.date(max(years), 12, 31):
        mean = 21 + shift + 9 * math.cos(2 * math.pi * (d.timetuple().tm_yday - 196) / 365.25)
        tmax[d], tmin[d] = mean + 6, mean - 6
        d += dt.timedelta(days=1)
    return Weather(tmax, tmin)


CFG = load_config()
W = synthetic()
G = calibrate_gdd(W, CFG)  # explicit target so tests do not need the downloaded files


def hr(w, m, d, method="thermal", thr=None):
    return heat_risk(w, m, d, CFG, method, thr, gdd_target=G if method == "thermal" else None)


def test_later_sowing_meets_more_heat():
    assert hr(W, 1, 10)["heat_days_median"] > hr(W, 11, 15)["heat_days_median"]


def test_warmer_climate_gives_more_heat_days():
    assert hr(synthetic(shift=2.0), 12, 1, "fixed")["heat_days_median"] >= hr(W, 12, 1, "fixed")["heat_days_median"]


def test_lower_threshold_never_gives_fewer_heat_days():
    assert hr(W, 12, 1, "thermal", 30)["heat_days_median"] >= hr(W, 12, 1, "thermal", 34)["heat_days_median"]


def test_thermal_method_shortens_late_sown_season():
    assert hr(W, 1, 10)["median_season_length_days"] < hr(W, 11, 15)["median_season_length_days"]


def test_calibration_reproduces_target_maturity():
    m = maturity_thermal(W, dt.date(2001, 11, 15), G, 0.0)
    assert abs((m - dt.date(2002, 4, 25)).days) <= 3


def test_january_sowing_belongs_to_next_calendar_year():
    assert sowing_date(2010, 1, 10) == dt.date(2011, 1, 10)
    assert sowing_date(2010, 11, 15) == dt.date(2010, 11, 15)


def test_feb_29_falls_back_in_non_leap_years():
    assert sowing_date(2010, 2, 29) == dt.date(2011, 2, 28)
    assert sowing_date(2011, 2, 29) == dt.date(2012, 2, 29)


@pytest.mark.parametrize("month", [3, 6, 9])
def test_sowing_outside_window_is_rejected(month):
    with pytest.raises(ValueError):
        hr(W, month, 1)


def test_output_carries_provenance_and_notice():
    r = hr(W, 11, 15)
    assert "NASA POWER" in r["provenance"]["temperature"]
    assert "does not replace" in r["notice"]


# ---- fixes from the 2026-11-15 review ---------------------------------------------------
def test_missing_day_does_not_crash_and_season_is_reported_as_dropped():
    w = synthetic()
    clean = hr(w, 11, 15)
    del w.tmax[dt.date(2003, 4, 20)]  # inside a grain-fill window
    r = hr(w, 11, 15)
    assert r["seasons_dropped"] >= 1
    assert r["seasons"] < clean["seasons"]


def test_missing_tmin_is_handled_like_missing_tmax():
    w = synthetic()
    del w.tmin[dt.date(2003, 4, 20)]
    assert hr(w, 11, 15)["seasons_dropped"] >= 1


def test_percentiles_are_symmetric_and_ordered():
    p10, p90 = _percentiles(list(range(1, 36)))
    assert p10 == pytest.approx(4.4) and p90 == pytest.approx(31.6)  # inclusive method: 1 + 0.1*34 and 1 + 0.9*34
    assert abs((p10 - 1) - (35 - p90)) < 1e-9
    assert _percentiles([5]) == (5, 5)


def test_compare_sowing_ranks_dates_at_every_threshold():
    r = compare_sowing(W, [(11, 15), (12, 15), (1, 10)], CFG, method="fixed")
    for t in CFG["heat"]["sensitivity_thresholds_c"]:
        extra = [row["extra_vs_baseline"][t] for row in r["rows"]]
        assert extra == sorted(extra)


# ---- real POWER files (skipped if they are not on this machine) -----------------------------
POWER = ROOT / "data" / "raw" / "power"
needs_data = pytest.mark.skipif(not (POWER / "gharbia_daily.json").exists(), reason="POWER files not downloaded")


@needs_data
def test_one_thermal_constant_is_used_for_all_sites():
    g = reference_gdd()
    for site in ("beheira", "menoufia"):
        w = Weather.from_power_json(POWER / f"{site}_daily.json")
        assert heat_risk(w, 11, 15, CFG, "thermal")["gdd_target"] == round(g)


@needs_data
def test_real_data_ranking_gharbia():
    w = Weather.from_power_json(POWER / "gharbia_daily.json")
    nov, dec, jan = (heat_risk(w, m, d, CFG)["heat_days_median"] for m, d in [(11, 15), (12, 15), (1, 10)])
    assert nov < dec < jan


@needs_data
def test_real_data_has_no_dropped_seasons():
    w = Weather.from_power_json(POWER / "gharbia_daily.json")
    assert heat_risk(w, 11, 15, CFG)["seasons_dropped"] == 0
