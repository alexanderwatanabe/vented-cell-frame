# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Every preset evaluates headless, as a frame in an array that fits the printer, a coupon and, where its gap holds a
bow, a spacer; and the generated preset files match presets/cells.json."""

import json
import subprocess
import sys

import pytest

from conftest import ROOT, echoed, evaluate, needs_openscad

PRESETS = {c["name"]: c for c in json.loads((ROOT / "presets/cells.json").read_text())["cells"]}
# [NC, NR] that fit the 270 mm printer, and the grip the default gap gives
EXPECT = {
    "18650": ([4, 6], "wall"), "21700": ([4, 6], "wall"), "26650": ([4, 6], "gap"), "32650": ([4, 6], "gap"),
    "32700": ([4, 6], "gap"), "33140": ([4, 6], "gap"), "40135": ([4, 6], "gap"), "4680": ([3, 4], "gap"),
    "66160": ([2, 2], "gap"),
}


def test_every_preset_has_an_expectation():
    assert set(EXPECT) == set(PRESETS)


@needs_openscad
@pytest.mark.parametrize("name", list(EXPECT))
def test_preset_frame(tmp_path, name):
    (nc, nr), grip = EXPECT[name]
    ok, text = evaluate(tmp_path, "frame", CELL=f'"{name}"', NC=nc, NR=nr)
    assert ok, text
    frame = echoed(text, "FRAME")
    assert frame["body"] == [PRESETS[name]["d"], PRESETS[name]["l"]]
    assert frame["grip"] == grip
    assert frame["steepest_deg"] <= 45 and frame["steepest_out_deg"] <= 45 and frame["open_fraction"] > 0


@needs_openscad
@pytest.mark.parametrize("name", list(EXPECT))
def test_preset_coupon(tmp_path, name):
    ok, text = evaluate(tmp_path, "coupon", CELL=f'"{name}"')
    assert ok, text
    assert echoed(text, "FRAME")["cells"] == [2, 2]


@needs_openscad
@pytest.mark.parametrize("name", [n for n, (_, grip) in EXPECT.items() if grip == "gap"])
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
