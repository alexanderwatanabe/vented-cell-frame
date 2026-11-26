// SPDX-License-Identifier: CERN-OHL-S-2.0
// Generated from presets/cells.json by tools/gen_cells.py: edit that file, not this one.
// Cell presets: [name, body diameter, body length end face to end face], mm. A preset only says where the grip sits;
// how the printed grip sees the cell is FIT_OFFSET, found with the coupon set (README).

CELL_PRESETS = [
    ["18650", 18.5, 65],   // Samsung INR18650-35E: max 18.55 x 65.25 overall
    ["21700", 21.2, 70],   // Samsung INR21700-50E: max 21.25 x 70.8, sleeved
    ["26650", 26, 65],   // A123 ANR26650M1-B: 25.96 sleeved x 65.15; other makers run to 26.5
    ["32650", 32.3, 65],   // no datasheet found
    ["32700", 32.4, 70.5],   // LiFePO4 32700 6 Ah (HX-TS-066): 32.4 +-0.3 sleeved x 70.5 +0.4/-0.3
    ["33140", 33.3, 140.5],   // IFR33140 15 Ah: 33.3 +-0.2 x 140.5 +-0.5; fit-tested: a 33.2 fit (FIT_OFFSET -0.1)
    ["40135", 40.2, 135],   // no datasheet found
    ["4680", 46, 80],   // nominal, from teardowns; no datasheet published
    ["66160", 66, 160],   // Yinlong LTO 66160 40 Ah: 66 +-1 x 161 +-1 (whether 161 includes the studs is unclear)
];

function cell_preset(name) = let(hits = [for (p = CELL_PRESETS) if (p[0] == name) p]) len(hits) == 1 ? hits[0] : undef;
CELL_NAMES = [for (p = CELL_PRESETS) p[0]];
