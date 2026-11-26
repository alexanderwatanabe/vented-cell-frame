# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Every preset evaluates headless, as a frame in an array that fits the printer, a coupon and a spacer, at the
default gap; and the generated preset files match presets/cells.json."""

import json
import subprocess
import sys

import pytest

from conftest import ROOT, echoed, evaluate, needs_openscad

PRESETS = {c["name"]: c for c in json.loads((ROOT / "presets/cells.json").read_text())["cells"]}
# A block that fits the 270 mm printer, the grip the default gap gives (at 3 mm, the gap grip for every preset), and any vent settings the cell needs: past
# about 40 mm a vent's top is too wide to bridge with one wave per cell, and two need a thicker wall to stay under 45.
LARGE = {"WAVES_PER_CELL": 2}
EXPECT = {
    "18650": ([4, 6], "gap", {}), "21700": ([4, 6], "gap", {}), "26650": ([4, 6], "gap", {}),
    "32650": ([4, 6], "gap", {}), "32700": ([4, 6], "gap", {}), "33140": ([4, 6], "gap", {}),
    "40135": ([4, 5], "gap", {}), "4680": ([3, 4], "gap", {**LARGE, "MIRROR": 0.75}),
    "66160": ([2, 2], "gap", {**LARGE, "MIRROR": 0.8}),
}


def test_every_preset_has_an_expectation():
    assert set(EXPECT) == set(PRESETS)


@needs_openscad
@pytest.mark.parametrize("name", list(EXPECT))
def test_preset_frame(tmp_path, name):
    (columns, rows), grip, vents = EXPECT[name]
    ok, text = evaluate(tmp_path, "frame", CELL=f'"{name}"', CELL_COLUMNS=columns, CELL_ROWS=rows, **vents)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert [frame["body_d"], frame["body_l"]] == [PRESETS[name]["diameter"], PRESETS[name]["length"]]
    assert frame["grip"] == grip
    assert frame["spacers_fit"]   # the default gap leaves room for the spacers that hold the cells inside
    assert frame["steepest_inside_deg"] <= 45 and frame["steepest_outside_deg"] <= 45 and frame["open_share"] > 0


@needs_openscad
@pytest.mark.parametrize("name", list(EXPECT))
def test_preset_coupon(tmp_path, name):
    ok, text = evaluate(tmp_path, "frame", CELL=f'"{name}"', PART='"coupon"')
    assert ok, text
    assert echoed(text, "FRAME")["cells"] == [2, 2]


@needs_openscad
@pytest.mark.parametrize("name", list(EXPECT))
def test_preset_spacer(tmp_path, name):
    ok, text = evaluate(tmp_path, "spacer", CELL=f'"{name}"')
    assert ok, text


def test_generated_files_match_the_presets():
    run = subprocess.run([sys.executable, str(ROOT / "tools/gen_cells.py"), "--check"], text=True, capture_output=True)
    assert run.returncode == 0, run.stdout + run.stderr


@needs_openscad
def test_the_configurators_form_matches_the_parts():
    run = subprocess.run([sys.executable, str(ROOT / "tools/gen_params.py"), "--check"], text=True, capture_output=True)
    assert run.returncode == 0, run.stdout + run.stderr


def test_the_single_page_is_built_from_the_configurator():
    run = subprocess.run([sys.executable, str(ROOT / "tools/build_page.py"), "--check"], text=True, capture_output=True)
    assert run.returncode == 0, run.stdout + run.stderr


def test_the_inputs_the_frame_and_spacer_share_say_the_same():
    # both parts declare the cell's and the spring's inputs, for each one's Customizer; they must not drift apart
    params = json.loads((ROOT / "configurator/params.json").read_text())
    frame = {p["name"]: p for p in params["frame"]}
    shared = [p for p in params["spacer"] if p["name"] in frame]
    assert len(shared) >= 12
    for p in shared:
        if p["name"] == "CELL":   # the spacer's caption leaves out the length, which it doesn't use
            p, f = {**p, "caption": None}, {**frame["CELL"], "caption": None}
        else:
            f = frame[p["name"]]
        assert p == f, p["name"]
