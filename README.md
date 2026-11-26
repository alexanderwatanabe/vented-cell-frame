# Vented cell frame

A printable frame for a block of cylindrical cells, from 18650 to 66160. Choose a cell and how many columns and rows
of them, and you get an open-ended box the cells stand in, running their full length:

- **It grips every edge cell** with printed bow springs in a band near each end.
- **Its walls are vented.** Between the bands, each wall is a wave that touches each cell along a few lines and opens
  into a pattern of vents, so the frame doesn't trap the cells' heat.
- **It prints standing, without supports.** The walls' faces are held at 45° or less, and every vent's top narrow
  enough to bridge.

The frame grips only the block's edge cells. Loose **gap spacers** hold the cells inside it, one in each diagonal gap
near each end: the default 3 mm gap between cells leaves room for them with every preset. The frame stops 1 mm
short of each end of the cells, so terminals, busbars and nickel strip stay clear.

![The configurator, with a 4 × 6 frame of 21700 cells](docs/configurator.png)

> **Use at your own risk.** Lithium and other battery cells can catch fire, vent or explode. This is a printed
> plastic part, offered with no claims and no warranty, and the author takes no responsibility for what you build
> with it. Read [Safety and no warranty](#safety-and-no-warranty) before you use it.

## Contents

- [The easy way: the page, nothing to install](#the-easy-way-the-page-nothing-to-install)
- [In OpenSCAD: the Customizer](#in-openscad-the-customizer)
- [On the command line](#on-the-command-line)
- [Editing the design](#editing-the-design)
- [Reference](#reference): [the grip](#the-grip), [shaping the vents](#shaping-the-vents),
  [cell presets](#cell-presets), [what gets refused](#what-gets-refused), [printing](#printing)
- [Safety and no warranty](#safety-and-no-warranty)
- [Licence](#licence)

## The easy way: the page, nothing to install

1. **Save [`vented-cell-frame.html`](https://github.com/alexanderwatanabe/vented-cell-frame/raw/main/vented-cell-frame.html)
   to your computer:** right-click the link and choose *Save Link As…* (a plain click shows its source instead). Then
   double-click the saved file. It opens in your browser and runs OpenSCAD inside the page. It needs an internet
   connection, to load OpenSCAD and the 3D viewer.
2. **Step 1, Coupon set: print this first.** Choose your cell and press **Render coupon set**, then **Download**,
   and print the STL. You get three small 2 × 2 corners of the frame, each with a fit offset printed on its tab.
   Push four of your cells into each:
   - **right:** a cell goes in with a firm push and doesn't wobble;
   - **too loose:** it falls out when you turn the coupon over;
   - **too tight:** you can't push it in by hand.

   If none is right, print another set centred on the closest one, with a finer step.
3. **Step 2, Frame.** Enter the best coupon's offset as **Fit offset**, and set **Cell columns** and **Cell rows**.
   Shape the vents if you like: the wall map redraws as you go. The page tells you if a setting can't be printed,
   and what to change. Press **Render frame**, then **Download**, and print it.
4. **Step 3, Spacers.** Render a spacer and print as many as the page says your block needs, for the cells inside
   the block. Narrow the gap between cells and small cells lose the room for them (18650s need 2.6 mm, 21700s
   1.8 mm): the frame's check says so, and the cells inside are then held only by their neighbours and your busbars.

A coupon set renders in about 4 s, and a 4 × 6 frame of 21700s in about 25 s; frames of larger cells take a minute or
two.

## In OpenSCAD: the Customizer

Install an OpenSCAD development snapshot from 2024 or later
(<https://openscad.org/downloads.html#snapshots>): it has the Manifold engine, which renders a frame in seconds.
OpenSCAD 2021.01 can check a design, but takes hours to render one.

Download this repository, open `frame.scad` or `spacer.scad`, and show the Customizer (Window → Customizer). Every
setting is there with the same label and explanation as in the page. Render with F6, then export the STL with F7.

Do the coupon first, as in the page: in `frame.scad`, set **Part** to `coupon`. It makes one coupon at the fit offset
you set, so render a few offsets in turn.

## On the command line

```sh
openscad --backend=manifold -o frame.stl -D 'CELL="21700"' -D CELL_COLUMNS=5 -D CELL_ROWS=4 -D FIT_OFFSET=0.1 frame.scad
openscad --backend=manifold -o coupon.stl -D 'PART="coupon"' -D 'CELL="21700"' -D FIT_OFFSET=0.1 frame.scad
openscad --backend=manifold -o spacer.stl -D 'CELL="21700"' spacer.scad
```

Each setting has a short name for `-D`, shown beside it in the page and the Customizer. The coupon set as one STL
needs Python, run here with [uv](https://docs.astral.sh/uv/):

```sh
uv run tools/coupon_set.py --cell 21700                            # offsets -0.2, 0, +0.2
uv run tools/coupon_set.py --cell 21700 --centre 0.2 --step 0.05   # refine round the best one
```

Give the coupons the same cell, gap or pitch, and grip as the frame you'll print (pass them with `-D`), because a
coupon is a corner of that frame. To keep your settings, make a file of your own: `include <frame.scad>`, then your
values.

The settings most builds change:

| Setting | Name | What it sets |
|---|---|---|
| Cell | `CELL` | A preset (below), or `"custom"` with `CELL_D` and `CELL_L`. |
| Cell columns, cell rows | `CELL_COLUMNS`, `CELL_ROWS` | The block. |
| Fit offset | `FIT_OFFSET` | From the coupon set. |
| Gap between cells | `CELL_GAP` | Between neighbouring cells' bodies: 3 mm by default, room for the spacers with every preset. Down to about 0.8 mm the frame still prints, but small cells' spacers no longer fit. |
| Pitch | `PITCH` | Centre to centre, overriding diameter + gap: set it when your busbars or nickel strip fix it. |
| Grip | `GRIP` | `auto`, `gap` or `wall`; see [the grip](#the-grip). |
| Printer size | `PRINTER_SIZE` | Your printer's build volume, its smallest side. Default 270 mm (Snapmaker U1). |
| Part | `PART` | `frame`, or `coupon` for the calibration coupon. |

## Editing the design

| Path | What it is |
|---|---|
| `frame.scad`, `spacer.scad` | The parts, each with its inputs in Customizer sections at the top. `frame.scad` also draws the coupon (`PART`). |
| `lib/grip.scad` | The bow spring and its pocket, and the cell size and pitch they follow from. |
| `presets/cells.json` | The cell presets: the one place to add or correct a cell. |
| `lib/cells.scad` | The presets for OpenSCAD, generated from `presets/cells.json`. |
| `configurator/` | The page's sources. `params.json` is its form, generated from the parts' Customizer sections. |
| `vented-cell-frame.html` | The page as one file, built from `configurator/` and the files it embeds. |
| `tools/` | The coupon set, the generators, the page's build, the OpenSCAD finder. |
| `tests/` | Headless checks of every part, preset and refusal. |

Every dimension in the parts is a named input with its reason, or follows from one; every rule is an assert. After
changing something, regenerate what follows from it and run the tests:

```sh
uv run tools/gen_cells.py      # after editing presets/cells.json: lib/cells.scad, the dropdowns, the table below
uv run tools/gen_params.py     # after changing a part's Customizer inputs: the page's form
uv run tools/build_page.py     # after changing configurator/, the presets or a part: vented-cell-frame.html
uv run pytest                  # finds OpenSCAD from $OPENSCAD, PATH, or /Applications
python3 -m http.server 8000    # to work on configurator/ itself: open http://localhost:8000/configurator/
```

The generated files are committed, so nobody needs Python to use the design. The tests fail if any of them falls
behind its sources.

## Reference

### The grip

The grip is a bow spring: a thin curved wall in a pocket, rooted at both ends and bulging toward its cell. Its sizes
are millimetres set by the nozzle and the plastic, not by the cell, so they stay the same for every cell. The cell
only sets where the spring sits.

| Grip (`GRIP`) | Where the bows sit |
|---|---|
| `gap` | In each gap between two edge cells, a ridge holds a bow facing each of its cells, as a gap spacer does. The bow is as long as the gap allows, up to `BOW_SPAN` (8 mm), and no shorter than `BOW_SPAN_MIN` (5 mm). |
| `wall` | A pad on the wall in front of each edge cell's middle holds a full 8 mm bow, with the wall behind it. The ridges in the gaps stay, as plain lands. |
| `auto` | `gap` where the gap holds a bow of at least `BOW_SPAN_MIN`, else `wall`. |

At the default 3 mm gap every preset takes the gap grip: an 18650's bow is 5.6 mm, a 21700's 6.8 mm. Packed tighter,
18650 and 21700 take the wall grip, since at 0.8 mm their diagonal gaps hold only a 2.5–3.7 mm bow, too short to
spring; and then no spacer fits, so the cells inside the block are held only by their neighbours.

**Bow press** (`BOW_PRESS`) is how far the bows' faces stand inside the cell at their middle, on diameter: 1.0 mm by
default, as tested. It is measured at the face, so changing the bow's thickness for another nozzle doesn't change it.

**Tested:** the gap grip with an 8 mm bow, on a 33140 cell at a 34 mm pitch. The wall grip, and gap bows shorter than
8 mm (the 26650's is 5.6 mm), are untested. The coupon set is the test, so print it first.

### Shaping the vents

Between the bands, the wall's inside face is two sine waves added together. One runs along the wall, with a crest at
each cell's middle; the other runs up the frame. The outside mirrors the inside about a datum, and the wall opens
wherever the inside passes it.

| Setting | What it changes |
|---|---|
| Waves per cell (`WAVES_PER_CELL`) | How many waves run along the wall per cell. More waves give narrower vents and more of them. |
| Along share (`ALONG_SHARE`) | How the depth is split between the two waves. 0.5 gives round, staggered vents; toward 0.7, the vents join into tall slots; below about 0.35, the columns between vents get too thin. |
| Wave spacing (`UP_WAVELENGTH`) | How far apart the up-the-frame wave's crests stand, rounded to fit a whole number between the bands: shorter for more, shorter vents, longer for fewer, taller ones. Each crest is a line where the wall touches the cell. |
| Trough depth (`TROUGH_DEPTH`) | How deep the troughs are: deeper troughs open bigger vents and leave wider air channels beside the cells. |
| Crest press (`CREST_PRESS`) | How far the crests press into the cell's land, which sets the size of the contact patches. |
| Mirror (`MIRROR`) | How far the outside mirrors the inside: 1 is a full mirror; less gives a thicker wall and smaller vents. |
| Wave phase (`UP_PHASE`) | Where the up-the-frame crests fall: 90° spaces the contact lines evenly between the bands, 0° the vents. |
| Stagger (`STAGGER`) | How far the pattern shifts from one cell to the next: 0.5 staggers the vents like brick bond, 0 lines them up in rows. |

**Large cells.** With one wave per cell, a vent is about half a pitch wide, so past about 40 mm its top is too wide
to bridge (`BRIDGE_MAX`, 10 mm by default). Two waves per cell halve it, and a lower Mirror keeps the outside under 45°:
a 4680 block passes with `WAVES_PER_CELL=2` and `MIRROR=0.75`, a 66160 block with `MIRROR=0.8`. If your printer
bridges further, raise `BRIDGE_MAX` instead.

### Cell presets

Every row is a starting point: check it against the datasheet of the cells you have. To add or correct one, edit
`presets/cells.json` and run `uv run tools/gen_cells.py`.

<!-- presets:begin -->
| Preset | Diameter × length (mm) | Basis | Datasheet |
|---|---|---|---|
| 18650 | 18.5 × 65 (VERIFY) | Samsung INR18650-35E: max 18.55 x 65.25 overall | [link](https://cdn.shopify.com/s/files/1/0613/3327/4870/files/35eDatasheet.pdf) |
| 21700 | 21.2 × 70 (VERIFY) | Samsung INR21700-50E: max 21.25 x 70.8, sleeved | [link](https://static.rapidonline.com/pdf/10-5180_v1.pdf) |
| 26650 | 26 × 65 (VERIFY) | A123 ANR26650M1-B: 25.96 sleeved x 65.15; other makers run to 26.5 | [link](https://bto.pl/files/Karty%20katalogowe/a123%20datasheet_26650m1b.pdf) |
| 32650 | 32.3 × 65 (VERIFY) | no datasheet found | none found |
| 32700 | 32.4 × 70.5 (VERIFY) | LiFePO4 32700 6 Ah (HX-TS-066): 32.4 +-0.3 sleeved x 70.5 +0.4/-0.3 | [link](https://rcscomponents.kiev.ua/datasheets/HX-TS-066_32700.pdf) |
| 33140 | 33.3 × 140.5 (VERIFY) | IFR33140 15 Ah: 33.3 +-0.2 x 140.5 +-0.5; fit-tested: a 33.2 fit (FIT_OFFSET -0.1) | [link](https://www.rcscomponents.kiev.ua/datasheets/IFR33140_C33.pdf) |
| 40135 | 40.2 × 135 (VERIFY) | no datasheet found | none found |
| 4680 | 46 × 80 (VERIFY) | nominal, from teardowns; no datasheet published | none found |
| 66160 | 66 × 160 (VERIFY) | Yinlong LTO 66160 40 Ah: 66 +-1 x 161 +-1 (whether 161 includes the studs is unclear) | [link](https://akkudoktor.net/uploads/short-url/7z7F1IhRYdLJHxtDF272lAQIx4q.pdf) |
<!-- presets:end -->

18650 is the smallest cell supported. A custom cell smaller than that is drawn if it passes the checks, but it is
untested. The frame needs cells about 52–63 mm long or more, depending on the diameter and the grip: a shorter frame
has room only for slivers of vent. 18350, 18500 and sub-C cells are too short.

### What gets refused

A design that breaks a rule stops with a message, rather than drawing a part that can't print or would be weak:

- a face steeper than 45°, which would need support;
- a tie across the wall shorter than `TIE_MIN`, or a column narrower than `COLUMN_MIN_SHARE` of the along-the-wall
  wavelength (`TIE_MIN` at least);
- vents that run all the way round the frame at some height, which would cut it in two;
- a vent whose top, 1 mm below it, is wider than `BRIDGE_MAX`: the bridge the printer would have to span;
- a wall less than `OPEN_SHARE_MIN` open, or a wave that doesn't close evenly round the frame;
- a frame bigger than the printer, or too short for its vents;
- a pitch at which neighbouring cells, or their grips, would overlap;
- a gap grip, or a spacer, where the gap between cells holds no bow; or a bow shorter than `BOW_SPAN_MIN`;
- a wall grip whose pockets leave less than `NECK_MIN` of wall behind them.

The checks sample the walls' faces, the vents and the corners on a fine grid; the tests also render each part and
check that it comes out as one solid of the size it reports.

### Printing

Print standing, with the cells' axis vertical and no supports. The grip was tested in PETG with a 0.4 mm nozzle. The
bows are two lines thick (`BOW_T`); a different nozzle needs `BOW_T`, `NECK_MIN` and `WALL_T` to match. Print the
coupons in the same plastic and on the same printer as the frame.

## Safety and no warranty

This design is shared as it is, for anyone to use at their own risk.

- **No claims.** Nothing here claims the design is fit for any purpose, safe, or able to hold any cell in any use.
  The values, presets and checks are best efforts and may be wrong. Only one cell and one grip have been tried on a
  printer. Check everything against your own cells, printer and plastic.
- **No warranty.** It is provided without warranty of any kind, express or implied, as the licence sets out
  (CERN-OHL-S-2.0, section 6, "Disclaimer and liability").
- **The risk is yours.** Lithium and other battery cells store a great deal of energy, and can short, overheat,
  vent, catch fire or explode. A printed plastic frame does not prevent any of that. It can soften, melt or burn, and
  it insulates nothing. It is not a battery management system, a fuse, a fire enclosure or any other safety device.
  Building, charging, storing or using a battery is your responsibility alone.
- **No liability.** The author takes no responsibility for any damage, injury, fire or loss arising from this design
  or from anything made with it.

If you're not sure what you're doing with battery cells, stop and get advice from someone who is.

## Licence

CERN Open Hardware Licence Version 2, Strongly Reciprocal (`CERN-OHL-S-2.0`); see `LICENSE`. If you distribute a
modified design, or parts made from one, publish your modified source under the same licence.

The page embeds Noto Sans (`configurator/fonts/`, SIL Open Font License 1.1, see `OFL.txt`) for the coupons' labels.
It loads OpenSCAD, which is GPL-2.0-or-later, at run time; OpenSCAD is not part of this repository.
