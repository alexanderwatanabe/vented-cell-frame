// SPDX-License-Identifier: CERN-OHL-S-2.0
// The calibration coupon: a 2 x 2 corner of the frame, one band of bows deep, with its FIT_OFFSET cut into a tab. It
// takes every input the frame does, so give it the same cell, gap or pitch, and grip as the frame you mean to print.
// tools/coupon_set.py renders a set of them at a spread of offsets as one print; push four of your cells into each,
// keep the offset that fits best, and set it as FIT_OFFSET (README, "Print the coupon set first").
//
//   openscad --backend=manifold -o coupon.stl -D 'CELL="21700"' -D FIT_OFFSET=0.1 coupon.scad

include <frame.scad>

/* [Hidden] */
NC = 2;
NR = 2;
FRAME_L = SPACER_INSET + BAND_H + 1;   // the band, 1 mm under it as in the frame, and 1 mm over it
BANDS = [[SPACER_INSET, SPACER_INSET + BAND_H]];
TAB_T = 1.6;            // mm, the label tab's thickness, lying on the bed
TAB_OUT = 10;           // mm the tab stands out past the frame's outside
TEXT_SIZE = 5;          // mm
TEXT_DEPTH = 0.6;       // mm the label is cut into the tab
LABEL = str(CELL, " ", FIT_OFFSET >= 0 ? "+" : "", FIT_OFFSET);
LABEL_W = 0.75 * TEXT_SIZE * len(LABEL) + 6;   // mm, the tab's width: about the label's, and a margin

// The tab, off the outside of the wall under the first row, between its two cells: from inside that wall's face (so
// it fuses) out past the frame's outside.
module tab() translate([P / 2, 0, 0]) difference() {
    translate([-LABEL_W / 2, -OUT - TAB_OUT, 0]) cube([LABEL_W, OUT + TAB_OUT - (BAND_OUT - 0.5), TAB_T]);
    translate([0, -OUT - TAB_OUT / 2, TAB_T - TEXT_DEPTH]) linear_extrude(TEXT_DEPTH + 0.01)
        text(LABEL, size = TEXT_SIZE, halign = "center", valign = "center");
}

if (VIEW == "part") color("Orange") tab();
