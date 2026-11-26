# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Write lib/cells.scad, and the README's preset table, from presets/cells.json: the presets' one source.

    uv run tools/gen_cells.py           write both
    uv run tools/gen_cells.py --check   fail if either is stale
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON = ROOT / "presets/cells.json"
SCAD = ROOT / "lib/cells.scad"
README = ROOT / "README.md"
PARTS = [ROOT / "frame.scad", ROOT / "spacer.scad"]   # their Customizer's CELL dropdown
BEGIN, END = "<!-- presets:begin -->", "<!-- presets:end -->"


def load():
    cells = json.loads(JSON.read_text())["cells"]
    names = [c["name"] for c in cells]
    if len(set(names)) != len(names) or "custom" in names:
        raise SystemExit("presets/cells.json: names must be unique and not 'custom'")
    for c in cells:
        if not (c["d"] > 0 and c["l"] > 0):
            raise SystemExit(f"presets/cells.json: {c['name']} needs a positive d and l")
    return cells


def fmt(x):
    return f"{x:g}"


def scad(cells):
    rows = "\n".join(f'    ["{c["name"]}", {fmt(c["d"])}, {fmt(c["l"])}],   // {c["basis"]}' for c in cells)
    return f"""// SPDX-License-Identifier: CERN-OHL-S-2.0
// Generated from presets/cells.json by tools/gen_cells.py: edit that file, not this one.
// Cell presets: [name, body diameter, body length end face to end face], mm. A preset only says where the grip sits;
// how the printed grip sees the cell is FIT_OFFSET, found with the coupon set (README).

CELL_PRESETS = [
{rows}
];

// The Customizer reads a dropdown's numeric-looking names (18650) as numbers, so a name may arrive as either.
function cell_preset(name) = let(n = is_num(name) ? str(name) : name, hits = [for (p = CELL_PRESETS) if (p[0] == n) p])
    len(hits) == 1 ? hits[0] : undef;
CELL_NAMES = [for (p = CELL_PRESETS) p[0]];
"""


def table(cells):
    lines = ["| Preset | Diameter × length (mm) | Basis | Datasheet |", "|---|---|---|---|"]
    for c in cells:
        src = f"[link]({c['source']})" if c["source"] else "none found"
        flag = " (VERIFY)" if c["verify"] else ""
        lines.append(f"| {c['name']} | {fmt(c['d'])} × {fmt(c['l'])}{flag} | {c['basis']} | {src} |")
    return "\n".join(lines)


def readme(cells):
    text = README.read_text()
    a, b = text.index(BEGIN) + len(BEGIN), text.index(END)
    return text[:a] + "\n" + table(cells) + "\n" + text[b:]


def dropdown(path, cells):
    names = ", ".join([c["name"] for c in cells] + ["custom"])
    return re.sub(r'^(CELL = "[^"]*"; // )\[.*\]$', lambda m: m.group(1) + f"[{names}]", path.read_text(), flags=re.M)


def main():
    cells = load()
    want = {SCAD: scad(cells), **{p: dropdown(p, cells) for p in PARTS}}
    if README.exists() and BEGIN in README.read_text():
        want[README] = readme(cells)
    stale = [p for p, t in want.items() if not p.exists() or p.read_text() != t]
    if "--check" in sys.argv:
        if stale:
            raise SystemExit("stale: " + ", ".join(str(p.relative_to(ROOT)) for p in stale) + ": run tools/gen_cells.py")
        return
    for p in stale:
        p.write_text(want[p])
        print("wrote", p.relative_to(ROOT))


if __name__ == "__main__":
    main()
