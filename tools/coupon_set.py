# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Render a set of calibration coupons, one per fit offset, laid out as one print in one STL.

    uv run tools/coupon_set.py --cell 21700
    uv run tools/coupon_set.py --cell 33140 --centre -0.1 --step 0.05 -D PITCH=34 -o my-coupons.stl

Each coupon is frame.scad with PART = "coupon" at FIT_OFFSET = centre + k * step, its offset cut into its tab. Any
other frame input passes through with -D, so the coupons match the frame you mean to print.
"""

import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from openscad import ROOT, find_openscad  # noqa: E402

COUPON_SPACING = 5.0   # mm between coupons on the plate
FIXED = {"PART", "FIT_OFFSET", "CELL", "CELL_COLUMNS", "CELL_ROWS", "VIEW"}   # each coupon sets these itself


def read_stl(path):
    """Triangles of a binary STL, as lists of three (x, y, z) vertices."""
    data = path.read_bytes()
    (n,) = struct.unpack_from("<I", data, 80)
    tris = []
    for i in range(n):
        v = struct.unpack_from("<12f", data, 84 + 50 * i)
        tris.append([v[3:6], v[6:9], v[9:12]])
    return tris


def write_stl(path, tris):
    out = bytearray(b"vented-cell-frame coupon set".ljust(80, b" "))
    out += struct.pack("<I", len(tris))
    for t in tris:
        out += struct.pack("<3f", 0, 0, 0)
        for v in t:
            out += struct.pack("<3f", *v)
        out += b"\0\0"
    path.write_bytes(bytes(out))


def bbox(tris):
    xs = [v[0] for t in tris for v in t]
    ys = [v[1] for t in tris for v in t]
    return min(xs), min(ys), max(xs), max(ys)


def layout(sizes, plate):
    """Shelf-pack rectangles (w, h) into rows no wider than plate; their lower-left corners, or None if it won't fit."""
    x = y = row_h = 0.0
    spots = []
    for w, h in sizes:
        if x > 0 and x + w > plate:
            x, y, row_h = 0.0, y + row_h + COUPON_SPACING, 0.0
        spots.append((x, y))
        x, row_h = x + w + COUPON_SPACING, max(row_h, h)
    width = max(sx + w for (sx, _), (w, _) in zip(spots, sizes))
    return spots if max(width, y + row_h) <= plate else None


def offsets(centre, step, count):
    half = (count - 1) / 2
    return [round(centre + (k - half) * step, 4) for k in range(count)]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cell", required=True, help='a preset, or "custom" with -D CELL_D=... -D CELL_L=...')
    ap.add_argument("--centre", type=float, default=0.0, help="mm, the middle offset (default 0)")
    ap.add_argument("--step", type=float, default=0.2, help="mm between offsets (default 0.2; 0.05 to refine)")
    ap.add_argument("--count", type=int, default=3, help="coupons in the set (default 3)")
    ap.add_argument("--printer-size", type=float, default=270.0, help="mm, the printer's bed, its smaller side (default 270)")
    ap.add_argument("-D", action="append", default=[], metavar="NAME=VALUE", help="any other frame input")
    ap.add_argument("-o", "--out", type=Path, help="the STL to write (default coupons-<cell>.stl)")
    args = ap.parse_args(argv)
    if args.count < 1:
        ap.error("--count must be 1 or more")
    if args.step <= 0:
        ap.error("--step must be above 0")
    for d in args.D:
        if d.split("=", 1)[0].strip() in FIXED:
            ap.error(f"-D {d}: each coupon sets {', '.join(sorted(FIXED))} itself; use --cell, --centre and --step")

    openscad = find_openscad()
    out = args.out or Path(f"coupons-{args.cell}.stl")
    parts = []
    with tempfile.TemporaryDirectory() as tmp:
        for k, off in enumerate(offsets(args.centre, args.step, args.count)):
            stl = Path(tmp) / f"c{k}.stl"
            cmd = [openscad, "--backend=manifold", "--export-format=binstl", "-o", str(stl), "-D", 'PART="coupon"',
                   "-D", f'CELL="{args.cell}"', "-D", f"FIT_OFFSET={off}"]
            for d in args.D:
                cmd += ["-D", d]
            run = subprocess.run(cmd + [str(ROOT / "frame.scad")], text=True, capture_output=True)
            if run.returncode != 0 or "ERROR" in run.stderr or not stl.exists():
                sys.exit(f"coupon at FIT_OFFSET {off} failed:\n{run.stderr}")
            parts.append(read_stl(stl))
            print(f"FIT_OFFSET {off:+g}: rendered")
    boxes = [bbox(t) for t in parts]
    spots = layout([(b[2] - b[0], b[3] - b[1]) for b in boxes], args.printer_size)
    if spots is None:
        sys.exit(f"the set won't fit a {args.printer_size:g} mm plate: use --count 1 per print, or a smaller --count")
    merged = [[(v[0] - b[0] + sx, v[1] - b[1] + sy, v[2]) for v in t]
              for t_list, b, (sx, sy) in zip(parts, boxes, spots) for t in t_list]
    write_stl(out, merged)
    print("wrote", out)


if __name__ == "__main__":
    main()
