// SPDX-License-Identifier: CERN-OHL-S-2.0
// A vented frame for a block of cylindrical cells: an open-ended box an NC x NR grid of cells stands in, running
// their full length, open at both ends so the terminals and busbars stay clear. It holds the edge cells; gap spacers
// (spacer.scad) hold the cells inside. Its job besides holding them is not to trap their heat:
// - In a band near each end, every edge cell is gripped by bow springs (lib/grip.scad). The wall touches an edge cell
//   only at its bows and lands there.
// - Between the bands each wall's inner face is two sine waves added, one along the wall (plan, one crest per cell)
//   and one up the frame (section), out of phase, running unbroken round the frame. The wall is a sheet of the bands'
//   thickness whose outside mirrors the inside about a datum: where the inside comes in to a cell, the outside bows
//   out. Where the inner wave passes the datum the two faces meet and the wall opens: the openings are the wave's
//   own, their edges its face. Where both waves crest, at a cell's middle, the wall touches the cell; where both
//   trough, it opens. The section wave shifts half a period from cell to cell, so the openings alternate like brick
//   bond. With the cells lying on their sides, the troughs on the upright walls are channels the draft rises through.
//
// It prints standing, the cells' axis vertical, with no support: asserts hold both faces of the wave under 45 degrees,
// so the openings' edges are too, and each ridge of the upper band grows from the wall at 45 degrees between two G2
// eases. Every blend is G2 (curvature-continuous).
//
// Print the calibration coupon (coupon.scad) first: it finds FIT_OFFSET for your printer and cells (README).
//
//   openscad --backend=manifold -o frame.stl -D 'CELL="21700"' -D NC=5 -D NR=4 frame.scad

/* [Cell] */
CELL = "33140";         // a preset in lib/cells.scad, or "custom" with CELL_D and CELL_L
CELL_D = undef;         // mm, overrides the preset's body diameter
CELL_L = undef;         // mm, overrides the preset's body length, end face to end face
FIT_OFFSET = 0;         // mm, how much bigger the printed grip sees the cell than CELL_D: from the coupon (README)
CELL_GAP = 0.8;         // mm between neighbouring cells' bodies: 0.8, the printed bores just meet
PITCH = undef;          // mm, overrides CELL_D + CELL_GAP: usually the busbars set it

/* [Block] */
NC = 4;                 // cells across the block
NR = 6;                 // cells up the block
GRIP = "auto";          // auto | gap | wall: where the edge cells' bows sit (README, "Grip")
PRINT_MAX = 270;        // mm, the printer's build volume, its smallest side: 270 for a Snapmaker U1
VIEW = "part";          // part | inplace | top

include <lib/grip.scad>

/* [Frame inputs] */
END_CLR = 1;            // mm, the frame stops this far short of each end face, clear of the terminals and busbars
FRAME_LAND_CLR = 0.6;   // mm on diameter: the frame is long, so it can't tilt a cell; wider than a spacer's, so a block
                        // of cells slides in without binding along its length
RELIEF_CLR = 1.2;       // mm, in the bands the wall stands this far back from the edge cells: the bows grip there
WALL_T = 3.2;           // mm, the wall's thickness in the bands, eight lines; between them it swells and thins with the wave
SPACER_INSET = 1;       // mm from each end of the frame to its band of bows
BAND_H = 5;             // mm, a band of bows along the frame: short, to leave more of the frame to the wave
// The wall's inner face between the bands is two sine waves added: one along the wall (plan), one up the frame
// (section), out of phase. Equal weights make them the same size; unequal, a major and a minor wave.
PLAN_L = P;             // mm, the plan wave's length along the wall: one per cell, its crest at each cell's middle, so the
                        // columns between openings stay wide
PLAN_WEIGHT = 0.5;      // the plan wave's share of the face's travel; the section wave has the rest: an even share keeps
                        // both the columns and the ties between the openings wide
CONTACT_L = 25;         // mm, about how far apart the section wave's crests stand up the frame: lines of contact on each
                        // cell. The count follows from the wave's height, so a short cell gets fewer
SECTION_PHASE = 90;     // degrees, the section wave's phase against the plan wave's
INTRUDE = 1.0;          // mm, a crest reaches this far past the land; the land then trims it to the cell's curve, so a
                        // crest touches the cell over a patch, not a point
CHANNEL = 4.5;          // mm, a trough's clearance to the cell: the channel the draft rises through beside an edge cell
BIG_AMP = 4;            // mm, bumps on the outside where it is otherwise plain, in the bands and round the corners, out
                        // behind each cell's middle; they fade (G2) as the wave comes in
BIG_L = P;              // mm, their length along the wall: one bump per cell
REFLECT = 1;            // how far the outside mirrors the inside's wave about the datum: 1 a full mirror, 0 flat
PHASE_STEP = 1 / 2;     // of a section wave, its shift up the frame per cell along the wall: openings in neighbouring
                        // gaps alternate like brick bond, and round the frame it closes in whole periods
CORNER_S = P;           // mm of the section wave each corner takes, as if it were one more cell: about its arc's length,
                        // so the wave runs on round it at the walls' pace
CORNER_N = 90;          // steps round a corner
U_STEP = 1;             // mm, the wave's step along a wall
Z_STEP = 1;             // mm, its step up the frame
RAMP = 10;              // mm, over which the wave blends (G2) from the bands' relief: shorter, and its slope passes 45 degrees
TIE_MIN = 6;            // mm, the shortest tie across the wall between two openings one above the other
COLUMN_MIN = 12;        // mm, the narrowest column up the wall between two openings side by side
SLOPE_MAX = 1;          // the steepest a face may lean from vertical: tan 45 degrees
BOW_SLICE = 0.5;        // mm, the bows' step along the frame (the spacer uses SLICE; the frame has many more bows)

FRAME_L = BODY_L - 2 * END_CLR;
BANDS = [[SPACER_INSET, SPACER_INSET + BAND_H], [FRAME_L - SPACER_INSET - BAND_H, FRAME_L - SPACER_INSET]];
LAND_D_F = CELL_FIT + FRAME_LAND_CLR;
CREST = LAND_D_F / 2;                     // the wall's inner face, from an edge cell's axis: a contact line
RELIEF_R = CREST + RELIEF_CLR;
CREST_IN = CREST - INTRUDE;
TROUGH = CREST + CHANNEL;                 // the inner face at its trough, from the line through the edge cells' axes
BAND_OUT = RELIEF_R + WALL_T;             // the outside in the bands: the plain wall's face
// The datum: a line round the frame that the outside mirrors the inside about, REFLECT of the way. Where the inner
// wave passes the datum the two faces have met and the wall opens, its edges the wave's own. The datum sits so that
// in the bands, where the inside is plain, the wall is WALL_T thick.
DATUM = RELIEF_R + WALL_T / (1 + REFLECT);
OUT = DATUM + REFLECT * (DATUM - CREST_IN) + BIG_AMP;   // the outside at its farthest: the frame's size
SIZE = [(NC - 1) * P + 2 * OUT, (NR - 1) * P + 2 * OUT];

function cell_at(i, j) = [i * P, j * P];
// The gaps on the block's boundary, each with the cells round it that are in the block.
GAPS = [for (i = [0:NC], j = [0:NR]) if (i == 0 || j == 0 || i == NC || j == NR)
    [[(i - 0.5) * P, (j - 0.5) * P], [for (a = [i - 1, i], b = [j - 1, j]) if (a >= 0 && a < NC && b >= 0 && b < NR) cell_at(a, b)]]];
// The corners are round (below), so only the gaps between two edge cells hold ridges: the part of a gap spacer inside
// the block. A corner cell is held by the ridge on each of its walls and by the corner's shell.
RIDGE_GAPS = [for (g = GAPS) if (len(g[1]) == 2) g];
// Each edge cell's middle on each wall it stands on, with the wall's outward direction.
EDGE_MIDS = concat(
    [for (i = [0:NC - 1]) [cell_at(i, 0), [0, -1]]], [for (i = [0:NC - 1]) [cell_at(i, NR - 1), [0, 1]]],
    [for (j = [0:NR - 1]) [cell_at(0, j), [-1, 0]]], [for (j = [0:NR - 1]) [cell_at(NC - 1, j), [1, 0]]]);

// The grip. "gap": in each gap between two edge cells, a ridge holds a bow facing each of its cells, as the gap spacer
// does; the bow is as long as the gap allows, up to BOW_SPAN. "wall": the ridges are plain lands, and a pad on the
// wall in front of each edge cell's middle holds a bow of the full BOW_SPAN, the wall behind it, so no neck limits it.
// "auto" takes the gap where it holds a bow of at least BOW_SPAN_MIN.
GRIP_USED = GRIP == "auto" ? (GAP_SPAN >= BOW_SPAN_MIN ? "gap" : "wall") : GRIP;
GRIP_SPAN = GRIP_USED == "gap" ? SPAN_IN_GAP : BOW_SPAN;
// Each bow as [its cell, a point its pocket faces].
GRIPS = GRIP_USED == "gap" ? [for (g = RIDGE_GAPS, c = g[1]) [c, g[0]]] : [for (m = EDGE_MIDS) [m[0], m[0] + m[1]]];
N_BOWS = len(GRIPS);
PAD_FLANK = ROOT_EMBED + NECK_MIN;   // mm of a pad's side walls past its pocket: the roots' embed, then the neck

// How far a ridge reaches in from the bands' wall face: just past its bows' roots. A spacer's arm runs on into the gap
// between the cells to stop it spinning; a ridge is part of the wall and needs none of it.
RIDGE_MARGIN = 1.5;     // mm of ridge past the bows' roots
ROOT_R = BORE / 2 + BOW_ROOT;
GRIP_ANGLE = GRIP_USED == "gap" ? 45 : 0;   // the bows' pockets from the wall's outward direction
ROOT_DEPTH = RELIEF_R - ROOT_R * cos(GRIP_ANGLE + atan((GRIP_SPAN / 2 + ROOT_EMBED) / ROOT_R));
RIDGE_REACH = ROOT_DEPTH + RIDGE_MARGIN;
// Every blend is G2, curvature-continuous: smootherstep, 6t^5 - 15t^4 + 10t^3, whose slope and curvature are zero at
// both ends.
function blend(t) = let(u = max(0, min(1, t))) u * u * u * (u * (6 * u - 15) + 10);
// The upper band's ridges grow from the wall along a taper that climbs at 45 degrees between two eases: its slope
// rises from flat to 45 degrees over TAPER_EASE (a smoothstep, so the curvature is continuous), holds, and falls back
// to flat over the last TAPER_EASE. It is one ease longer than the ridges' reach; a smootherstep, steepest at 15/8 of
// its mean, would be 15/8 of it.
TAPER_EASE = 3;         // mm
TAPER_L = RIDGE_REACH / SLOPE_MAX + TAPER_EASE;
function ease_rise(x) = let(t = max(0, min(1, x / TAPER_EASE))) TAPER_EASE * SLOPE_MAX * (pow(t, 3) - pow(t, 4) / 2);
// how far in from the wall the taper has grown, x up it from its foot
function taper_d(x) = x <= TAPER_EASE ? ease_rise(x)
    : x >= TAPER_L - TAPER_EASE ? RIDGE_REACH - ease_rise(TAPER_L - x)
    : ease_rise(TAPER_EASE) + SLOPE_MAX * (x - TAPER_EASE);
// Above a band that ends short of the frame's top, its ridges blend back into the wall. They shrink going up, so the
// blend faces up and needs no 45 degree limit.
FADE_L = 6;

// The four walls, in order round the frame: where the line through their edge cells' axes starts, its turn from +x
// (the wall's outside is a quarter turn clockwise of it), its length, and how far round the frame the section wave
// has run where it starts: the walls before it and a corner before each.
WALLS = [[[0, 0], 0, (NC - 1) * P, 0],
         [[(NC - 1) * P, 0], 90, (NR - 1) * P, (NC - 1) * P + CORNER_S],
         [[(NC - 1) * P, (NR - 1) * P], 180, (NC - 1) * P, (NC + NR - 2) * P + 2 * CORNER_S],
         [[0, (NR - 1) * P], 270, (NR - 1) * P, (2 * NC + NR - 3) * P + 3 * CORNER_S]];
ROUND_S = 2 * (NC + NR - 2) * P + 4 * CORNER_S;   // the section wave's run round the frame

// Between the bands, clear of the ridges' blends in and out: where the wave runs.
OPEN_SPAN = len(BANDS) > 1 ? [BANDS[0][1] + FADE_L, BANDS[len(BANDS) - 1][0] - TAPER_L] : [0, 0];
// The section wave's crests up the frame, lines of contact on each cell: as many as the wave's height holds at about
// CONTACT_L apart, and at least one.
CONTACTS = max(1, round((OPEN_SPAN[1] - OPEN_SPAN[0]) / CONTACT_L));
function envelope(z) = OPEN_SPAN[1] - OPEN_SPAN[0] > 2 * RAMP
    ? min(blend((z - OPEN_SPAN[0]) / RAMP), blend((OPEN_SPAN[1] - z) / RAMP)) : 0;
// The face's travel: 0 is in at its crest, 1 out at its trough. The plan wave runs along each wall, u from its first
// cell's middle; the section wave runs on round the frame, s along the walls and the corners, and z up it.
function plan_wave(u) = 0.5 - 0.5 * cos(360 * u / PLAN_L);
function section_wave(s, z) = let(t = (z - OPEN_SPAN[0]) / (OPEN_SPAN[1] - OPEN_SPAN[0]))
    0.5 - 0.5 * cos(360 * (CONTACTS * t + PHASE_STEP * s / P) + SECTION_PHASE);
function wave(plan, s, z) = OPEN_SPAN[1] <= OPEN_SPAN[0] ? 0 : PLAN_WEIGHT * plan + (1 - PLAN_WEIGHT) * section_wave(s, z);
// The inner face, out from the line through the edge cells' axes: in the bands RELIEF_R; between them the wave.
function face_r(plan, s, z) = let(w = CREST_IN + (TROUGH - CREST_IN) * wave(plan, s, z)) RELIEF_R + envelope(z) * (w - RELIEF_R);
// The outside: the inside mirrored about the datum, REFLECT of the way. It is as smooth as the inside and leans
// REFLECT as steeply. Where the outside is otherwise plain (the bands), it bows out in bumps, one behind each cell
// (bump 1 behind its middle), fading as the wave comes in: the share of the wave not there.
function out_r(plan, bump, s, z) = DATUM + REFLECT * (DATUM - face_r(plan, s, z)) + BIG_AMP * (1 - envelope(z)) * bump;
function big_bump(u) = 0.5 + 0.5 * cos(360 * u / BIG_L);
function face_wall(w, u, z) = face_r(plan_wave(u), w[3] + u, z);
function face_out(w, u, z) = out_r(plan_wave(u), big_bump(u), w[3] + u, z);
// The corners curve round their corner cells: past the line through a corner cell's axis the frame's faces run round
// that cell's axis, both bumps at the crest they have at the cell's middle and the section wave running on through
// CORNER_S. A face's radius at a corner's ends is the wall's, and the wave runs along the arc at the pace it runs
// along the wall there, so each face meets each wall tangent to it: no crease. The walls' faces stop at their end
// cells and leave the corners to these faces; run on, the walls' troughs would cut the round shell.
// t runs 0 to 1 from the end of the wall before (its outside facing a0) to the start of the wall after.
function corner_s(w, t, r0, r1) = let(m0 = r0 * PI / 2 / CORNER_S, m1 = r1 * PI / 2 / CORNER_S)
    w[3] - CORNER_S + CORNER_S * (t + (m0 - 1) * (t - 2 * t * t + t * t * t) + (m1 - 1) * (t * t * t - t * t));
function corner_r(w, t, z, outside) = let(
    f = function(s) outside ? out_r(0, 1, s, z) : face_r(0, s, z),
    tt = max(0, min(1, t)))
    f(corner_s(w, tt, f(w[3] - CORNER_S), f(w[3])));
CORNER_T = [for (j = [-1:CORNER_N + 1]) j / CORNER_N];   // a step past each end, over the walls' own ground
GRID_Z = [for (k = [0:ceil(FRAME_L / Z_STEP)]) min(FRAME_L, k * Z_STEP)];
function grid_u(len) = [for (i = [0:ceil(len / U_STEP)]) min(len, i * U_STEP)];
// The steepest the faces lean from vertical, walls and corners: the print's overhang. The outside overhangs too where
// it leans out going up.
function steepest(outside) = max(concat(
    [for (w = WALLS, u = grid_u(w[2]), k = [0:len(GRID_Z) - 2]) let(f = function(z) outside ? face_out(w, u, z) : face_wall(w, u, z))
        abs(f(GRID_Z[k + 1]) - f(GRID_Z[k])) / (GRID_Z[k + 1] - GRID_Z[k])],
    [for (w = WALLS, t = CORNER_T, k = [0:len(GRID_Z) - 2])
        abs(corner_r(w, t, GRID_Z[k + 1], outside) - corner_r(w, t, GRID_Z[k], outside)) / (GRID_Z[k + 1] - GRID_Z[k])]));
STEEPEST = steepest(false);
STEEPEST_OUT = steepest(true);
// How much of the walls between the bands is open: where the inner wave passes the datum.
OPEN_FRACTION = OPEN_SPAN[1] <= OPEN_SPAN[0] ? 0 : let(zs = [for (z = GRID_Z) if (z > OPEN_SPAN[0] && z < OPEN_SPAN[1]) z],
    pts = [for (w = WALLS, u = grid_u(w[2])) if (u >= 0 && u <= w[2]) [w, u]])
    len([for (p = pts, z = zs) if (face_wall(p[0], p[1], z) > DATUM) 1]) / (len(pts) * len(zs));

// The ties: along each of the plan wave's trough lines on a wall, where the openings fall, the solid between two
// openings one above the other. Each run of solid that has an opening below and above it is a tie.
TIE_DZ = 0.25;
TIE_ZS = [for (k = [0:floor((OPEN_SPAN[1] - OPEN_SPAN[0]) / TIE_DZ)]) OPEN_SPAN[0] + k * TIE_DZ];
function opens(s) = [for (z = TIE_ZS) face_r(plan_wave(s), s, z) > DATUM];
function next_open(o, i) = i >= len(o) ? -1 : o[i] ? i : next_open(o, i + 1);
function ties(o) = [for (i = [1:len(o) - 1]) if (!o[i] && o[i - 1]) let(j = next_open(o, i)) if (j > 0) (j - i) * TIE_DZ];
ALL_TIES = OPEN_SPAN[1] <= OPEN_SPAN[0] ? [] : [for (k = [0:round(2 * P / PLAN_L) - 1], t = ties(opens((k + 0.5) * PLAN_L))) t];
TIE_SHORTEST = len(ALL_TIES) == 0 ? 0 : min(ALL_TIES);
// The columns: at each height where the wave is at full depth, across four cells of wall, the solid between two
// openings side by side.
COL_DS = 0.5;
COL_SS = [for (k = [0:floor(4 * P / COL_DS)]) k * COL_DS];
COL_ZS = [for (z = TIE_ZS) if (envelope(z) > 0.99) z];
function opens_across(z) = [for (sv = COL_SS) face_r(plan_wave(sv), sv, z) > DATUM];
ALL_COLUMNS = OPEN_SPAN[1] <= OPEN_SPAN[0] ? [] : [for (k = [0:2:len(COL_ZS) - 1], c = ties(opens_across(COL_ZS[k]))) c * COL_DS / TIE_DZ];
COLUMN_NARROWEST = len(ALL_COLUMNS) == 0 ? 0 : min(ALL_COLUMNS);

assert(NC >= 2 && NR >= 2, "the frame holds at least 2 x 2 cells");
assert(GRIP == "auto" || GRIP == "gap" || GRIP == "wall", "GRIP is auto, gap or wall");
assert(GRIP_USED != "gap" || GAP_SPAN >= BOW_SPAN_MIN, str("the gap between edge cells holds a bow of ", GAP_SPAN,
    " mm, under BOW_SPAN_MIN ", BOW_SPAN_MIN, ": use GRIP = \"wall\", or widen CELL_GAP or PITCH"));
assert(len(ALL_TIES) == 0 || TIE_SHORTEST >= TIE_MIN, str("the shortest tie between openings is ", TIE_SHORTEST, " mm"));
assert(len(ALL_COLUMNS) == 0 || COLUMN_NARROWEST >= COLUMN_MIN, str("the narrowest column between openings is ", COLUMN_NARROWEST, " mm"));
assert(TIP < LAND_D_F, "the bows must stand in past the frame's lands");
assert(max(SIZE[0], SIZE[1], FRAME_L) <= PRINT_MAX, str("the frame is ", SIZE, " x ", FRAME_L, ": bigger than the printer"));
for (b = BANDS) assert(b[0] >= 0 && b[1] <= FRAME_L, "a band of bows runs past the frame's ends");
assert(PLAN_WEIGHT >= 0 && PLAN_WEIGHT <= 1, "PLAN_WEIGHT is a share, 0 to 1");
assert(abs(PHASE_STEP * ROUND_S / P - round(PHASE_STEP * ROUND_S / P)) < 1e-6,
    "the section wave's shift doesn't close round the frame: it would meet itself out of step at a corner");
assert(min([for (w = WALLS, z = GRID_Z, o = [false, true]) corner_r(w, 0, z, o) * PI / 2 / CORNER_S]) > 0
    && max([for (w = WALLS, z = GRID_Z, o = [false, true]) corner_r(w, 0, z, o) * PI / 2 / CORNER_S]) < 3,
    "a corner's arc is so far from CORNER_S long that the wave would run back on itself round it");
assert(len(BANDS) < 2 || OPEN_SPAN[1] - OPEN_SPAN[0] > 2 * RAMP, str("the frame is too short for its wave: ",
    OPEN_SPAN[1] - OPEN_SPAN[0], " mm between the bands' blends, under the ", 2 * RAMP, " its ramps take"));
assert(STEEPEST <= SLOPE_MAX, str("the wave leans ", atan(STEEPEST), " degrees: past 45 it would need support"));
assert(CREST_IN > P / 2 - ARM_TIP_W, "a crest reaches so far in it closes the gap between two cells");
assert(STEEPEST_OUT <= SLOPE_MAX, str("the outside leans ", atan(STEEPEST_OUT), " degrees: past 45 it would need support"));
assert(TROUGH > DATUM, "the wave never passes the datum: the wall never opens");
assert(REFLECT >= 0 && REFLECT <= 1, "REFLECT is a share, 0 to 1");
assert(abs(P / PLAN_L - round(P / PLAN_L)) < 1e-6, "PLAN_L must divide the pitch, so every cell's middle is a crest");

module outer_2d() translate([-OUT - 1, -OUT - 1]) square(SIZE + [2, 2]);   // just past the walls' own faces
// The cells' outline at distance r out from the lines through the edge cells' axes.
module inner_2d(r) translate([-r, -r]) square([(NC - 1) * P + 2 * r, (NR - 1) * P + 2 * r]);
// A pad in front of an edge cell's middle, in the cell's frame toward the wall: from inside the land (the land trims
// it) into the wall.
module pad_2d() translate([CREST - 1, -GRIP_SPAN / 2 - PAD_FLANK]) square([RELIEF_R - CREST + 2, GRIP_SPAN + 2 * PAD_FLANK]);
module ridges_2d() intersection() {
    inner_2d(BAND_OUT);
    difference() { inner_2d(BAND_OUT); offset(delta = -RIDGE_REACH) inner_2d(RELIEF_R); }
    corners_2d(BAND_OUT);
    union() {
        for (g = RIDGE_GAPS) translate(g[0]) circle(r = ARM_R);
        if (GRIP_USED == "wall") for (gr = GRIPS) toward(gr[0], gr[1]) pad_2d();
    }
}
// The ridges d in from the bands' wall face: a ridge growing from the wall, or shrinking back into it.
module ridges_within_2d(d) difference() { ridges_2d(); offset(delta = -d) inner_2d(RELIEF_R); }
module pockets_2d() for (gr = GRIPS) toward(gr[0], gr[1]) pocket_2d(GRIP_SPAN);

function band_at(z) = [for (b = BANDS) if (z >= b[0] && z <= b[1]) b];
function tip_frame(z) = let(b = band_at(z)) len(b) == 0 ? BORE : tip_in_band(z - b[0][0], b[0][1] - b[0][0]);
module bows_2d(tip) for (gr = GRIPS) toward(gr[0], gr[1]) bow_2d(tip, GRIP_SPAN);

// The space inside one wall's inside face, or its outside face: in the wall's own frame (u along it, the outside
// towards -y), everything from the face in to FAR. Past the wall's ends, over the corners, it bounds nothing: the
// corners' own faces do (corners()).
FAR = max(SIZE[0], SIZE[1]) + 10;

// A wall starts at each corner cell (WALLS[k][0]), and its u = 0 is that cell's middle; the corner before it is a
// quarter turn about that cell's axis, from the outside of the wall before (a0) to its own.
module plus_2d() {   // the frame clear of the four corner quadrants
    translate([0, -FAR]) square([(NC - 1) * P, 2 * FAR + (NR - 1) * P]);
    translate([-FAR, 0]) square([2 * FAR + (NC - 1) * P, (NR - 1) * P]);
}
module corners_2d(r) union() { plus_2d(); for (w = WALLS) translate(w[0]) circle(r = r); }
// The solid inside a corner's face: from the corner cell's axis out to the face, over the quarter turn and a step past
// each end, where the frame is the walls' (plus_2d) anyway. Faces are listed anticlockwise from outside, then
// reversed: OpenSCAD wants them clockwise.
module corner(w, outside) let(nt = len(CORNER_T), nz = len(GRID_Z), a0 = w[1] - 180,
    zz = function(k) k == 0 ? -0.01 : k == nz - 1 ? FRAME_L + 0.01 : GRID_Z[k],
    f = function(j, k) j + k * nt, ax = function(k) nt * nz + k)
    translate(w[0]) polyhedron(
        points = concat([for (k = [0:nz - 1], t = CORNER_T) let(r = corner_r(w, t, GRID_Z[k], outside), a = a0 + 90 * t)
                [r * cos(a), r * sin(a), zz(k)]],
            [for (k = [0:nz - 1]) [0, 0, zz(k)]]),
        faces = [for (q = concat(
            [for (k = [0:nz - 2], j = [0:nt - 2]) [f(j, k), f(j + 1, k), f(j + 1, k + 1), f(j, k + 1)]],
            [for (k = [0:nz - 2]) [ax(k), f(0, k), f(0, k + 1), ax(k + 1)]],
            [for (k = [0:nz - 2]) [f(nt - 1, k), ax(k), ax(k + 1), f(nt - 1, k + 1)]],
            [concat([ax(0)], [for (j = [nt - 1:-1:0]) f(j, 0)])],
            [concat([ax(nz - 1)], [for (j = [0:nt - 1]) f(j, nz - 1)])])) [for (i = [len(q) - 1:-1:0]) q[i]]]);
module corners(outside) union() {
    translate([0, 0, -1]) linear_extrude(FRAME_L + 2) plus_2d();
    for (w = WALLS) corner(w, outside);
}
module inside_wall(w, outside = false) let(len = w[2], us = concat([-FAR], grid_u(len), [len + FAR]), nu = len(us), nz = len(GRID_Z),
    zz = function(k) k == 0 ? -0.01 : k == nz - 1 ? FRAME_L + 0.01 : GRID_Z[k],
    f = function(i, k) i + k * nu, b0 = function(k) nu * nz + k, b1 = function(k) nu * nz + nz + k)
    translate(w[0]) rotate(w[1]) polyhedron(
        points = concat([for (k = [0:nz - 1], i = [0:nu - 1]) [us[i], i == 0 || i == nu - 1 ? -FAR
                : outside ? -face_out(w, us[i], GRID_Z[k]) : -face_wall(w, us[i], GRID_Z[k]), zz(k)]],
            [for (k = [0:nz - 1]) [us[0], FAR, zz(k)]], [for (k = [0:nz - 1]) [us[nu - 1], FAR, zz(k)]]),
        faces = concat(
            [for (k = [0:nz - 2], i = [0:nu - 2]) [f(i, k + 1), f(i + 1, k + 1), f(i + 1, k), f(i, k)]],
            [for (k = [0:nz - 2]) [b1(k + 1), b0(k + 1), b0(k), b1(k)]],
            [for (k = [0:nz - 2]) [b0(k + 1), f(0, k + 1), f(0, k), b0(k)]],
            [for (k = [0:nz - 2]) [f(nu - 1, k + 1), b1(k + 1), b1(k), f(nu - 1, k)]],
            [concat([for (i = [0:nu - 1]) f(i, 0)], [b1(0), b0(0)])],
            [concat([b0(nz - 1), b1(nz - 1)], [for (i = [nu - 1:-1:0]) f(i, nz - 1)])]));

// The cells, at their land, with a 45 degree lead-in at both ends.
module cells_cut() for (i = [0:NC - 1], j = [0:NR - 1]) translate(cell_at(i, j)) {
    translate([0, 0, -0.01]) cylinder(d = LAND_D_F, h = FRAME_L + 0.02);
    translate([0, 0, -0.01]) cylinder(d1 = LAND_D_F + 2 * CHAMFER + 0.02, d2 = LAND_D_F, h = CHAMFER + 0.01);
    translate([0, 0, FRAME_L - CHAMFER]) cylinder(d1 = LAND_D_F, d2 = LAND_D_F + 2 * CHAMFER + 0.02, h = CHAMFER + 0.01);
}

// Each band's ridges run out to the frame's end beyond it; toward the middle they blend into the wall: a band above
// the bed starts its ridges in a taper, a band below the top ends them in a fade. The pockets open from the band's
// start to its far end, so each pocket has solid ridge or the bed under it, and a bow starts on its floor.
function first_band(k) = k == 0;
function last_band(k) = k == len(BANDS) - 1;
function ridge_span(k) = [first_band(k) ? 0 : BANDS[k][0], last_band(k) ? FRAME_L : BANDS[k][1]];
function pocket_span(k) = [BANDS[k][0], last_band(k) ? FRAME_L : BANDS[k][1] + FADE_L];

module frame() union() {
    difference() {
        union() {
            // the sheet: inside every wall's outside face, and outside every wall's inside face
            difference() {
                intersection() {
                    linear_extrude(FRAME_L) outer_2d();
                    intersection_for (w = WALLS) inside_wall(w, true);
                    corners(true);
                }
                intersection() {
                    intersection_for (w = WALLS) inside_wall(w);
                    corners(false);
                }
            }
            for (k = [0:len(BANDS) - 1]) let(r = ridge_span(k), q = pocket_span(k)) {
                difference() {
                    translate([0, 0, r[0]]) linear_extrude(r[1] - r[0]) ridges_2d();
                    translate([0, 0, q[0]]) linear_extrude(q[1] - q[0] + 0.02) pockets_2d();
                }
                // a band that ends short of the top blends its ridges back into the wall
                if (!last_band(k)) let(n = ceil(FADE_L / SLICE)) for (i = [0:n - 1])
                    let(z = r[1] + i * FADE_L / n, d = RIDGE_REACH * (1 - blend((i + 1) / n)))
                    if (d > 0.05) difference() {
                        translate([0, 0, z]) linear_extrude(FADE_L / n + 0.01) ridges_within_2d(d);
                        translate([0, 0, z - 0.01]) linear_extrude(FADE_L / n + 0.03) pockets_2d();
                    }
                if (!first_band(k)) let(n = ceil(TAPER_L / SLICE)) for (i = [0:n - 1])
                    let(z = r[0] - TAPER_L + i * TAPER_L / n)
                    translate([0, 0, z]) linear_extrude(TAPER_L / n + 0.01) ridges_within_2d(taper_d((i + 1) * TAPER_L / n) + 0.01);
            }
        }
        cells_cut();
    }
    // the bows, contoured along each band
    for (b = BANDS) let(n = ceil((b[1] - b[0]) / BOW_SLICE)) for (k = [0:n - 1])
        let(z0 = b[0] + k * (b[1] - b[0]) / n, z1 = b[0] + (k + 1) * (b[1] - b[0]) / n)
        translate([0, 0, z0]) linear_extrude(z1 - z0 + 0.01) bows_2d(tip_frame((z0 + z1) / 2));
}

module cells() for (i = [0:NC - 1], j = [0:NR - 1]) translate(cell_at(i, j))
    color("SteelBlue", 0.45) translate([0, 0, -END_CLR]) cylinder(d = CELL_FIT, h = BODY_L);

if (VIEW == "part") color("Orange") frame();
if (VIEW == "inplace") { color("Orange") frame(); cells(); }
if (VIEW == "top") { color("Orange") frame(); for (i = [0:NC - 1], j = [0:NR - 1]) translate(cell_at(i, j))
    color("SteelBlue", 0.45) cylinder(d = CELL_FIT, h = FRAME_L + 1); }

echo(FRAME = [["cell", CELL], ["body", [BODY_D, BODY_L]], ["cell_fit", CELL_FIT], ["pitch", P], ["cells", [NC, NR]],
    ["size", SIZE], ["length", FRAME_L], ["land_d", LAND_D_F], ["grip", GRIP_USED], ["bow_span", GRIP_SPAN],
    ["gap_span", GAP_SPAN], ["bows", N_BOWS], ["bands", BANDS], ["taper_l", TAPER_L],
    ["contacts", len(BANDS) > 1 ? CONTACTS : 0], ["plan_weight", PLAN_WEIGHT], ["wall_t", WALL_T], ["channel", CHANNEL],
    ["steepest_deg", atan(STEEPEST)], ["steepest_out_deg", atan(STEEPEST_OUT)], ["big_amp", BIG_AMP],
    ["open_fraction", OPEN_FRACTION], ["tie_shortest", TIE_SHORTEST], ["column_narrowest", COLUMN_NARROWEST],
    ["bow_stands_past_land", (LAND_D_F - TIP) / 2]]);
