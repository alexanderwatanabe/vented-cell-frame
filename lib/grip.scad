// SPDX-License-Identifier: CERN-OHL-S-2.0
// The grip the frame (frame.scad) and the loose gap spacer (spacer.scad) share, so the two hold a cell alike: a bow
// spring in a pocket, a thin curved wall rooted in both of the pocket's side walls and bulging toward its cell. With
// no free end, nothing catches on the cell as it slides in. Each bow is contoured along the cell's axis like a
// sphere: furthest in at its band's middle and flush with the bore at both ends, so a cell's end edge meets a slope.
// It draws nothing itself.
//
// The part's file sets the cell inputs before including this: CELL, CELL_D, CELL_L, FIT_OFFSET, CELL_GAP, PITCH.

include <cells.scad>

// The spring. Its sizes are millimetres set by the nozzle and the plastic, not by the cell: the cell only sets where
// the spring sits. They were fit-tested on a 33.2 mm cell in PETG with a 0.4 mm nozzle.
BOW_T = 0.9;            // mm, two lines of a 0.4 nozzle
BOW_SPAN = 8;           // mm, the bow's span between its roots, the pocket's width: the tested length, the longest drawn
BOW_SPAN_MIN = 5;       // mm, the shortest bow drawn: shorter, at BOW_T, it is too stiff to spring. ESTIMATE: untested
BOW_ROOT = 0.8;         // mm past the bore where the bow's ends meet the pocket's side walls: how deep it bows
ROOT_EMBED = 0.6;       // mm each end runs into the side wall, so the root is solid plastic, not a touching corner
POCKET_D = 1.6;         // mm past the bore: room behind the roots (BOW_ROOT + BOW_T / 2), and no deeper, so necks stay wide
BORE_CLR = 0.8;         // mm on diameter, the bore round the bows past the cell: a plain bore this size is a bit loose
TIP_PRESS = 0.1;        // mm on diameter, the bows' middles stand this far inside the cell: flush was a tad loose
LAND_CLR = 0.2;         // mm on diameter, the spacer's lands to the cell: close enough to stop tilt, not to bind
ARM_TIP_W = 2;          // mm, an arm is cut where the side gap narrows to this: thinner won't print as a wall
NECK_MIN = 1.6;         // mm, the narrowest plastic between two neighbouring pockets: four lines
CHAMFER = 0.6;          // mm, a 45 degree lead-in on the lands at both ends
SLICE = 0.25;           // mm, the contoured bows' step along the axis

$fn = 120;

PRESET = cell_preset(CELL);
assert(CELL == "custom" || !is_undef(PRESET), str("unknown cell \"", CELL, "\": use one of ", CELL_NAMES, " or \"custom\""));
BODY_D = is_undef(CELL_D) ? (is_undef(PRESET) ? undef : PRESET[1]) : CELL_D;   // mm, the cell's body
BODY_L = is_undef(CELL_L) ? (is_undef(PRESET) ? undef : PRESET[2]) : CELL_L;   // mm, end face to end face
assert(is_num(BODY_D) && is_num(BODY_L), "a custom cell needs CELL_D and CELL_L");

CELL_FIT = BODY_D + FIT_OFFSET;   // the cell as the printed grip sees it
BORE = CELL_FIT + BORE_CLR;       // the bore the bows and pockets are drawn round
TIP = CELL_FIT - TIP_PRESS;       // across the bows' middles
P = is_undef(PITCH) ? BODY_D + CELL_GAP : PITCH;   // the cell pitch
LAND_D = CELL_FIT + LAND_CLR;

// An arm (along an axis, between two side neighbours) is cut where it is ARM_TIP_W wide; where the side gap is wider
// than that all the way, it runs to the gap's middle.
ARM_R = P / 2 - sqrt(max(0, pow(LAND_D / 2, 2) - pow(P / 2 - ARM_TIP_W / 2, 2)));
GAP_R = P / sqrt(2) - LAND_D / 2;   // the centre of a diagonal gap to a land: its inscribed circle

// In a diagonal gap the pockets' inner walls stand POCKET_IN from the gap's centre, and two neighbouring pockets'
// inner corners leave a neck between them. The longest bow the gap holds leaves NECK_MIN there.
POCKET_IN = P / sqrt(2) - BORE / 2 - POCKET_D;
GAP_SPAN = 2 * (POCKET_IN - NECK_MIN / sqrt(2));
SPAN_IN_GAP = min(BOW_SPAN, GAP_SPAN);
function neck(span) = sqrt(2) * (POCKET_IN - span / 2);

assert(P > CELL_FIT, str("the pitch ", P, " is under the cell's ", CELL_FIT, ": neighbours would collide"));
assert(TIP < LAND_D, "the bows must stand in past the lands");
assert(BOW_ROOT + BOW_T / 2 < POCKET_D, "the bows' roots fit in the pocket");

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
