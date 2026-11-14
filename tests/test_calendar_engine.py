"""Tests for the wheat calendar engine. They use synthetic weather, so no downloaded data is needed."""
import datetime as dt
import math
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from fieldshift.calendar_engine import (Weather, calibrate_gdd, heat_risk, load_config,  # noqa: E402
                                        maturity_thermal, sowing_date)


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


def test_later_sowing_meets_more_heat():
    w = synthetic()
    early = heat_risk(w, 11, 15, CFG, "thermal")["heat_days_median"]
    late = heat_risk(w, 1, 10, CFG, "thermal")["heat_days_median"]
    assert late > early


def test_warmer_climate_gives_more_heat_days():
    base = heat_risk(synthetic(), 12, 1, CFG, "fixed")["heat_days_median"]
    warm = heat_risk(synthetic(shift=2.0), 12, 1, CFG, "fixed")["heat_days_median"]
    assert warm >= base


def test_lower_threshold_never_gives_fewer_heat_days():
    w = synthetic()
    assert heat_risk(w, 12, 1, CFG, "thermal", 30)["heat_days_median"] >= heat_risk(w, 12, 1, CFG, "thermal", 34)["heat_days_median"]


def test_thermal_method_shortens_late_sown_season():
    w = synthetic()
    a = heat_risk(w, 11, 15, CFG, "thermal")["median_season_length_days"]
    b = heat_risk(w, 1, 10, CFG, "thermal")["median_season_length_days"]
    assert b < a


def test_calibration_reproduces_target_maturity():
    w = synthetic()
    target = calibrate_gdd(w, CFG)
    m = maturity_thermal(w, dt.date(2001, 11, 15), target, 0.0)
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
        heat_risk(synthetic(), month, 1, CFG)


def test_output_carries_provenance_and_notice():
    r = heat_risk(synthetic(), 11, 15, CFG)
    assert "NASA POWER" in r["provenance"]["temperature"]
    assert "does not replace" in r["notice"]
