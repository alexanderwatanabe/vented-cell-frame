// SPDX-License-Identifier: CERN-OHL-S-2.0
// The calibration coupon: a 2 x 2 corner of the frame, one band of bows deep. Print it first, push four of your
// cells in, and judge the fit by hand; then set FIT_OFFSET (README, "Print the coupon first"). It takes every input
// the frame does, so set the same CELL, CELL_GAP or PITCH, and GRIP as the frame you mean to print.
//
//   openscad --backend=manifold -o coupon.stl -D 'CELL="21700"' coupon.scad

include <frame.scad>

NC = 2;
NR = 2;
FRAME_L = 7;            // mm: the band and the 1 mm under it, so the cell meets the bows at the top as it would in the frame
BANDS = [[1, 6]];
