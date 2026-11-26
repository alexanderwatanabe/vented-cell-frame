# SPDX-License-Identifier: CERN-OHL-S-2.0
"""The frame, its coupon and the gap spacer: the tested configuration, and what each refuses."""

import ast
import re

import pytest

from conftest import COUPON, TESTED, echoed, evaluate, needs_openscad

pytestmark = needs_openscad


def test_tested_configuration_keeps_its_shape(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["cells"] == [4, 6] and frame["height"] == 138
    assert frame["footprint"] == pytest.approx([152.6, 220.6], abs=0.05)
    assert frame["grip"] == "gap" and frame["bow_span"] == 8
    # every gap between two edge cells holds a ridge with a bow facing each cell; the round corners hold none
    assert frame["bows_per_band"] == 2 * (2 * 3 + 2 * 5)
    assert frame["up_waves"] == 4
    # the bows' faces stand 1.0 mm inside the cell on diameter at their middle, as tested: 0.8 past the frame's land
    assert frame["bow_past_land"] == pytest.approx(0.8)


def test_walls_open_and_print_without_support(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["steepest_inside_deg"] <= 45 and frame["steepest_outside_deg"] <= 45
    assert frame["open_share"] > 0.1
    assert frame["tie_shortest"] >= 6 and frame["column_narrowest"] >= 0.35 * 34
    assert 0 < frame["vent_bridge"] <= 10


def test_coupon_is_a_corner_of_the_frame(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, **COUPON)
    assert ok, text
    coupon = echoed(text, "FRAME")
    assert coupon["cells"] == [2, 2] and coupon["bows_per_band"] == 8 and coupon["height"] == 7
    assert coupon["open_share"] == 0 and coupon["up_waves"] == 0


def test_a_coupon_stays_two_by_two(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, **COUPON, CELL_COLUMNS=5, CELL_ROWS=3)
    assert ok, text
    assert echoed(text, "FRAME")["cells"] == [2, 2]


def test_a_coupon_sets_grip_does_not_change_with_its_offset(tmp_path):
    grips = set()
    for offset in (-0.2, 0.4):   # before the fix, auto chose by the fitted size and flipped near +0.5
        ok, text = evaluate(tmp_path, "frame", CELL='"26650"', FIT_OFFSET=offset, **COUPON)
        assert ok, text
        grips.add(echoed(text, "FRAME")["grip"])
    assert len(grips) == 1


def test_spacer_keeps_its_tested_shape(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"33140"', FIT_OFFSET=-0.1, PITCH=34)
    assert ok, text
    spacer = echoed(text, "SPACER")
    assert spacer["land_d"] == pytest.approx(33.4)
    assert spacer["neck"] == pytest.approx(2.04, abs=0.01)
    assert spacer["bow_past_land"] == pytest.approx(0.6)


def test_small_cells_take_the_wall_grip_with_a_full_bow(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"18650"')
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["grip"] == "wall" and frame["bow_span"] == 8
    assert frame["bows_per_band"] == 2 * (4 + 6)   # one in front of each edge cell on each wall it stands on


@pytest.mark.parametrize("overrides, refusal", [
    (dict(TROUGH_DEPTH=2), "never pass the datum"),
    (dict(ALONG_SHARE=1.5), "ALONG_SHARE is a share"),
    (dict(CELL_COLUMNS=8), "bigger than the printer"),
    (dict(CELL_L=50), "too short for its vents"),
    (dict(CELL_L=56), "too short for whole vents"),
    (dict(GRIP='"none"'), "GRIP is auto, gap or wall"),
    (dict(PART='"lid"'), "PART is frame or coupon"),
    (dict(VIEW='"top"'), "VIEW is part, with_cells or none"),
    (dict(ALONG_SHARE=0, STAGGER=0, UP_WAVELENGTH=60, BUMP_DEPTH=0), "the frame would come apart"),
    (dict(BOW_SPAN=4), "under BOW_SPAN_MIN"),
    (dict(BOW_PRESS=0), "BOW_PRESS must be above 0"),
    (dict(CELL_ROWS=5, STAGGER=0.25), "CELL_COLUMNS + CELL_ROWS must be even"),
    (dict(CELL_COLUMNS=2.5), "whole numbers"),
    (dict(STAGGER=0.3), "STAGGER is 0 or 1 / n"),
    (dict(BRIDGE_MAX=5), "the printer would have to bridge it"),
], ids=["closed", "along-share", "printer", "short", "slivers", "grip-name", "part-name", "view-name", "ring",
        "bow-span", "bow-press", "stagger-odd", "half-cells", "stagger-repeat", "bridge"])
def test_frame_refuses(tmp_path, overrides, refusal):
    ok, text = evaluate(tmp_path, "frame", **{**TESTED, **overrides})
    assert not ok and refusal in text, text[-600:]


def test_a_wave_steeper_than_45_degrees_is_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, WAVES_PER_CELL=2)
    assert not ok and "past 45 it would need support" in text


def test_short_ties_between_vents_are_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, TROUGH_DEPTH=6)
    assert not ok and "shortest tie between vents" in text


def test_narrow_columns_between_vents_are_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED, ALONG_SHARE=0.3)
    assert not ok and "narrowest column between vents" in text


def test_cells_that_would_overlap_are_refused_whatever_the_fit(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"21700"', PITCH=20.8, FIT_OFFSET=-0.6)
    assert not ok and "neighbouring cells would overlap" in text


def test_wall_grip_pockets_leave_the_wall_whole_behind_them(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"21700"', WALL_T=1.5)
    assert not ok and "the wall grip's pockets reach within" in text


def test_the_gap_grip_is_refused_where_the_gap_holds_no_bow(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"18650"', GRIP='"gap"')
    assert not ok and 'use GRIP = "wall"' in text


def test_the_spacer_is_refused_where_the_gap_holds_no_bow(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"18650"')
    assert not ok and "widen CELL_GAP or PITCH" in text


def test_a_spacer_bow_under_the_shortest_span_is_refused(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"33140"', FIT_OFFSET=-0.1, PITCH=34, BOW_SPAN=4)
    assert not ok and "under BOW_SPAN_MIN" in text


def test_an_unknown_cell_is_refused(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"99999"')
    assert not ok and "unknown cell" in text


def test_a_custom_cell_needs_its_size(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"custom"', CELL_D=20)
    assert not ok and "needs its length" in text


def test_a_custom_spacer_needs_only_its_diameter(tmp_path):
    ok, text = evaluate(tmp_path, "spacer", CELL='"custom"', CELL_D=33.2, PITCH=34)
    assert ok, text


def test_a_custom_cell_is_drawn_from_its_size(tmp_path):
    ok, text = evaluate(tmp_path, "frame", CELL='"custom"', CELL_D=20, CELL_L=70)
    assert ok, text
    assert echoed(text, "FRAME")["pitch"] == pytest.approx(20.8)


def test_a_preset_named_as_a_number_is_found(tmp_path):
    # the Customizer's dropdown hands numeric-looking names over as numbers
    ok, text = evaluate(tmp_path, "frame", CELL=18650)
    assert ok, text
    assert echoed(text, "FRAME")["body_d"] == 18.5


@pytest.mark.parametrize("overrides", [
    dict(ALONG_SHARE=0.7), dict(STAGGER=0), dict(STAGGER=0.25), dict(MIRROR=0.7), dict(UP_WAVELENGTH=15),
    dict(UP_WAVELENGTH=40), dict(UP_PHASE=0),
], ids=["slots", "aligned", "quarter-step", "thicker", "short-waves", "long-waves", "phase-0"])
def test_the_vents_can_be_reshaped(tmp_path, overrides):
    # the slopes and the open share, that is: some of these shapes widen a vent's top past the default bridge
    ok, text = evaluate(tmp_path, "frame", **TESTED, BRIDGE_MAX=12, **overrides)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["steepest_inside_deg"] <= 45 and frame["steepest_outside_deg"] <= 45 and frame["open_share"] >= 0.1


def test_shorter_waves_up_the_frame_make_shorter_vents(tmp_path):
    def tallest(wavelength):
        ok, text = evaluate(tmp_path, "frame", **TESTED, BRIDGE_MAX=12, UP_WAVELENGTH=wavelength)
        assert ok, text
        return echoed(text, "FRAME")["vent_tallest"]
    assert tallest(15) < tallest(25) < tallest(40)


def test_the_wall_map_covers_one_repeat_and_the_full_height(tmp_path):
    ok, text = evaluate(tmp_path, "frame", **TESTED)
    assert ok, text
    wall = dict(ast.literal_eval(re.search(r"^ECHO: WALL_MAP = (.+)$", text, re.M).group(1)))
    rows = wall["rows"]
    assert wall["pitch"] == 34
    assert len(rows[0]) * wall["ds"] == pytest.approx(2 * 34)    # brick bond repeats every two cells
    assert (len(rows) - 1) * wall["dz"] == pytest.approx(138, abs=wall["dz"])
    values = [v for row in rows for v in row]
    assert 0 in values and any(v > 0 for v in values) and any(v < 0 for v in values)   # vents, wall, contact
