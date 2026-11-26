# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Write configurator/params.json, the configurator's form, from the parts' own Customizer sections, as OpenSCAD
exports them.

    uv run tools/gen_params.py           write it
    uv run tools/gen_params.py --check   fail if it is stale
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from openscad import ROOT, find_openscad  # noqa: E402

OUT = ROOT / "configurator/params.json"
PARTS = ["frame", "spacer"]
SKIP = {"VIEW"}   # the configurator sets it


def export(openscad, part):
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "p.json"
        run = subprocess.run([openscad, "--export-format=param", "-o", str(out), "-D", 'VIEW="none"',
                              str(ROOT / f"{part}.scad")], text=True, capture_output=True)
        if not out.exists():
            raise SystemExit(f"{part}: OpenSCAD exported no parameters:\n{run.stderr}")
        params = json.loads(out.read_text())["parameters"]
    return [p for p in params if p["name"] not in SKIP]


def render():
    openscad = find_openscad()
    return json.dumps({part: export(openscad, part) for part in PARTS}, indent=1) + "\n"


def main():
    text = render()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            raise SystemExit("stale: configurator/params.json: run tools/gen_params.py")
        return
    OUT.write_text(text)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
