# SPDX-License-Identifier: CERN-OHL-S-2.0
import ast
import re
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

# The configuration the grip was fit-tested in: a 33140 cell that the printed grip sees as 33.2 mm, at a 34 mm pitch
# set by the busbars, in a block of 4 x 6.
TESTED = {"CELL": '"33140"', "FIT_OFFSET": -0.1, "PITCH": 34, "CELL_L": 140}


def evaluate(tmp_path, part, **overrides):
    """Evaluate a part echo-only with -D overrides. OpenSCAD writes a failed assert into the echo file and still exits
    0, so a run is good only when neither the file nor stderr holds an ERROR or a WARNING."""
    out = tmp_path / f"{part}.echo"
    args = [OPENSCAD, "-o", str(out)]
    for key, value in overrides.items():
        args += ["-D", f"{key}={value}"]
    result = subprocess.run(args + [str(ROOT / f"{part}.scad")], text=True, capture_output=True)
    text = (out.read_text() if out.exists() else "") + result.stderr
    ok = result.returncode == 0 and "ERROR" not in text and "WARNING" not in text
    return ok, text


def echoed(text, name):
    found = re.search(rf"^ECHO: {name} = (.+)$", text, re.M)
    assert found, text
    return dict(ast.literal_eval(found.group(1)))
