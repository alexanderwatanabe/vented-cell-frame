# SPDX-License-Identifier: CERN-OHL-S-2.0
"""The coupon set's offsets and its layout on the plate."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from coupon_set import GAP, layout, offsets  # noqa: E402


def test_offsets_spread_evenly_round_the_centre():
    assert offsets(-0.1, 0.05, 3) == [-0.15, -0.1, -0.05]
    assert offsets(0, 0.2, 4) == [-0.3, -0.1, 0.1, 0.3]


def test_coupons_wrap_onto_a_new_row_when_the_plate_is_full():
    spots = layout([(100, 80)] * 3, 250)
    assert spots == [(0, 0), (100 + GAP, 0), (0, 80 + GAP)]


def test_a_set_bigger_than_the_plate_is_refused():
    assert layout([(160, 160)] * 3, 270) is None
