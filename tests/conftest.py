# SPDX-License-Identifier: CERN-OHL-S-2.0
import ast
import re
import struct
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from openscad import ROOT, find_openscad  # noqa: E402

try:
    OPENSCAD = find_openscad()
except RuntimeError:
    OPENSCAD = None
needs_openscad = pytest.mark.skipif(OPENSCAD is None, reason="requires OpenSCAD: set $OPENSCAD")
HAS_MANIFOLD = OPENSCAD is not None and "manifold" in (lambda r: (r.stdout + r.stderr).lower())(
    subprocess.run([OPENSCAD, "--help"], text=True, capture_output=True))
needs_manifold = pytest.mark.skipif(not HAS_MANIFOLD, reason="requires an OpenSCAD with the Manifold backend")

# The configuration the grip was fit-tested in: a 33140 cell that the printed grip sees as 33.2 mm, at a 34 mm pitch
# set by the busbars, in a block of 4 x 6.
TESTED = {"CELL": '"33140"', "FIT_OFFSET": -0.1, "PITCH": 34, "CELL_L": 140}
COUPON = {"PART": '"coupon"'}


def defines(overrides):
    args = []
    for key, value in overrides.items():
        args += ["-D", f"{key}={value}"]
    return args


def evaluate(tmp_path, part, **overrides):
    """Evaluate a part echo-only with -D overrides. OpenSCAD writes a failed assert into the echo file and still exits
    0, so a run is good only when neither the file nor stderr holds an ERROR or a WARNING."""
    out = tmp_path / f"{part}.echo"
    overrides = {"VIEW": '"none"', **overrides}
    result = subprocess.run([OPENSCAD, "-o", str(out)] + defines(overrides) + [str(ROOT / f"{part}.scad")],
                            text=True, capture_output=True)
    text = (out.read_text() if out.exists() else "") + result.stderr
    ok = result.returncode == 0 and "ERROR" not in text and "WARNING" not in text
    return ok, text


def echoed(text, name):
    found = re.search(rf"^ECHO: {name} = (.+)$", text, re.M)
    assert found, text
    return dict(ast.literal_eval(found.group(1)))


def render(tmp_path, source, **overrides):
    """Render with Manifold to a binary STL; its triangles, or None if OpenSCAD drew nothing."""
    out = tmp_path / "part.stl"
    result = subprocess.run([OPENSCAD, "--backend=manifold", "--export-format=binstl", "-o", str(out)]
                            + defines(overrides) + [str(source)], text=True, capture_output=True)
    assert "ERROR" not in result.stderr, result.stderr
    if not out.exists():
        return None
    data = out.read_bytes()
    (n,) = struct.unpack_from("<I", data, 80)
    return [[struct.unpack_from("<3f", data, 84 + 50 * i + 12 + 12 * j) for j in range(3)] for i in range(n)]


def solids(triangles):
    """How many separate solids a mesh holds: triangles sharing a vertex are one solid."""
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for t in triangles:
        keys = [tuple(round(c, 4) for c in v) for v in t]
        for k in keys[1:]:
            parent[find(k)] = find(keys[0])
    return len({find(tuple(round(c, 4) for c in t[0])) for t in triangles})


def bounds(triangles):
    pts = [v for t in triangles for v in t]
    return [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
