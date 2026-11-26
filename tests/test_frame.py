# SPDX-License-Identifier: CERN-OHL-S-2.0
"""The frame, its coupon and the gap spacer: the tested configuration, and what each refuses."""

import pytest

from conftest import TESTED, echoed, evaluate, needs_openscad

pytestmark = needs_openscad


def test_tested_configuration_keeps_its_shape(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["cells"] == [4, 6] and frame["size"] == [157, 225] and frame["length"] == 138
    assert frame["grip"] == "gap" and frame["bow_span"] == 8
    # every gap between two edge cells holds a ridge with a bow facing each cell; the round corners hold none
    assert frame["bows"] == 2 * (2 * 3 + 2 * 5)
    assert frame["contacts"] == 4
    assert frame["bow_stands_past_land"] > 0


def test_walls_open_and_print_without_support(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["steepest_deg"] <= 45 and frame["steepest_out_deg"] <= 45
    assert frame["open_fraction"] > 0.1
    assert frame["tie_shortest"] >= 6 and frame["column_narrowest"] >= 12


def test_coupon_is_a_corner_of_the_frame(tmp_path):
    ok, text = evaluate(tmp_path, "coupon", **TESTED)
    assert ok, text
    coupon = echoed(text, "FRAME")
    assert coupon["cells"] == [2, 2] and coupon["bows"] == 8 and coupon["open_fraction"] == 0 and coupon["length"] == 7


def test_spacer_keeps_its_tested_shape(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"33140"', FIT_OFFSET=-0.1, PITCH=34)
    assert ok, text
    spacer = echoed(text, "SPACER")
    assert spacer["land_d"] == pytest.approx(33.4)
    assert spacer["neck"] == pytest.approx(2.04, abs=0.01)
    assert spacer["bow_stands_past_land"] == pytest.approx(0.15)


def test_small_cells_take_the_wall_grip_with_a_full_bow(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"18650"')
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["grip"] == "wall" and frame["bow_span"] == 8
    assert frame["bows"] == 2 * (4 + 6)   # one in front of each edge cell on each wall it stands on


@pytest.mark.parametrize("overrides, refusal", [
    (dict(CHANNEL=14, TIE_MIN=0, COLUMN_SHARE=0), "past 45 it would need support"),
    (dict(CHANNEL=2), "never passes the datum"),
    (dict(PLAN_WEIGHT=1.5), "PLAN_WEIGHT is a share"),
    (dict(NC=8), "bigger than the printer"),
    (dict(CELL_L=50), "too short for its wave"),
    (dict(CELL_L=56), "the frame is too short for whole vents"),
    (dict(GRIP='"none"'), "GRIP is auto, gap or wall"),
], ids=["steep", "closed", "plan-weight", "printer", "short", "slivers", "grip-name"])
def test_frame_refuses(tmp_path, overrides, refusal):
    ok, text = evaluate(tmp_path, "frame", **{**TESTED, **overrides})
    assert not ok and refusal in text


def test_short_ties_between_openings_are_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, PLAN_L="P / 2", PLAN_WEIGHT=0.6, CHANNEL=6, REFLECT=0.5, COLUMN_SHARE=0)
    assert not ok and "shortest tie between openings" in text


def test_narrow_columns_between_openings_are_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, PLAN_L="P / 2", PLAN_WEIGHT=0.35, CHANNEL=5.5, REFLECT=0.5, TIE_MIN=0)
    assert not ok and "narrowest column between openings" in text


def test_the_gap_grip_is_refused_where_the_gap_holds_no_bow(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"18650"', GRIP='"gap"')
    assert not ok and "use GRIP = \"wall\"" in text


def test_the_spacer_is_refused_where_the_gap_holds_no_bow(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"18650"')
    assert not ok and "widen CELL_GAP or PITCH" in text


def test_an_unknown_cell_is_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"99999"')
    assert not ok and "unknown cell" in text


def test_a_custom_cell_needs_its_size(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"custom"')
    assert not ok and "needs CELL_D and CELL_L" in text


def test_a_custom_cell_is_drawn_from_its_size(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"custom"', CELL_D=20, CELL_L=70)
    assert ok, text
    assert echoed(text, "FRAME")["pitch"] == pytest.approx(20.8)


def test_a_preset_named_as_a_number_is_found(tmp_path):
    # the Customizer's dropdown hands numeric-looking names over as numbers
    ok, text = evaluate(tmp_path, "frame", CELL=18650, VIEW='"none"')
    assert ok, text
    assert echoed(text, "FRAME")["body"] == [18.5, 65]
