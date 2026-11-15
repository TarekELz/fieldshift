import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from fieldshift import salt_engine as se  # noqa: E402

T = se.load_table()


def test_table_matches_published_points():
    assert T["wheat"]["points"][0] == (6.0, 100.0) and T["wheat"]["points"][3] == (13.0, 50.0)
    assert T["maize"]["points"][0] == (1.7, 100.0)


def test_yield_is_100_below_threshold_and_interpolates():
    p = T["wheat"]["points"]
    assert se.yield_potential(p, 3) == 100
    assert se.yield_potential(p, 6.7) == pytest.approx(95)      # halfway between (6.0,100) and (7.4,90)? 0.7/1.4
    assert se.yield_potential(p, 13) == pytest.approx(50)
    assert se.yield_potential(p, 14) is None


def test_more_salt_never_raises_yield_for_any_crop():
    for c, v in T.items():
        ys = [se.yield_potential(v["points"], e) for e in (0, 2, 4, 6, 8, 10, 12, 16)]
        ys = [y if y is not None else -1 for y in ys]
        assert ys == sorted(ys, reverse=True), c


def test_salt_sensitive_maize_suffers_before_wheat():
    r = se.assess(["wheat", "maize"], ece=4.0)["crops"]
    assert r["maize"]["yield_potential_pct"] < r["wheat"]["yield_potential_pct"]
    assert r["wheat"]["status"] == "fine" and r["maize"]["status"] != "fine"


def test_signs_use_assumed_values_and_say_so():
    r = se.assess(signs="crust")
    assert r["ece_ds_m"] == 12.0 and "Judgement" in r["basis"]
    assert r["crops"]["rice"]["status"] == "not advised"


def test_must_give_exactly_one_input():
    with pytest.raises(ValueError):
        se.assess(ece=3, signs="none")
    with pytest.raises(ValueError):
        se.assess()


def test_bad_inputs_are_rejected():
    with pytest.raises(ValueError):
        se.assess(ece=-1)
    with pytest.raises(ValueError):
        se.assess(signs="salty")
    with pytest.raises(ValueError):
        se.assess(["quinoa"], ece=2)


def test_output_names_the_data_limit():
    assert any("No NASA product measures soil salinity" in c for c in se.assess(ece=3)["caveats"])
