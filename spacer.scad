// SPDX-License-Identifier: CERN-OHL-S-2.0
// The gap spacer: a loose part for the diagonal gap where four cells meet, pushed in near each end of the block. The
// frame grips the edge cells; the spacers grip the cells inside. A square grid of tight-pitched printed holes would
// meet between side neighbours, leaving plastic only in the diagonal gaps, so this is that plastic and nothing else.
//
// Its four faces are arcs of the four cells round it. The arms run out into the side gaps until they are ARM_TIP_W
// wide; they stop it spinning, and their flanks are lands just clear of the cells along the full height, so it cannot
// tilt. Between them, a bow in a pocket on each face grips its cell (lib/grip.scad). Each bow runs the full height,
// so every layer of it stands on the one below.
//
// It needs a diagonal gap wide enough for a bow: small cells at a tight pitch have none (README, "Grip").
//
//   openscad -o spacer.stl spacer.scad
//   openscad -o spacer.stl -D 'CELL="21700"' -D CELL_GAP=2 spacer.scad

/* [Cell] */
CELL = "33140";         // a preset in lib/cells.scad, or "custom" with CELL_D and CELL_L
CELL_D = undef;         // mm, overrides the preset's body diameter
CELL_L = undef;         // mm, overrides the preset's body length
FIT_OFFSET = 0;         // mm, how much bigger the printed grip sees the cell than CELL_D: from the coupon (README)
CELL_GAP = 0.8;         // mm between neighbouring cells' bodies: 0.8, the printed bores just meet
PITCH = undef;          // mm, overrides CELL_D + CELL_GAP: usually the busbars set it

/* [Spacer] */
H = 18;                 // mm, the spacer's length along the cells: its lands far apart, so it can't rock
VIEW = "part";          // part | inplace | top

include <lib/grip.scad>

CELLS = [for (sx = [-1, 1], sy = [-1, 1]) [sx * P / 2, sy * P / 2]];
NECK = neck(SPAN_IN_GAP);
assert(GAP_SPAN >= BOW_SPAN_MIN, str("the diagonal gap holds a bow of ", GAP_SPAN, " mm, under BOW_SPAN_MIN ",
    BOW_SPAN_MIN, ": widen CELL_GAP or PITCH"));
assert(NECK >= NECK_MIN - 1e-9, str("the core's necks are ", NECK, " mm"));
assert(ARM_R > GAP_R, "the arms reach past the core");

module at_cells() for (c = CELLS) toward(c, [0, 0]) children();
module body_2d(land_d) difference() {
    circle(r = ARM_R);
    for (c = CELLS) translate(c) circle(d = land_d);
    at_cells() pocket_2d(SPAN_IN_GAP);
}

module spacer() {
    // the lands and the plain middle; the chamfers stepped at the ends
    n_ch = ceil(CHAMFER / SLICE);
    linear_extrude(H) body_2d(LAND_D + 2 * CHAMFER);
    translate([0, 0, CHAMFER]) linear_extrude(H - 2 * CHAMFER) body_2d(LAND_D);
    for (i = [0:n_ch - 1], e = [0, 1]) let(z = i * CHAMFER / n_ch, d = LAND_D + 2 * (CHAMFER - z))
        translate([0, 0, e == 0 ? z : H - z - CHAMFER / n_ch]) linear_extrude(CHAMFER / n_ch + 0.01) body_2d(d);
    // the bows, contoured: flush with the bore at both ends, TIP at the middle
    n = ceil(H / SLICE);
    for (i = [0:n - 1]) let(z0 = i * H / n, z1 = (i + 1) * H / n)
        translate([0, 0, z0]) linear_extrude(z1 - z0 + 0.01) at_cells() bow_2d(tip_in_band((z0 + z1) / 2, H), SPAN_IN_GAP);
}

module cell(h = 60) color("SteelBlue", 0.45) translate([0, 0, -h / 2 + H / 2]) cylinder(d = CELL_FIT, h = h);

if (VIEW == "part") color("Orange") spacer();
if (VIEW == "inplace") { color("Orange") spacer(); for (c = CELLS) translate(c) cell(); }
if (VIEW == "top") { color("Orange") spacer(); for (c = CELLS) translate(c) color("SteelBlue", 0.45) cylinder(d = CELL_FIT, h = 1); }

echo(SPACER = [["cell", CELL], ["body_d", BODY_D], ["cell_fit", CELL_FIT], ["pitch", P], ["bow_span", SPAN_IN_GAP],
    ["neck", NECK], ["across_arms", 2 * ARM_R], ["inscribed_d", 2 * GAP_R], ["height", H], ["land_d", LAND_D],
    ["bow_stands_past_land", (LAND_D - TIP) / 2], ["tilt_deg_max", atan(LAND_CLR / H)]]);
