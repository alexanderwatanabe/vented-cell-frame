# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Find an OpenSCAD binary for the tools and tests: $OPENSCAD, else `openscad` on PATH, else the newest macOS app."""

import glob
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def find_openscad():
    found = os.environ.get("OPENSCAD") or shutil.which("openscad")
    if found:
        return found
    apps = sorted(glob.glob("/Applications/OpenSCAD*.app/Contents/MacOS/OpenSCAD"))
    if apps:
        return apps[-1]
    raise RuntimeError("OpenSCAD not found: set $OPENSCAD, or put openscad on PATH")
