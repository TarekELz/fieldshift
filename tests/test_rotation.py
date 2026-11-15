import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import rotation as rot  # noqa: E402

pytestmark = pytest.mark.skipif(not (ROOT / "data/raw/power/gharbia_daily.json").exists(), reason="POWER files not downloaded")


def run(**kw):
    return rot.compare_rotations("gharbia", rot.DEMO, **kw)


def test_three_rotations_with_existing_first():
    r = run()
    assert len(r["rotations"]) == 3 and r["rotations"][0]["role"] == "existing rotation"
    assert r["rotations"][0]["water"]["ratio_to_existing"] == 1.0


def test_every_rotation_has_evidence_gaps_and_risks():
    for row in run()["rotations"]:
        assert row["evidence"] and row["gaps"] and row["risks"] and row["why_included"]
        assert all("tag" in e for e in row["evidence"])


def test_later_wheat_sowing_means_more_extra_heat_days():
    rows = run()["rotations"]
    assert rows[0]["wheat_heat"]["extra_heat_days_vs_15_nov"][32.0] > rows[1]["wheat_heat"]["extra_heat_days_vs_15_nov"][32.0] == 0


def test_rice_floor_and_not_modelled_are_stated():
    text = rot.render_text(run(signs="patches", interval_days=10))
    assert "FLOOR" in text and "Not modelled" in text and "does not replace" in text
    assert "canal turns" in text and "Judgement only" in text


def test_summer_crop_must_be_known():
    with pytest.raises(ValueError):
        rot.compare_rotations("gharbia", [{"summer_crop": "quinoa", "wheat_sowing": (11, 15)}])


def test_unknown_site_and_empty_input_rejected():
    with pytest.raises(ValueError):
        rot.compare_rotations("atlantis", rot.DEMO)
    with pytest.raises(ValueError):
        rot.compare_rotations("gharbia", [])


def test_warning_when_wheat_precedes_harvest():
    r = rot.compare_rotations("gharbia", [{"summer_crop": "cotton", "summer_sowing": (4, 1), "wheat_sowing": (10, 1)}])
    assert r["rotations"][0]["warnings"]


def test_damietta_caveat_is_carried_into_the_output():
    r = rot.compare_rotations("damietta", rot.DEMO)
    assert "sea" in r["site_caveat"]
