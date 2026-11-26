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
// It needs a diagonal gap wide enough for a bow: small cells at a tight pitch have none (README, "The grip").
//
//   openscad -o spacer.stl spacer.scad
//   openscad -o spacer.stl -D 'CELL="21700"' -D CELL_GAP=2 spacer.scad

/* [Cell] */
// Cell — a preset, or "custom" with its diameter below
CELL = "21700"; // [18650, 21700, 26650, 32650, 32700, 33140, 40135, 4680, 66160, custom]
// Diameter (mm) — the cell's body; 0 takes the preset's
CELL_D = 0; // [0:0.1:100]
// Fit offset (mm) — added to the cell's diameter where the grip is drawn: positive if your coupons were tight, negative if loose
FIT_OFFSET = 0; // [-1:0.05:1]
// Gap between cells (mm) — between neighbouring cells' bodies; at 0.8 the printed holes round neighbouring cells just meet
CELL_GAP = 0.8; // [0:0.1:10]
// Pitch (mm) — centre to centre, overriding diameter + gap: set it when your busbars or nickel strip fix it; 0 to leave it
PITCH = 0; // [0:0.1:120]

/* [Grip] */
// Bow span (mm) — a bow spring's span between its roots: 8 is tested, and the longest drawn
BOW_SPAN = 8; // [4:0.5:12]
// Shortest bow span (mm) — the shortest allowed: shorter, it is too stiff to spring. Untested below 8
BOW_SPAN_MIN = 5; // [3:0.5:12]
// Bow thickness (mm) — two lines of a 0.4 mm nozzle
BOW_T = 0.9; // [0.4:0.05:2]
// Bow press (mm) — how far the bows' faces stand inside the cell at their middle, on diameter: more grips harder
BOW_PRESS = 1.0; // [0.1:0.05:2]
// Bore clearance (mm) — the hole round the bows, past the cell, on diameter: a plain hole this size is a bit loose
BORE_CLR = 0.8; // [0.2:0.1:2]
// Thinnest neck (mm) — the narrowest plastic between two neighbouring pockets: four lines
NECK_MIN = 1.6; // [0.8:0.1:4]
// Arm tip width (mm) — where an arm between two cells is cut: thinner won't print as a wall
ARM_TIP_W = 2; // [0.8:0.1:5]
// Spacer land clearance (mm) — the spacer's lands round each cell, on diameter: close enough to stop tilt, not to bind
SPACER_LAND_CLR = 0.2; // [0:0.05:1]

/* [Spacer] */
// Spacer height (mm) — its length along the cells: lands far apart, so it can't rock
SPACER_H = 18; // [6:1:60]

/* [View] */
// View — the spacer alone, with its four cells in place, or nothing (to check a design quickly)
VIEW = "part"; // [part, with_cells, none]

/* [Hidden] */
CELL_L = 0;             // the spacer doesn't depend on the cell's length

include <lib/grip.scad>

CELL_CENTRES = [for (sx = [-1, 1], sy = [-1, 1]) [sx * P / 2, sy * P / 2]];
NECK = neck(GAP_BOW_SPAN);
SPACER_LAND_D = CELL_FIT + SPACER_LAND_CLR;
ARM_R = arm_r(SPACER_LAND_D);
CORE_R = P / sqrt(2) - SPACER_LAND_D / 2;   // the centre of the gap to a land: its inscribed circle
assert(GAP_SPAN_MAX >= BOW_SPAN_MIN, str("the diagonal gap holds a bow of ", GAP_SPAN_MAX, " mm, under BOW_SPAN_MIN ",
    BOW_SPAN_MIN, ": widen CELL_GAP or PITCH"));
assert(GAP_BOW_SPAN >= BOW_SPAN_MIN, str("the bows are ", GAP_BOW_SPAN, " mm, under BOW_SPAN_MIN ", BOW_SPAN_MIN));
assert(NECK >= NECK_MIN - 1e-9, str("the core's necks are ", NECK, " mm"));
assert(ARM_R > CORE_R, "the arms reach past the core");
assert(BOW_FACE_D < SPACER_LAND_D, "the bows' faces must stand in past the lands");
assert(VIEW == "part" || VIEW == "with_cells" || VIEW == "none", "VIEW is part, with_cells or none");

module at_cell_faces() for (c = CELL_CENTRES) toward(c, [0, 0]) children();
module spacer_2d(land_d) difference() {
    circle(r = ARM_R);
    for (c = CELL_CENTRES) translate(c) circle(d = land_d);
    at_cell_faces() pocket_2d(GAP_BOW_SPAN);
}

module spacer() {
    // the lands and the plain middle; the chamfers stepped at the ends
    n_ch = ceil(CHAMFER / SLICE);
    linear_extrude(SPACER_H) spacer_2d(SPACER_LAND_D + 2 * CHAMFER);
    translate([0, 0, CHAMFER]) linear_extrude(SPACER_H - 2 * CHAMFER) spacer_2d(SPACER_LAND_D);
    for (i = [0:n_ch - 1], e = [0, 1]) let(z = i * CHAMFER / n_ch, d = SPACER_LAND_D + 2 * (CHAMFER - z))
        translate([0, 0, e == 0 ? z : SPACER_H - z - CHAMFER / n_ch]) linear_extrude(CHAMFER / n_ch + 0.01) spacer_2d(d);
    // the bows, contoured: furthest in at the middle, back toward the bore at both ends
    n = ceil(SPACER_H / SLICE);
    for (i = [0:n - 1]) let(z0 = i * SPACER_H / n, z1 = (i + 1) * SPACER_H / n)
        translate([0, 0, z0]) linear_extrude(z1 - z0 + 0.01) at_cell_faces() bow_2d(bow_face_d_at((z0 + z1) / 2, SPACER_H), GAP_BOW_SPAN);
}

module cell(h = 60) color("SteelBlue", 0.45) translate([0, 0, -h / 2 + SPACER_H / 2]) cylinder(d = CELL_FIT, h = h);

if (VIEW == "part") color("Orange") spacer();
if (VIEW == "with_cells") { color("Orange") spacer(); for (c = CELL_CENTRES) translate(c) cell(); }

echo(SPACER = [["cell", CELL], ["body_d", BODY_D], ["cell_fit", CELL_FIT], ["pitch", P], ["bow_span", GAP_BOW_SPAN],
    ["neck", NECK], ["across_arms", 2 * ARM_R], ["core_d", 2 * CORE_R], ["height", SPACER_H], ["land_d", SPACER_LAND_D],
    ["bow_past_land", (SPACER_LAND_D - BOW_FACE_D) / 2], ["tilt_deg_max", atan(SPACER_LAND_CLR / SPACER_H)]]);
