// SPDX-License-Identifier: CERN-OHL-S-2.0
// The grip the frame (frame.scad) and the loose gap spacer (spacer.scad) share, so the two hold a cell alike: a bow
// spring in a pocket, a thin curved wall rooted in both of the pocket's side walls and bulging toward its cell. With
// no free end, nothing catches on the cell as it slides in. Each bow is contoured along the cell's axis like a
// sphere: furthest in at its band's middle and back toward the bore at both ends, so a cell's end edge meets a slope.
// It draws nothing itself.
//
// The part's file sets its inputs before including this: the cell (CELL, CELL_D, CELL_L, FIT_OFFSET, CELL_GAP, PITCH)
// and the spring (BOW_SPAN, BOW_SPAN_MIN, BOW_T, BOW_PRESS, BORE_CLR, NECK_MIN, ARM_TIP_W).

include <cells.scad>

// These follow from the spring's inputs or are fixed by the bow's shape.
BOW_ROOT = 0.8;         // mm past the bore where the bow's centreline meets the pocket's side walls: how deep it bows
ROOT_EMBED = 0.6;       // mm each end runs into the side wall, so the root is solid plastic, not a touching corner
ROOT_ROOM = 0.35;       // mm of pocket behind the roots
POCKET_DEPTH = BOW_ROOT + BOW_T / 2 + ROOT_ROOM;   // mm past the bore: no deeper, so the necks between pockets stay wide
CHAMFER = 0.6;          // mm, a 45 degree lead-in on the lands at both ends
SLICE = 0.25;           // mm, the contoured bows' step along the axis

$fn = 120;

PRESET = cell_preset(CELL);
assert(CELL == "custom" || !is_undef(PRESET), str("unknown cell \"", CELL, "\": use one of ", CELL_NAMES, " or \"custom\""));
BODY_D = CELL_D == 0 ? (is_undef(PRESET) ? undef : PRESET[1]) : CELL_D;   // mm, the cell's body
BODY_L = CELL_L == 0 ? (is_undef(PRESET) ? undef : PRESET[2]) : CELL_L;   // mm, end face to end face
assert(is_num(BODY_D), "a custom cell needs its diameter, CELL_D");

CELL_FIT = BODY_D + FIT_OFFSET;   // the cell as the printed grip sees it
BORE = CELL_FIT + BORE_CLR;       // the bore the bows and pockets are drawn round
// Across the bows' faces at a band's middle: BOW_PRESS inside the cell. Their centreline stands BOW_T / 2 behind.
BOW_FACE_D = CELL_FIT - BOW_PRESS;
P = PITCH == 0 ? BODY_D + CELL_GAP : PITCH;   // the cell pitch

// A spacer's arm (along an axis, between two side neighbours) is cut where it is ARM_TIP_W wide, its flanks lands of
// diameter land_d; where the side gap is wider than that all the way, it runs to the gap's middle. The frame's ridges
// are cut the same way.
function arm_r(land_d) = P / 2 - sqrt(max(0, pow(land_d / 2, 2) - pow(P / 2 - ARM_TIP_W / 2, 2)));

// In a diagonal gap the pockets' back walls stand pocket_in from the gap's centre, and two neighbouring pockets'
// corners leave a neck between them. The longest bow a gap holds leaves NECK_MIN there.
function pocket_in(bore) = P / sqrt(2) - bore / 2 - POCKET_DEPTH;
function gap_span_max(bore) = 2 * (pocket_in(bore) - NECK_MIN / sqrt(2));
GAP_SPAN_MAX = gap_span_max(BORE);
// The same for the cell's nominal size, before any fit offset: what the grip is chosen by, so a coupon set's
// offsets don't change it.
GAP_SPAN_NOMINAL = gap_span_max(BODY_D + BORE_CLR);
GAP_BOW_SPAN = min(BOW_SPAN, GAP_SPAN_MAX);   // a bow in a diagonal gap: as long as the gap allows, up to BOW_SPAN
function neck(span) = sqrt(2) * (pocket_in(BORE) - span / 2);

assert(P > BODY_D, str("the pitch ", P, " is under the cell's diameter ", BODY_D, ": neighbouring cells would overlap"));
assert(P > CELL_FIT, str("the pitch ", P, " is under the cell as the grip sees it, ", CELL_FIT,
    ": neighbouring cells' grips would overlap"));
assert(BOW_PRESS > 0, "BOW_PRESS must be above 0: the bows' faces must reach into the cell to grip it");

// A bow and its pocket, in a frame whose x runs out from the cell's centre through the pocket's middle. face_d is the
// diameter across the bows' faces at this height; the bow is a parabola through its middle there and its roots at
// BOW_ROOT past the bore.
function bow_x(y, face_d, span) = let(mid = face_d / 2 + BOW_T / 2)
    mid + (BORE / 2 + BOW_ROOT - mid) * pow(y / (span / 2), 2);
module bow_2d(face_d, span) {
    n = 16; y0 = span / 2 + ROOT_EMBED;
    intersection() {
        for (k = [0:n - 1]) let(ya = -y0 + 2 * y0 * k / n, yb = -y0 + 2 * y0 * (k + 1) / n)
            hull() { translate([bow_x(ya, face_d, span), ya]) circle(d = BOW_T, $fn = 16); translate([bow_x(yb, face_d, span), yb]) circle(d = BOW_T, $fn = 16); }
        // only the bow's run across its pocket; its face, wherever it stands, is left whole
        translate([min(BORE / 2, face_d / 2) - 1, -span / 2 - 1]) square([BORE / 2 - min(BORE / 2, face_d / 2) + POCKET_DEPTH + 2, span + 2]);
    }
}
module pocket_2d(span, depth = POCKET_DEPTH) translate([BORE / 2 - 1, -span / 2]) square([depth + 1, span]);
// A cell's frame pointing from its centre c toward the point g.
module toward(c, g) translate(c) rotate(atan2(g[1] - c[1], g[0] - c[0])) children();
// Across the bows' faces at z up a band of height h: BOW_FACE_D at the middle, the bore less the bow's thickness at
// both ends, a parabola between.
function bow_face_d_at(z, h) = let(end = BORE - BOW_T) end - (end - BOW_FACE_D) * (1 - pow(2 * z / h - 1, 2));
