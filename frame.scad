// SPDX-License-Identifier: CERN-OHL-S-2.0
// A vented frame for a block of cylindrical cells: an open-ended box a grid of cells stands in, running their full
// length, open at both ends so the terminals and busbars stay clear. It holds the edge cells; gap spacers
// (spacer.scad) hold the cells inside. Its job besides holding them is not to trap their heat:
// - In a band near each end, every edge cell is gripped by bow springs (lib/grip.scad). The wall touches an edge cell
//   only at its bows and lands there.
// - Between the bands each wall's inside face is two sine waves added, one along the wall (a crest at each cell's
//   middle) and one up the frame, running unbroken round the frame. The wall is a sheet of the bands' thickness whose
//   outside mirrors the inside about a datum: where the inside comes in to a cell, the outside bows out. Where the
//   two faces meet the wall opens: the vents are the wave's own, their edges its faces. Where both waves crest, at a
//   cell's middle, the wall touches the cell. The wave up the frame can shift from cell to cell, so the vents
//   stagger like brick bond. With the cells lying on their sides, the troughs on the upright walls are channels the
//   draft rises through.
//
// It prints standing, the cells' axis vertical, with no support. Asserts hold both faces of the wave under 45
// degrees, and every vent's top narrow enough to bridge; each ridge of the upper band grows from the wall at 45
// degrees between two eases. Every blend is G2 (curvature-continuous).
//
// PART = "coupon" draws the calibration coupon instead: a 2 x 2 corner of the frame, one band deep, with its fit
// offset cut into a tab. Print a few at different offsets first (README).
//
//   openscad --backend=manifold -o frame.stl -D 'CELL="21700"' -D CELL_COLUMNS=5 -D CELL_ROWS=4 frame.scad
//   openscad --backend=manifold -o coupon.stl -D 'PART="coupon"' -D 'CELL="21700"' -D FIT_OFFSET=0.1 frame.scad

/* [Part] */
// Part — the frame, or a calibration coupon: a 2 × 2 corner of the frame, one band deep, its fit offset on a tab
PART = "frame"; // [frame, coupon]

/* [Cell] */
// Cell — a preset, or "custom" with its diameter and length below
CELL = "21700"; // [18650, 21700, 26650, 32650, 32700, 33140, 40135, 4680, 66160, custom]
// Diameter (mm) — the cell's body; 0 takes the preset's
CELL_D = 0; // [0:0.1:100]
// Length (mm) — the cell's body, end face to end face; 0 takes the preset's
CELL_L = 0; // [0:0.5:300]
// Fit offset (mm) — added to the cell's diameter where the grip is drawn: positive if your coupons were tight, negative if loose
FIT_OFFSET = 0; // [-1:0.05:1]
// Gap between cells (mm) — between neighbouring cells' bodies; at 0.8 the printed holes round neighbouring cells just meet
CELL_GAP = 0.8; // [0:0.1:10]
// Pitch (mm) — centre to centre, overriding diameter + gap: set it when your busbars or nickel strip fix it; 0 to leave it
PITCH = 0; // [0:0.1:120]

/* [Block] */
// Cell columns — cells across the block
CELL_COLUMNS = 4; // [2:1:20]
// Cell rows — cells deep
CELL_ROWS = 6; // [2:1:20]
// Printer size (mm) — the build volume's smallest side, which every side of the part must fit: 270 for a Snapmaker U1
PRINTER_SIZE = 270; // [100:1:1000]

/* [Vents] */
// The wall between the bands is two sine waves added, one along the wall and one up the frame; it opens where its two
// faces meet. The asserts hold every setting printable (Vent limits).
// Waves per cell — along the wall: 1 puts a crest at each cell's middle and a vent by each gap between cells
WAVES_PER_CELL = 1; // [1, 2, 3]
// Along share — the along-the-wall wave's share of the depth: 0.5 round vents; toward 0.7 tall slots; under 0.35 thin columns
ALONG_SHARE = 0.5; // [0:0.05:1]
// Wave spacing (mm) — how far apart the waves up the frame stand, rounded to fit: shorter, more and smaller vents
UP_WAVELENGTH = 25; // [10:1:80]
// Wave phase (degrees) — where the waves up the frame fall: 90 sets the contact lines evenly between the bands, 0 the vents
UP_PHASE = 90; // [0:15:180]
// Stagger — each cell's shift of the waves up the frame, in waves: 0.5 staggers the vents like brick; 0 lines them up in rows
STAGGER = 0.5; // [0, 0.25, 0.5]
// Trough depth (mm) — how far the wall stands off the cells between contacts: deeper, bigger vents and air channels
TROUGH_DEPTH = 4.5; // [1:0.1:10]
// Crest press (mm) — how far the crests reach past the cells' land, on radius; the land trims them, leaving the contact patches
CREST_PRESS = 1.0; // [0:0.1:3]
// Mirror — how far the outside follows the inside's wave, 0 to 1: 1 fully, opening the most; less, a thicker wall, smaller vents
MIRROR = 1; // [0:0.05:1]

/* [Grip] */
// Grip — where the edge cells' bow springs sit: auto takes the gap between edge cells where a bow fits, else the wall
GRIP = "auto"; // [auto, gap, wall]
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
// Frame land clearance (mm) — the frame round each cell, on diameter: a block of cells slides in without binding
FRAME_LAND_CLR = 0.6; // [0:0.05:2]

/* [Vent limits] */
// Shortest tie (mm) — the solid across the wall between two vents one above the other; columns are never narrower either
TIE_MIN = 6; // [2:0.5:30]
// Narrowest column (share) — the solid between two vents side by side, as a share of the along-the-wall wavelength
COLUMN_MIN_SHARE = 0.35; // [0:0.01:1]
// Least open (share) — the share of the wall between the bands that must open: less, and the vents are slivers
OPEN_SHARE_MIN = 0.1; // [0:0.01:0.5]
// Widest vent top (mm) — a vent's width 1 mm below its top, which the printer has to bridge: keep it to what yours bridges cleanly
BRIDGE_MAX = 10; // [2:0.5:30]

/* [Frame details] */
// Wall thickness (mm) — in the bands of bows: eight lines
WALL_T = 3.2; // [1.2:0.1:8]
// Bump depth (mm) — the bumps on the outside behind each cell, where the wall is otherwise plain
BUMP_DEPTH = 4; // [0:0.5:10]
// Band height (mm) — each band of bows near the ends: short, to leave more of the frame to the vents
BAND_H = 5; // [2:0.5:30]
// End clearance (mm) — the frame stops this far short of each end of the cells, clear of terminals and busbars
END_CLR = 1; // [0:0.5:20]

/* [View] */
// View — the part alone, with the cells in place, or nothing (to check a design quickly)
VIEW = "part"; // [part, with_cells, none]

include <lib/grip.scad>

/* [Hidden] */
COUPON = PART == "coupon";
// The coupon is a 2 x 2 corner whatever the block, so these follow from PART, not from -D.
N_ACROSS = COUPON ? 2 : CELL_COLUMNS;
N_DEEP = COUPON ? 2 : CELL_ROWS;
RELIEF_CLR = 1.2;       // mm, in the bands the wall stands this far back from the edge cells: the bows grip there
BAND_INSET = 1;         // mm from each end of the frame to its band of bows
RIDGE_LAND_CLR = 0.2;   // mm on diameter: the ridges are cut as a spacer's arms are, at a spacer's lands, as tested
// The wall's inside face between the bands is two sine waves added: one along the wall, one up the frame. Equal
// shares make them the same size; unequal, a major and a minor wave.
ALONG_WAVELENGTH = P / WAVES_PER_CELL;   // a whole number per cell, so a crest stands at every cell's middle
// The pattern along the walls repeats once the wave up the frame's shift from cell to cell comes round whole.
REPEAT_CELLS = STAGGER == 0 ? 1 : round(1 / STAGGER);
REPEAT_L = REPEAT_CELLS * P;
COLUMN_MIN = max(TIE_MIN, COLUMN_MIN_SHARE * ALONG_WAVELENGTH);   // mm
CORNER_S = P;           // mm of the wave up the frame each corner takes, as if it were one more cell: about its arc's
                        // length, so the wave runs on round it at the walls' pace
CORNER_N = 90;          // steps round a corner
U_STEP = 1;             // mm, the faces' step along a wall
Z_STEP = 1;             // mm, their step up the frame
RAMP = 10;              // mm, over which the wave blends (G2) from the bands' relief: shorter, and its slope passes 45 degrees
SLOPE_MAX = 1;          // the steepest a face may lean from vertical: tan 45 degrees
BOW_SLICE = 0.5;        // mm, the bows' step along the frame (the spacer uses SLICE; the frame has many more bows)
FULL_DEPTH = 0.99;      // of the wave's blend: where it counts as at full depth, for the columns
// The vents' grid: the wall's thickness sampled this finely over one repeat along it and the frame's height.
GRID_DS = 0.5;          // mm along
GRID_DZ = 0.5;          // mm up
ROOF_H = 1;             // mm below a vent's top where its width is the bridge the printer spans
TIE_DZ = 0.25;          // mm, the ties' step up the frame, along the trough lines
MAP_STEP = 2;           // the wall map takes every MAP_STEP-th point of the grid each way

assert(COUPON || is_num(BODY_L), "a custom cell needs its length, CELL_L");
FRAME_H = COUPON ? BAND_INSET + BAND_H + 1 : BODY_L - 2 * END_CLR;   // the coupon: its band, and 1 mm over it
BANDS = COUPON ? [[BAND_INSET, BAND_INSET + BAND_H]]
    : [[BAND_INSET, BAND_INSET + BAND_H], [FRAME_H - BAND_INSET - BAND_H, FRAME_H - BAND_INSET]];
FRAME_LAND_D = CELL_FIT + FRAME_LAND_CLR;
// Radii, out from the line through the edge cells' axes.
LAND_R = FRAME_LAND_D / 2;                // the frame's land
RELIEF_R = LAND_R + RELIEF_CLR;           // the inside face in the bands
CREST_R = LAND_R - CREST_PRESS;           // the inside face at the wave's crests, before the land trims it
TROUGH_R = LAND_R + TROUGH_DEPTH;         // the inside face at its troughs
BAND_OUT_R = RELIEF_R + WALL_T;           // the outside in the bands, bumps aside
// The datum: a line round the frame that the outside mirrors the inside about, MIRROR of the way. The datum sits so
// that in the bands, where the inside is plain, the wall is WALL_T thick.
DATUM_R = RELIEF_R + WALL_T / (1 + MIRROR);

function cell_at(i, j) = [i * P, j * P];
// The gaps on the block's boundary, each with the cells round it that are in the block.
GAPS = [for (i = [0:N_ACROSS], j = [0:N_DEEP]) if (i == 0 || j == 0 || i == N_ACROSS || j == N_DEEP)
    [[(i - 0.5) * P, (j - 0.5) * P], [for (a = [i - 1, i], b = [j - 1, j]) if (a >= 0 && a < N_ACROSS && b >= 0 && b < N_DEEP) cell_at(a, b)]]];
// The corners are round (below), so only the gaps between two edge cells hold ridges: the part of a gap spacer inside
// the block. A corner cell is held by the ridge on each of its walls and by the corner's shell.
RIDGE_GAPS = [for (g = GAPS) if (len(g[1]) == 2) g];
// Each edge cell's middle on each wall it stands on, with the wall's outward direction.
EDGE_MIDS = concat(
    [for (i = [0:N_ACROSS - 1]) [cell_at(i, 0), [0, -1]]], [for (i = [0:N_ACROSS - 1]) [cell_at(i, N_DEEP - 1), [0, 1]]],
    [for (j = [0:N_DEEP - 1]) [cell_at(0, j), [-1, 0]]], [for (j = [0:N_DEEP - 1]) [cell_at(N_ACROSS - 1, j), [1, 0]]]);

// The grip. "gap": in each gap between two edge cells, a ridge holds a bow facing each of its cells, as the gap spacer
// does; the bow is as long as the gap allows, up to BOW_SPAN. "wall": the ridges are plain lands, and a pad on the
// wall in front of each edge cell's middle holds a bow of the full BOW_SPAN, the wall behind it, so no neck limits it.
// "auto" takes the gap where, at the cell's nominal size, it holds a bow of at least BOW_SPAN_MIN.
GRIP_USED = GRIP == "auto" ? (GAP_SPAN_NOMINAL >= BOW_SPAN_MIN ? "gap" : "wall") : GRIP;
DRAWN_SPAN = GRIP_USED == "gap" ? GAP_BOW_SPAN : BOW_SPAN;
// Each bow as [its cell, a point its pocket faces]. A band draws each of them.
BOWS = GRIP_USED == "gap" ? [for (g = RIDGE_GAPS, c = g[1]) [c, g[0]]] : [for (m = EDGE_MIDS) [m[0], m[0] + m[1]]];
PAD_FLANK = ROOT_EMBED + NECK_MIN;   // mm of a pad's side walls past its pocket: the roots' embed, then the neck
POCKET_BACK_R = BORE / 2 + POCKET_DEPTH;   // a pocket's back, out from its cell's axis

// How far a ridge reaches in from the bands' wall face: just past its bows' roots. A spacer's arm runs on into the gap
// between the cells to stop it spinning; a ridge is part of the wall and needs none of it.
RIDGE_MARGIN = 1.5;     // mm of ridge past the bows' roots
ROOT_R = BORE / 2 + BOW_ROOT;
GRIP_ANGLE = GRIP_USED == "gap" ? 45 : 0;   // the bows' pockets from the wall's outward direction
ROOT_DEPTH = RELIEF_R - ROOT_R * cos(GRIP_ANGLE + atan((DRAWN_SPAN / 2 + ROOT_EMBED) / ROOT_R));
RIDGE_REACH = ROOT_DEPTH + RIDGE_MARGIN;
// Every blend is G2, curvature-continuous: smootherstep, 6t^5 - 15t^4 + 10t^3, whose slope and curvature are zero at
// both ends.
function blend(t) = let(u = max(0, min(1, t))) u * u * u * (u * (6 * u - 15) + 10);
// The upper band's ridges grow from the wall along a taper that climbs at 45 degrees between two eases: its slope
// rises from flat to 45 degrees over the ease (a smoothstep, so the curvature is continuous), holds, and falls back
// to flat over the last ease. Each ease climbs half its length, so the two together climb one ease: a ridge that
// reaches less than that takes shorter eases.
TAPER_EASE = min(3, RIDGE_REACH);   // mm
TAPER_H = RIDGE_REACH / SLOPE_MAX + TAPER_EASE;
function ease_rise(x) = let(t = max(0, min(1, x / TAPER_EASE))) TAPER_EASE * SLOPE_MAX * (pow(t, 3) - pow(t, 4) / 2);
// how far in from the wall the taper has grown, x up it from its foot
function taper_d(x) = x <= TAPER_EASE ? ease_rise(x)
    : x >= TAPER_H - TAPER_EASE ? RIDGE_REACH - ease_rise(TAPER_H - x)
    : ease_rise(TAPER_EASE) + SLOPE_MAX * (x - TAPER_EASE);
// Above a band that ends short of the frame's top, its ridges blend back into the wall. They shrink going up, so the
// blend faces up and needs no 45 degree limit.
FADE_H = 6;

// The four walls, in order round the frame: where the line through their edge cells' axes starts, its turn from +x
// (the wall's outside is a quarter turn clockwise of it), its length, and how far round the frame the wave up it has
// run where it starts: the walls before it and a corner before each.
WALLS = [[[0, 0], 0, (N_ACROSS - 1) * P, 0],
         [[(N_ACROSS - 1) * P, 0], 90, (N_DEEP - 1) * P, (N_ACROSS - 1) * P + CORNER_S],
         [[(N_ACROSS - 1) * P, (N_DEEP - 1) * P], 180, (N_ACROSS - 1) * P, (N_ACROSS + N_DEEP - 2) * P + 2 * CORNER_S],
         [[0, (N_DEEP - 1) * P], 270, (N_DEEP - 1) * P, (2 * N_ACROSS + N_DEEP - 3) * P + 3 * CORNER_S]];
ROUND_S = 2 * (N_ACROSS + N_DEEP - 2) * P + 4 * CORNER_S;   // the wave's run round the frame

// Between the bands, clear of the ridges' blends in and out: where the wave runs. The coupon has none.
WAVE_SPAN = len(BANDS) > 1 ? [BANDS[0][1] + FADE_H, BANDS[len(BANDS) - 1][0] - TAPER_H] : [0, 0];
HAS_WAVE = WAVE_SPAN[1] > WAVE_SPAN[0];
// The waves up the frame between the bands: as many as the span holds at about UP_WAVELENGTH apart, at least one.
UP_WAVES = HAS_WAVE ? max(1, round((WAVE_SPAN[1] - WAVE_SPAN[0]) / UP_WAVELENGTH)) : 0;
function envelope(z) = WAVE_SPAN[1] - WAVE_SPAN[0] > 2 * RAMP
    ? min(blend((z - WAVE_SPAN[0]) / RAMP), blend((WAVE_SPAN[1] - z) / RAMP)) : 0;
// The face's travel: 0 is in at its crest, 1 out at its trough. The wave along the wall runs u from its first cell's
// middle; the wave up the frame runs on round it, s along the walls and the corners, and z up it.
function along_wave(u) = 0.5 - 0.5 * cos(360 * u / ALONG_WAVELENGTH);
function up_wave(s, z) = let(t = (z - WAVE_SPAN[0]) / (WAVE_SPAN[1] - WAVE_SPAN[0]))
    0.5 - 0.5 * cos(360 * (UP_WAVES * t + STAGGER * s / P) + UP_PHASE);
function wave(along, s, z) = HAS_WAVE ? ALONG_SHARE * along + (1 - ALONG_SHARE) * up_wave(s, z) : 0;
// The inside face: in the bands RELIEF_R; between them the wave.
function inside_r(along, s, z) = let(w = CREST_R + (TROUGH_R - CREST_R) * wave(along, s, z)) RELIEF_R + envelope(z) * (w - RELIEF_R);
// The outside: the inside mirrored about the datum, MIRROR of the way. It is as smooth as the inside and leans
// MIRROR as steeply. Where the outside is otherwise plain (the bands), it bows out in bumps, one behind each cell
// (bump 1 behind its middle), fading as the wave comes in: the share of the wave not there.
function outside_r(along, bump, s, z) = DATUM_R + MIRROR * (DATUM_R - inside_r(along, s, z)) + BUMP_DEPTH * (1 - envelope(z)) * bump;
function bump(u) = 0.5 + 0.5 * cos(360 * u / P);
function wall_inside_r(w, u, z) = inside_r(along_wave(u), w[3] + u, z);
function wall_outside_r(w, u, z) = outside_r(along_wave(u), bump(u), w[3] + u, z);
// A wall's thickness at s along the pattern and z up it, both faces from one sample of the inside: 0 or less is a vent.
function wall_t_at(s, z) = let(i = inside_r(along_wave(s), s, z))
    (1 + MIRROR) * (DATUM_R - i) + BUMP_DEPTH * (1 - envelope(z)) * bump(s);
// The corners curve round their corner cells: past the line through a corner cell's axis the frame's faces run round
// that cell's axis, both bumps at the crest they have at the cell's middle and the wave running on through CORNER_S.
// A face's radius at a corner's ends is the wall's, and the wave runs along the arc at the pace it runs along the
// wall there, so each face meets each wall tangent to it: no crease. The walls' faces stop at their end cells and
// leave the corners to these faces; run on, the walls' troughs would cut the round shell.
// t runs 0 to 1 from the end of the wall before (its outside facing a0) to the start of the wall after.
function corner_s(w, t, r0, r1) = let(m0 = r0 * PI / 2 / CORNER_S, m1 = r1 * PI / 2 / CORNER_S)
    w[3] - CORNER_S + CORNER_S * (t + (m0 - 1) * (t - 2 * t * t + t * t * t) + (m1 - 1) * (t * t * t - t * t));
CORNER_T = [for (j = [-1:CORNER_N + 1]) j / CORNER_N];   // a step past each end, over the walls' own ground
GRID_Z = [for (k = [0:ceil(FRAME_H / Z_STEP)]) min(FRAME_H, k * Z_STEP)];
// Each corner's face, worked out once for the checks and the polyhedron: CORNER_FACES[outside][wall][k][j] is its
// radius at GRID_Z[k] and CORNER_T[j]. The radii at its two ends depend on z only.
CORNER_FACES = [for (outside = [false, true]) [for (w = WALLS) [for (z = GRID_Z) let(
    f = function(s) outside ? outside_r(0, 1, s, z) : inside_r(0, s, z),
    r0 = f(w[3] - CORNER_S), r1 = f(w[3]))
    [for (t = CORNER_T) f(corner_s(w, max(0, min(1, t)), r0, r1))]]]];
function corner_faces(wi, outside) = CORNER_FACES[outside ? 1 : 0][wi];
function grid_u(len) = [for (i = [0:ceil(len / U_STEP)]) min(len, i * U_STEP)];
// The walls' pattern repeats every REPEAT_L along them, so the checks on the walls sample one repeat, s over
// [0, REPEAT_L); the corners, each with its own run of the wave, are sampled whole.
PATTERN_S = [for (i = [0:ceil(REPEAT_L / U_STEP) - 1]) i * U_STEP];
// Both faces over one repeat, at the polyhedron's steps: FACES[outside][k][i] at GRID_Z[k], PATTERN_S[i].
FACES = [for (outside = [false, true]) [for (z = GRID_Z) [for (s = PATTERN_S)
    outside ? outside_r(along_wave(s), bump(s), s, z) : inside_r(along_wave(s), s, z)]]];
// The steepest the faces lean from vertical, walls and corners: the print's overhang. The outside overhangs too where
// it leans out going up.
function steepest(outside) = let(f = FACES[outside ? 1 : 0]) max(concat(
    [for (k = [0:len(GRID_Z) - 2], i = [0:len(PATTERN_S) - 1]) abs(f[k + 1][i] - f[k][i]) / (GRID_Z[k + 1] - GRID_Z[k])],
    [for (wi = [0:3], k = [0:len(GRID_Z) - 2], j = [0:len(CORNER_T) - 1]) let(c = corner_faces(wi, outside))
        abs(c[k + 1][j] - c[k][j]) / (GRID_Z[k + 1] - GRID_Z[k])]));
STEEPEST_INSIDE = steepest(false);
STEEPEST_OUTSIDE = steepest(true);
// The outside at its farthest, walls and corners: the frame's footprint.
OUT_R = max(concat([for (row = FACES[1]) max(row)], [for (wi = [0:3], row = corner_faces(wi, true)) max(row)]));
FOOTPRINT = [(N_ACROSS - 1) * P + 2 * OUT_R, (N_DEEP - 1) * P + 2 * OUT_R];

// The vents' grid: the wall's thickness over one repeat along it and the frame's height, finely enough to measure the
// vents by. A row wraps round: its last point's neighbour is its first.
GRID_SS = [for (i = [0:round(REPEAT_L / GRID_DS) - 1]) i * GRID_DS];
GRID_ZS = [for (k = [0:floor(FRAME_H / GRID_DZ)]) k * GRID_DZ];
THICKNESS = HAS_WAVE ? [for (z = GRID_ZS) [for (s = GRID_SS) wall_t_at(s, z)]] : [];
OPEN = [for (row = THICKNESS) [for (t = row) t <= 0]];
WAVE_ROWS = [for (k = [0:len(GRID_ZS) - 1]) if (GRID_ZS[k] > WAVE_SPAN[0] && GRID_ZS[k] < WAVE_SPAN[1]) k];
FULL_ROWS = [for (k = WAVE_ROWS) if (envelope(GRID_ZS[k]) > FULL_DEPTH) k];
// Runs in a row that wraps round, each as [first index, length]: open runs where the value is true.
function next_change(o, i, v, n) = n >= len(o) ? n : o[(i + n) % len(o)] != v ? n : next_change(o, i, v, n + 1);
function wrap_runs(o, v) = let(m = len(o)) len([for (x = o) if (x == v) 1]) == m ? [[0, m]]
    : [for (i = [0:m - 1]) if (o[i] == v && o[(i - 1 + m) % m] != v) [i, next_change(o, i, v, 0)]];
function any_open(o, run) = len([for (n = [0:run[1] - 1]) if (o[(run[0] + n) % len(o)]) 1]) > 0;
// How much of the wall between the bands is open.
OPEN_SHARE = len(WAVE_ROWS) == 0 ? 0 : len([for (k = WAVE_ROWS, x = OPEN[k]) if (x) 1]) / (len(WAVE_ROWS) * len(GRID_SS));
// A row open all the way along would cut the frame in two: its narrowest column is then 0.
RING_ROWS = [for (k = WAVE_ROWS) if (len(wrap_runs(OPEN[k], true)) == 1 && wrap_runs(OPEN[k], true)[0][1] == len(GRID_SS)) k];
// The columns: at each height where the wave is at full depth, the solid between two vents side by side.
ALL_COLUMNS = concat([for (k = RING_ROWS) 0],
    [for (k = FULL_ROWS) if (len([for (x = OPEN[k]) if (x) 1]) > 0) for (r = wrap_runs(OPEN[k], false)) r[1] * GRID_DS]);
COLUMN_NARROWEST = len(ALL_COLUMNS) == 0 ? 0 : min(ALL_COLUMNS);
// The vents' size: the widest across, the tallest up, and the widest 1 mm below a top (the bridge the printer spans):
// an open run whose span is shut ROOF_H above it.
ROOF_ROWS = round(ROOF_H / GRID_DZ);
VENT_WIDEST = max(concat([0], [for (k = WAVE_ROWS, r = wrap_runs(OPEN[k], true)) r[1] * GRID_DS]));
VENT_BRIDGE = max(concat([0], [for (k = WAVE_ROWS) if (k + ROOF_ROWS < len(OPEN)) for (r = wrap_runs(OPEN[k], true))
    if (!any_open(OPEN[k + ROOF_ROWS], r)) r[1] * GRID_DS]));
// Runs up a line of the grid, which doesn't wrap.
function run_up(o, i, n) = i + n >= len(o) || !o[i + n] ? n : run_up(o, i, n + 1);
function column_runs(i) = let(o = [for (k = WAVE_ROWS) OPEN[k][i]])
    [for (j = [0:len(o) - 1]) if (o[j] && (j == 0 || !o[j - 1])) run_up(o, j, 0)];
VENT_TALLEST = max(concat([0], [for (i = [0:len(GRID_SS) - 1], n = HAS_WAVE ? column_runs(i) : []) n * GRID_DZ]));

// The ties: along each trough line of the wave along the wall, where the vents fall, the solid between two vents one
// above the other, sampled finer than the grid.
TIE_ZS = [for (k = [0:floor((WAVE_SPAN[1] - WAVE_SPAN[0]) / TIE_DZ)]) WAVE_SPAN[0] + k * TIE_DZ];
function opens(s) = [for (z = TIE_ZS) wall_t_at(s, z) <= 0];
function next_open(o, i) = i >= len(o) ? -1 : o[i] ? i : next_open(o, i + 1);
// The solid runs between two open ones, as counts of samples.
function solid_runs(o) = [for (i = [1:len(o) - 1]) if (!o[i] && o[i - 1]) let(j = next_open(o, i)) if (j > 0) j - i];
ALL_TIES = HAS_WAVE ? [for (k = [0:round(REPEAT_L / ALONG_WAVELENGTH) - 1], n = solid_runs(opens((k + 0.5) * ALONG_WAVELENGTH))) n * TIE_DZ] : [];
TIE_SHORTEST = len(ALL_TIES) == 0 ? 0 : min(ALL_TIES);

// The wall unrolled, for a view of the pattern: every MAP_STEP-th point of the grid. Each value is the wall's
// thickness, 0 in a vent, and negative where the inside face reaches the cells' land and touches them.
WALL_MAP_ROWS = !HAS_WAVE ? [] : [for (k = [0:MAP_STEP:len(GRID_ZS) - 1]) [for (i = [0:MAP_STEP:len(GRID_SS) - 1]) let(t = THICKNESS[k][i])
    t <= 0 ? 0 : let(r = round(10 * max(t, 0.1)) / 10)
    inside_r(along_wave(GRID_SS[i]), GRID_SS[i], GRID_ZS[k]) <= LAND_R ? -r : r]];

// The inputs first, so a wrong one is named before anything measured from it.
assert(N_ACROSS >= 2 && N_DEEP >= 2 && N_ACROSS == round(N_ACROSS) && N_DEEP == round(N_DEEP),
    "CELL_COLUMNS and CELL_ROWS are whole numbers, 2 or more");
assert(PART == "frame" || PART == "coupon", "PART is frame or coupon");
assert(GRIP == "auto" || GRIP == "gap" || GRIP == "wall", "GRIP is auto, gap or wall");
assert(ALONG_SHARE >= 0 && ALONG_SHARE <= 1, "ALONG_SHARE is a share, 0 to 1");
assert(abs(STAGGER * ROUND_S / P - round(STAGGER * ROUND_S / P)) < 1e-6,
    str("with STAGGER ", STAGGER, ", CELL_COLUMNS + CELL_ROWS must be even, or the vents won't meet up round a corner"));
assert(MIRROR >= 0 && MIRROR <= 1, "MIRROR is a share, 0 to 1");
assert(WAVES_PER_CELL >= 1 && WAVES_PER_CELL == round(WAVES_PER_CELL), "WAVES_PER_CELL is a whole number, so every cell's middle is a crest");
assert(STAGGER == 0 || abs(1 / STAGGER - round(1 / STAGGER)) < 1e-6, "STAGGER is 0 or 1 / n of a wave, so the pattern repeats");
// Then what the design measures.
assert(GRIP_USED != "gap" || GAP_SPAN_MAX >= BOW_SPAN_MIN, str("the gap between edge cells holds a bow of ", GAP_SPAN_MAX,
    " mm, under BOW_SPAN_MIN ", BOW_SPAN_MIN, ": use GRIP = \"wall\", or widen CELL_GAP or PITCH"));
assert(DRAWN_SPAN >= BOW_SPAN_MIN, str("the bows are ", DRAWN_SPAN, " mm, under BOW_SPAN_MIN ", BOW_SPAN_MIN));
assert(BOW_FACE_D < FRAME_LAND_D, "the bows' faces must stand in past the frame's lands");
assert(GRIP_USED != "wall" || POCKET_BACK_R <= BAND_OUT_R - NECK_MIN, str("the wall grip's pockets reach within ", BAND_OUT_R - POCKET_BACK_R,
    " mm of the wall's outside, under NECK_MIN ", NECK_MIN, ": thicken WALL_T"));
assert(len(ALL_TIES) == 0 || TIE_SHORTEST >= TIE_MIN, str("the shortest tie between vents is ", TIE_SHORTEST, " mm"));
assert(len(RING_ROWS) == 0, str("the vents run all the way round at ", len(RING_ROWS) == 0 ? 0 : GRID_ZS[RING_ROWS[0]],
    " mm up: the frame would come apart there"));
assert(len(ALL_COLUMNS) == 0 || COLUMN_NARROWEST >= COLUMN_MIN, str("the narrowest column between vents is ", COLUMN_NARROWEST, " mm"));
assert(VENT_BRIDGE <= BRIDGE_MAX, str("a vent's top is ", VENT_BRIDGE, " mm wide 1 mm below it, over BRIDGE_MAX ",
    BRIDGE_MAX, ": the printer would have to bridge it"));
assert(max(FOOTPRINT[0], FOOTPRINT[1], FRAME_H) <= PRINTER_SIZE, str("the part is ", FOOTPRINT, " x ", FRAME_H,
    ": bigger than the printer"));
for (b = BANDS) assert(b[0] >= 0 && b[1] <= FRAME_H, "a band of bows runs past the frame's ends");
CORNER_PACE = [for (o = [false, true], wi = [0:3], c = corner_faces(wi, o)) c[1] * PI / 2 / CORNER_S];   // at t = 0
assert(min(CORNER_PACE) > 0 && max(CORNER_PACE) < 3,
    "a corner's arc is so far from CORNER_S long that the wave would run back on itself round it");
assert(COUPON || WAVE_SPAN[1] - WAVE_SPAN[0] > 2 * RAMP, str("the frame is too short for its vents: ",
    WAVE_SPAN[1] - WAVE_SPAN[0], " mm between the bands' blends, under the ", 2 * RAMP, " its ramps take"));
assert(STEEPEST_INSIDE <= SLOPE_MAX, str("the inside leans ", atan(STEEPEST_INSIDE), " degrees: past 45 it would need support"));
assert(STEEPEST_OUTSIDE <= SLOPE_MAX, str("the outside leans ", atan(STEEPEST_OUTSIDE), " degrees: past 45 it would need support"));
assert(CREST_R > P / 2 - ARM_TIP_W, "a crest reaches so far in it closes the gap between two cells");
assert(TROUGH_R > DATUM_R, "the troughs never pass the datum: the wall never opens");
assert(COUPON || (OPEN_SHARE > 0 && OPEN_SHARE >= OPEN_SHARE_MIN), str("only ", OPEN_SHARE,
    " of the wall opens, under OPEN_SHARE_MIN ", OPEN_SHARE_MIN, ": the frame is too short for whole vents"));

module outer_2d() translate([-OUT_R - 1, -OUT_R - 1]) square(FOOTPRINT + [2, 2]);   // just past the walls' own faces
// The cells' outline at distance r out from the lines through the edge cells' axes.
module inner_2d(r) translate([-r, -r]) square([(N_ACROSS - 1) * P + 2 * r, (N_DEEP - 1) * P + 2 * r]);
// A pad in front of an edge cell's middle, in the cell's frame toward the wall: from inside the land (the land trims
// it) into the wall.
module pad_2d() translate([LAND_R - 1, -DRAWN_SPAN / 2 - PAD_FLANK]) square([RELIEF_R - LAND_R + 2, DRAWN_SPAN + 2 * PAD_FLANK]);
module ridges_2d() intersection() {
    inner_2d(BAND_OUT_R);
    difference() { inner_2d(BAND_OUT_R); offset(delta = -RIDGE_REACH) inner_2d(RELIEF_R); }
    corners_2d(BAND_OUT_R);
    union() {
        for (g = RIDGE_GAPS) translate(g[0]) circle(r = arm_r(CELL_FIT + RIDGE_LAND_CLR));
        if (GRIP_USED == "wall") for (b = BOWS) toward(b[0], b[1]) pad_2d();
    }
}
// The ridges d in from the bands' wall face: a ridge growing from the wall, or shrinking back into it.
module ridges_within_2d(d) difference() { ridges_2d(); offset(delta = -d) inner_2d(RELIEF_R); }
module pockets_2d(depth = POCKET_DEPTH) for (b = BOWS) toward(b[0], b[1]) pocket_2d(DRAWN_SPAN, depth);

function band_at(z) = [for (b = BANDS) if (z >= b[0] && z <= b[1]) b];
function frame_bow_face_d(z) = let(b = band_at(z)) len(b) == 0 ? BORE - BOW_T : bow_face_d_at(z - b[0][0], b[0][1] - b[0][0]);
module bows_2d(face_d) for (b = BOWS) toward(b[0], b[1]) bow_2d(face_d, DRAWN_SPAN);

// The space within one wall's inside face, or its outside face: in the wall's own frame (u along it, the outside
// towards -y), everything from the face in to FAR. Past the wall's ends, over the corners, it bounds nothing: the
// corners' own faces do (corners()).
FAR = max(FOOTPRINT[0], FOOTPRINT[1]) + 10;

// A wall starts at each corner cell (WALLS[k][0]), and its u = 0 is that cell's middle; the corner before it is a
// quarter turn about that cell's axis, from the outside of the wall before (a0) to its own.
module plus_2d() {   // the frame clear of the four corner quadrants
    translate([0, -FAR]) square([(N_ACROSS - 1) * P, 2 * FAR + (N_DEEP - 1) * P]);
    translate([-FAR, 0]) square([2 * FAR + (N_ACROSS - 1) * P, (N_DEEP - 1) * P]);
}
module corners_2d(r) union() { plus_2d(); for (w = WALLS) translate(w[0]) circle(r = r); }
// The solid inside a corner's face: from the corner cell's axis out to the face, over the quarter turn and a step past
// each end, where the frame is the walls' (plus_2d) anyway. Faces are listed anticlockwise from outside, then
// reversed: OpenSCAD wants them clockwise.
module corner(wi, outside) let(w = WALLS[wi], c = corner_faces(wi, outside), nt = len(CORNER_T), nz = len(GRID_Z), a0 = w[1] - 180,
    zz = function(k) k == 0 ? -0.01 : k == nz - 1 ? FRAME_H + 0.01 : GRID_Z[k],
    f = function(j, k) j + k * nt, ax = function(k) nt * nz + k)
    translate(w[0]) polyhedron(
        points = concat([for (k = [0:nz - 1], j = [0:nt - 1]) let(r = c[k][j], a = a0 + 90 * CORNER_T[j])
                [r * cos(a), r * sin(a), zz(k)]],
            [for (k = [0:nz - 1]) [0, 0, zz(k)]]),
        faces = [for (q = concat(
            [for (k = [0:nz - 2], j = [0:nt - 2]) [f(j, k), f(j + 1, k), f(j + 1, k + 1), f(j, k + 1)]],
            [for (k = [0:nz - 2]) [ax(k), f(0, k), f(0, k + 1), ax(k + 1)]],
            [for (k = [0:nz - 2]) [f(nt - 1, k), ax(k), ax(k + 1), f(nt - 1, k + 1)]],
            [concat([ax(0)], [for (j = [nt - 1:-1:0]) f(j, 0)])],
            [concat([ax(nz - 1)], [for (j = [0:nt - 1]) f(j, nz - 1)])])) [for (i = [len(q) - 1:-1:0]) q[i]]]);
module corners(outside) union() {
    translate([0, 0, -1]) linear_extrude(FRAME_H + 2) plus_2d();
    for (wi = [0:3]) corner(wi, outside);
}
module within_face(w, outside = false) let(len = w[2], us = concat([-FAR], grid_u(len), [len + FAR]), nu = len(us), nz = len(GRID_Z),
    zz = function(k) k == 0 ? -0.01 : k == nz - 1 ? FRAME_H + 0.01 : GRID_Z[k],
    f = function(i, k) i + k * nu, b0 = function(k) nu * nz + k, b1 = function(k) nu * nz + nz + k)
    translate(w[0]) rotate(w[1]) polyhedron(
        points = concat([for (k = [0:nz - 1], i = [0:nu - 1]) [us[i], i == 0 || i == nu - 1 ? -FAR
                : outside ? -wall_outside_r(w, us[i], GRID_Z[k]) : -wall_inside_r(w, us[i], GRID_Z[k]), zz(k)]],
            [for (k = [0:nz - 1]) [us[0], FAR, zz(k)]], [for (k = [0:nz - 1]) [us[nu - 1], FAR, zz(k)]]),
        faces = concat(
            [for (k = [0:nz - 2], i = [0:nu - 2]) [f(i, k + 1), f(i + 1, k + 1), f(i + 1, k), f(i, k)]],
            [for (k = [0:nz - 2]) [b1(k + 1), b0(k + 1), b0(k), b1(k)]],
            [for (k = [0:nz - 2]) [b0(k + 1), f(0, k + 1), f(0, k), b0(k)]],
            [for (k = [0:nz - 2]) [f(nu - 1, k + 1), b1(k + 1), b1(k), f(nu - 1, k)]],
            [concat([for (i = [0:nu - 1]) f(i, 0)], [b1(0), b0(0)])],
            [concat([b0(nz - 1), b1(nz - 1)], [for (i = [nu - 1:-1:0]) f(i, nz - 1)])]));

// The cells, at their land, with a 45 degree lead-in at both ends.
module cells_cut() for (i = [0:N_ACROSS - 1], j = [0:N_DEEP - 1]) translate(cell_at(i, j)) {
    translate([0, 0, -0.01]) cylinder(d = FRAME_LAND_D, h = FRAME_H + 0.02);
    translate([0, 0, -0.01]) cylinder(d1 = FRAME_LAND_D + 2 * CHAMFER + 0.02, d2 = FRAME_LAND_D, h = CHAMFER + 0.01);
    translate([0, 0, FRAME_H - CHAMFER]) cylinder(d1 = FRAME_LAND_D, d2 = FRAME_LAND_D + 2 * CHAMFER + 0.02, h = CHAMFER + 0.01);
}

// Each band's ridges run out to the frame's end beyond it; toward the middle they blend into the wall: a band above
// the bed starts its ridges in a taper, a band below the top ends them in a fade. The pockets open from the band's
// start to its far end, so each pocket has solid ridge or the bed under it, and a bow starts on its floor.
function first_band(k) = k == 0;
function last_band(k) = k == len(BANDS) - 1;
function ridge_span(k) = [first_band(k) ? 0 : BANDS[k][0], last_band(k) ? FRAME_H : BANDS[k][1]];
function pocket_span(k) = [BANDS[k][0], last_band(k) ? FRAME_H : BANDS[k][1] + FADE_H];
// Where a pocket reaches into the sheet behind it (the wall grip's), it is cut there too. Above a pocket that ends
// short of the top, its back closes in at 45 degrees over the depth it reached into the sheet, so it needs no bridge.
SHEET_DEPTH = max(0, POCKET_BACK_R - RELIEF_R);
module sheet_pockets() for (k = [0:len(BANDS) - 1]) let(q = pocket_span(k)) {
    translate([0, 0, q[0]]) linear_extrude(q[1] - q[0] + 0.02) pockets_2d();
    if (!last_band(k) && SHEET_DEPTH > 0) let(n = max(1, ceil(SHEET_DEPTH / SLICE))) for (i = [0:n - 1])
        translate([0, 0, q[1] + i * SHEET_DEPTH / n]) linear_extrude(SHEET_DEPTH / n + 0.01) pockets_2d(POCKET_DEPTH - (i + 1) * SHEET_DEPTH / n);
}

module frame() union() {
    difference() {
        union() {
            // the sheet: inside every wall's outside face, and outside every wall's inside face
            difference() {
                intersection() {
                    linear_extrude(FRAME_H) outer_2d();
                    intersection_for (w = WALLS) within_face(w, true);
                    corners(true);
                }
                intersection() {
                    intersection_for (w = WALLS) within_face(w);
                    corners(false);
                }
            }
            for (k = [0:len(BANDS) - 1]) let(r = ridge_span(k)) {
                translate([0, 0, r[0]]) linear_extrude(r[1] - r[0]) ridges_2d();
                // a band that ends short of the top blends its ridges back into the wall
                if (!last_band(k)) let(n = ceil(FADE_H / SLICE)) for (i = [0:n - 1])
                    let(z = r[1] + i * FADE_H / n, d = RIDGE_REACH * (1 - blend((i + 1) / n)))
                    if (d > 0.05) translate([0, 0, z]) linear_extrude(FADE_H / n + 0.01) ridges_within_2d(d);
                if (!first_band(k)) let(n = ceil(TAPER_H / SLICE)) for (i = [0:n - 1])
                    let(z = r[0] - TAPER_H + i * TAPER_H / n)
                    translate([0, 0, z]) linear_extrude(TAPER_H / n + 0.01) ridges_within_2d(taper_d((i + 1) * TAPER_H / n) + 0.01);
            }
        }
        cells_cut();
        sheet_pockets();
    }
    // the bows, contoured along each band
    for (b = BANDS) let(n = ceil((b[1] - b[0]) / BOW_SLICE)) for (k = [0:n - 1])
        let(z0 = b[0] + k * (b[1] - b[0]) / n, z1 = b[0] + (k + 1) * (b[1] - b[0]) / n)
        translate([0, 0, z0]) linear_extrude(z1 - z0 + 0.01) bows_2d(frame_bow_face_d((z0 + z1) / 2));
}

// The coupon's tab, off the outside of the wall under the first row, between its two cells: from inside that wall's
// face (so it fuses) out past the frame's outside, its fit offset cut into it.
TAB_T = 1.6;            // mm, the tab's thickness, lying on the bed
TAB_OUT = 10;           // mm the tab stands out past the frame's outside
TEXT_SIZE = 5;          // mm
TEXT_DEPTH = 0.6;       // mm the label is cut into the tab
LABEL = str(CELL, " ", FIT_OFFSET >= 0 ? "+" : "", FIT_OFFSET);
TAB_W = 0.75 * TEXT_SIZE * len(LABEL) + 6;   // mm: about the label's width, and a margin
module tab() translate([P / 2, 0, 0]) difference() {
    translate([-TAB_W / 2, -OUT_R - TAB_OUT, 0]) cube([TAB_W, OUT_R + TAB_OUT - (BAND_OUT_R - 0.5), TAB_T]);
    translate([0, -OUT_R - TAB_OUT / 2, TAB_T - TEXT_DEPTH]) linear_extrude(TEXT_DEPTH + 0.01)
        text(LABEL, size = TEXT_SIZE, halign = "center", valign = "center");
}
module part() { frame(); if (COUPON) tab(); }

module cells() for (i = [0:N_ACROSS - 1], j = [0:N_DEEP - 1]) translate(cell_at(i, j))
    color("SteelBlue", 0.45) translate([0, 0, -END_CLR]) cylinder(d = CELL_FIT, h = COUPON ? FRAME_H + 2 * END_CLR : BODY_L);

assert(VIEW == "part" || VIEW == "with_cells" || VIEW == "none", "VIEW is part, with_cells or none");
if (VIEW == "part") color("Orange") part();
if (VIEW == "with_cells") { color("Orange") part(); cells(); }

echo(FRAME = [["part", PART], ["cell", CELL], ["body_d", BODY_D], ["body_l", BODY_L], ["cell_fit", CELL_FIT], ["pitch", P],
    ["cells", [N_ACROSS, N_DEEP]], ["footprint", FOOTPRINT], ["height", FRAME_H], ["land_d", FRAME_LAND_D],
    ["grip", GRIP_USED], ["bow_span", DRAWN_SPAN], ["gap_span_max", GAP_SPAN_MAX], ["bows_per_band", len(BOWS)],
    ["bands", BANDS], ["taper_h", TAPER_H], ["up_waves", UP_WAVES], ["along_share", ALONG_SHARE], ["wall_t", WALL_T],
    ["trough_depth", TROUGH_DEPTH], ["steepest_inside_deg", atan(STEEPEST_INSIDE)],
    ["steepest_outside_deg", atan(STEEPEST_OUTSIDE)], ["bump_depth", BUMP_DEPTH], ["open_share", OPEN_SHARE],
    ["tie_shortest", TIE_SHORTEST], ["column_narrowest", COLUMN_NARROWEST], ["vent_tallest", VENT_TALLEST],
    ["vent_widest", VENT_WIDEST], ["vent_bridge", VENT_BRIDGE], ["repeat_l", REPEAT_L],
    ["bow_past_land", (FRAME_LAND_D - BOW_FACE_D) / 2]]);
// The wall unrolled: [its points' step along, their step up, the cells' pitch (a cell's middle every pitch along), the
// rows from the bottom up]. A value is the wall's thickness, 0 in a vent, negative where it touches the cells.
if (HAS_WAVE) echo(WALL_MAP = [["ds", GRID_DS * MAP_STEP], ["dz", GRID_DZ * MAP_STEP], ["pitch", P], ["rows", WALL_MAP_ROWS]]);
