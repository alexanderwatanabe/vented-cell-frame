# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Build vented-cell-frame.html: the configurator as one file to download and open, with nothing to install or serve.

The configurator's code, its form, the presets, the .scad sources and the labels' font are written into the page;
only OpenSCAD (WebAssembly) and three.js still come from jsDelivr, so it needs a network connection.

    uv run tools/build_page.py           write it
    uv run tools/build_page.py --check   fail if it is stale
"""

import base64
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "configurator"
OUT = ROOT / "vented-cell-frame.html"
SOURCES = ["frame.scad", "spacer.scad", "lib/grip.scad", "lib/cells.scad"]   # as configurator/app.js loads them


def script_safe(text):
    """Text that can sit inside a <script> element: nothing in it may close the element or open a comment, in any
    case. In JSON and in JS strings, "<\\/" reads as "</"."""
    return re.sub(r"</(script)", r"<\\/\1", text, flags=re.I).replace("<!--", "<\\!--")


def build():
    html = (PAGE / "index.html").read_text()
    viewer = (PAGE / "viewer.js").read_text()
    app = (PAGE / "app.js").read_text()
    # one module: the viewer's export becomes a plain declaration, and the app's import of it goes
    viewer = re.sub(r"^export function ", "function ", viewer, flags=re.M)
    app, n = re.subn(r'^import \{ createViewer \} from "\./viewer\.js";\n', "", app, flags=re.M)
    if n != 1:
        raise SystemExit("configurator/app.js: expected one import of ./viewer.js")
    viewer_imports = re.findall(r"^import .*;\n", viewer, flags=re.M)
    viewer = re.sub(r"^import .*;\n", "", viewer, flags=re.M)
    embed = {
        "params": json.loads((PAGE / "params.json").read_text()),
        "cells": json.loads((ROOT / "presets/cells.json").read_text()),
        "sources": [[p, (ROOT / p).read_text()] for p in SOURCES],
        "font": base64.b64encode((PAGE / "fonts/NotoSans-Regular.ttf").read_bytes()).decode(),
        "worker": (PAGE / "worker.js").read_text(),
    }
    data = f"<script>window.VCF_EMBED = {script_safe(json.dumps(embed, separators=(',', ':')))};</script>"
    module = "<script type=\"module\">\n" + script_safe("".join(viewer_imports) + viewer + "\n" + app) + "</script>"
    tag = '<script type="module" src="app.js"></script>'
    if html.count(tag) != 1:
        raise SystemExit(f"configurator/index.html: expected one {tag}")
    banner = ("<!-- Built by tools/build_page.py from configurator/: edit those files, not this one. -->\n"
              "<!-- Noto Sans, embedded for the coupons' labels: SIL Open Font License 1.1 (configurator/fonts/OFL.txt). -->\n")
    html = html.replace("<html lang=\"en\">", banner + "<html lang=\"en\">", 1)
    return html.replace(tag, data + "\n" + module)


def main():
    text = build()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != text:
            raise SystemExit("stale: vented-cell-frame.html: run tools/build_page.py")
        return
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(ROOT)} ({len(text) // 1024} KB)")


if __name__ == "__main__":
    main()
