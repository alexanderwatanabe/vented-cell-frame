// SPDX-License-Identifier: CERN-OHL-S-2.0
// The grip the frame (frame.scad) and the loose gap spacer (spacer.scad) share, so the two hold a cell alike: a bow
// spring in a pocket, a thin curved wall rooted in both of the pocket's side walls and bulging toward its cell. With
// no free end, nothing catches on the cell as it slides in. Each bow is contoured along the cell's axis like a
// sphere: furthest in at its band's middle and flush with the bore at both ends, so a cell's end edge meets a slope.
// It draws nothing itself.
//
// The part's file sets its inputs before including this: the cell (CELL, CELL_D, CELL_L, FIT_OFFSET, CELL_GAP, PITCH)
// and the spring.

include <cells.scad>

// The spring's inputs (BOW_T, BOW_SPAN, BOW_SPAN_MIN, BORE_CLR, TIP_PRESS, NECK_MIN, ARM_TIP_W) are the part's, in its
// Customizer sections; these follow from them or are fixed by the bow's shape.
BOW_ROOT = 0.8;         // mm past the bore where the bow's ends meet the pocket's side walls: how deep it bows
ROOT_EMBED = 0.6;       // mm each end runs into the side wall, so the root is solid plastic, not a touching corner
ROOT_ROOM = 0.35;       // mm of pocket behind the roots
POCKET_D = BOW_ROOT + BOW_T / 2 + ROOT_ROOM;   // mm past the bore: no deeper, so the necks between pockets stay wide
CHAMFER = 0.6;          // mm, a 45 degree lead-in on the lands at both ends
SLICE = 0.25;           // mm, the contoured bows' step along the axis

$fn = 120;

PRESET = cell_preset(CELL);
assert(CELL == "custom" || !is_undef(PRESET), str("unknown cell \"", CELL, "\": use one of ", CELL_NAMES, " or \"custom\""));
BODY_D = CELL_D == 0 ? (is_undef(PRESET) ? undef : PRESET[1]) : CELL_D;   // mm, the cell's body
BODY_L = CELL_L == 0 ? (is_undef(PRESET) ? undef : PRESET[2]) : CELL_L;   // mm, end face to end face
assert(is_num(BODY_D) && is_num(BODY_L), "a custom cell needs CELL_D and CELL_L");

CELL_FIT = BODY_D + FIT_OFFSET;   // the cell as the printed grip sees it
BORE = CELL_FIT + BORE_CLR;       // the bore the bows and pockets are drawn round
TIP = CELL_FIT - TIP_PRESS;       // across the bows' middles
P = PITCH == 0 ? BODY_D + CELL_GAP : PITCH;   // the cell pitch

// A spacer's arm (along an axis, between two side neighbours) is cut where it is ARM_TIP_W wide, its flanks lands of
// diameter land_d; where the side gap is wider than that all the way, it runs to the gap's middle. The frame's ridges
// are cut the same way.
function arm_r(land_d) = P / 2 - sqrt(max(0, pow(land_d / 2, 2) - pow(P / 2 - ARM_TIP_W / 2, 2)));

// In a diagonal gap the pockets' inner walls stand POCKET_IN from the gap's centre, and two neighbouring pockets'
// inner corners leave a neck between them. The longest bow the gap holds leaves NECK_MIN there.
POCKET_IN = P / sqrt(2) - BORE / 2 - POCKET_D;
GAP_SPAN = 2 * (POCKET_IN - NECK_MIN / sqrt(2));
SPAN_IN_GAP = min(BOW_SPAN, GAP_SPAN);
function neck(span) = sqrt(2) * (POCKET_IN - span / 2);

assert(P > CELL_FIT, str("the pitch ", P, " is under the cell's ", CELL_FIT, ": neighbours would collide"));

// A bow and its pocket, in a frame whose x runs out from the cell's centre through the pocket's middle.
function bow_x(y, tip, span) = tip / 2 + (BORE / 2 + BOW_ROOT - tip / 2) * pow(y / (span / 2), 2);
module bow_2d(tip, span) {
    n = 16; y0 = span / 2 + ROOT_EMBED;
    intersection() {
        for (k = [0:n - 1]) let(ya = -y0 + 2 * y0 * k / n, yb = -y0 + 2 * y0 * (k + 1) / n)
            hull() { translate([bow_x(ya, tip, span), ya]) circle(d = BOW_T, $fn = 16); translate([bow_x(yb, tip, span), yb]) circle(d = BOW_T, $fn = 16); }
        translate([BORE / 2 - 1, -span / 2 - 1]) square([POCKET_D + 2, span + 2]);
    }
}
module pocket_2d(span) translate([BORE / 2 - 1, -span / 2]) square([POCKET_D + 1, span]);
// A cell's frame pointing from its centre c toward the point g.
module toward(c, g) translate(c) rotate(atan2(g[1] - c[1], g[0] - c[0])) children();
// Across the bows' middles at z up a band of height h: the bore at both ends, TIP at the middle.
function tip_in_band(z, h) = BORE - (BORE - TIP) * (1 - pow(2 * z / h - 1, 2));
