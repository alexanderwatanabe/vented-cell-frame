# SPDX-License-Identifier: CERN-OHL-S-2.0
"""The parts as drawn: each comes out as one solid, the size the frame reports, with its pockets clear behind the
bows. These render with the Manifold backend, a few seconds each."""

import pytest

from conftest import COUPON, ROOT, TESTED, bounds, echoed, evaluate, needs_manifold, render, solids

pytestmark = needs_manifold


@pytest.mark.parametrize("overrides", [dict(TESTED), dict(CELL='"21700"')], ids=["gap-grip", "wall-grip"])
def test_a_coupon_is_one_solid(tmp_path, overrides):
    triangles = render(tmp_path, ROOT / "frame.scad", **overrides, **COUPON)
    assert triangles and solids(triangles) == 1


def test_a_small_frame_is_one_solid_the_size_it_reports(tmp_path):
    overrides = dict(CELL='"21700"', CELL_COLUMNS=2, CELL_ROWS=2)
    ok, text = evaluate(tmp_path, "frame", **overrides)
    assert ok, text
    frame = echoed(text, "FRAME")
    triangles = render(tmp_path, ROOT / "frame.scad", **overrides)
    assert triangles and solids(triangles) == 1
    assert bounds(triangles) == pytest.approx(frame["footprint"] + [frame["height"]], abs=0.3)


def test_a_spacer_is_one_solid(tmp_path):
    triangles = render(tmp_path, ROOT / "spacer.scad", CELL='"33140"', FIT_OFFSET=-0.1, PITCH=34)
    assert triangles and solids(triangles) == 1


def probe(tmp_path, y0, y1):
    """The 21700 coupon (wall grip) cut down to a box behind its first bow's middle: 2 mm wide, 1 mm high at mid-band,
    y0 to y1 out from the cell's axis toward the wall. Its triangles, or None if the box is empty."""
    scad = tmp_path / "probe.scad"
    scad.write_text(f'include <{ROOT / "frame.scad"}>\n'
                    f"intersection() {{ part(); translate([-1, -{y1}, 3]) cube([2, {y1 - y0}, 1]); }}\n")
    return render(tmp_path, scad, CELL='"21700"', VIEW='"none"', **COUPON)


def test_a_wall_grip_pocket_is_clear_behind_its_bow(tmp_path):
    # the 21700's bow backs onto 11.0 mm from the cell's axis at mid-band and its pocket reaches 12.6
    assert probe(tmp_path, 11.3, 12.4) is None
    assert probe(tmp_path, 13.0, 14.0)   # the wall behind the pocket is solid: the probe works
