"""The committed SRTM terrain check (docs/checks/srtm_terrain.csv) supports the app's data-point choices and cell warnings."""
import csv
from pathlib import Path

ROWS = list(csv.DictReader(open(Path(__file__).resolve().parents[1] / "docs" / "checks" / "srtm_terrain.csv", encoding="utf8")))


def test_all_nineteen_points_are_described():
    assert len(ROWS) == 19


def test_named_points_are_on_the_flat_floodplain():
    named = [r for r in ROWS if r["kind"] == "named"]
    assert len(named) == 7
    for r in named:
        assert -10 <= int(r["height_at_point_m"]) <= 15, r["point"]
        assert float(r["cell_share_above_100m"]) <= 0.05, r["point"]


def test_desert_edge_warnings_match_measured_plateau_share():
    flagged = [float(r["cell_share_above_100m"]) for r in ROWS if r["app_caveat"] == "desert_edge"]
    other = [float(r["cell_share_above_100m"]) for r in ROWS if r["kind"] == "cell" and r["app_caveat"] == ""]
    assert flagged and other
    assert min(flagged) > max(other)  # every warned cell is more plateau than every unwarned one
