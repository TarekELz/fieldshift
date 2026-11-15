"""Crop economics: national-average gross income per feddan, adjusted for salt. Checks arithmetic and directions, not prices."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from fieldshift import economics as ec  # noqa: E402

CROPS, FED = ec.load()


def test_registry_and_numbers_load():
    assert {"rice", "wheat", "maize", "cotton", "sugar_beet", "onion", "potato", "tomato", "orange", "faba_bean", "grape", "date_palm", "barley", "sorghum"} <= set(CROPS)
    assert FED == 0.42
    for c in CROPS.values():
        assert c["yield_kg_ha"] > 0 and c["price_egp_per_t"] > 0 and c["price_year"] == 2022 and c["ar"] and c["aliases"]


def test_gross_is_yield_times_area_times_price():
    r = ec.gross_per_feddan("wheat", None, CROPS, FED)
    assert r["gross_egp"] == round(CROPS["wheat"]["yield_kg_ha"] / 1000 * 0.42 * CROPS["wheat"]["price_egp_per_t"])
    assert r["salt_known"] is False and r["gross_egp"] == r["base_egp"]


def test_salt_lowers_income_by_the_fao_factor():
    clean, salty = ec.gross_per_feddan("rice", 2.0, CROPS, FED), ec.gross_per_feddan("rice", 6.0, CROPS, FED)  # rice: 100% at ECe 3, 64% at 6
    assert clean["salt_pct"] == 100 and salty["salt_pct"] == 64
    assert abs(salty["gross_egp"] - salty["base_egp"] * 0.64) <= salty["base_egp"] * 0.01  # the factor is the unrounded table value


def test_beyond_the_table_means_at_most_half():
    r = ec.gross_per_feddan("maize", 12.0, CROPS, FED)  # maize has no value above 5.9 dS/m
    assert r["salt_pct"] is None and r["salt_known"] and r["gross_egp"] == round(r["base_egp"] * 0.5)


def test_no_salt_data_for_sorghum_is_not_a_penalty():
    r = ec.gross_per_feddan("sorghum", 6.0, CROPS, FED)
    assert r["salt_known"] is False and r["gross_egp"] == r["base_egp"]


def test_rank_is_sorted_and_grouped():
    r = ec.rank("winter", None, CROPS, FED)
    assert [x["gross_egp"] for x in r] == sorted((x["gross_egp"] for x in r), reverse=True)
    assert {x["crop"] for x in r} == {"wheat", "barley", "faba_bean", "sugar_beet", "onion"}
