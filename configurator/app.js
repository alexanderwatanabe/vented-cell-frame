// SPDX-License-Identifier: CERN-OHL-S-2.0
// The configurator: a form built from the parts' Customizer sections (params.json) and the presets
// (presets/cells.json). Each change is checked in OpenSCAD (WebAssembly, in a worker) without drawing the part;
// Render draws it, shows it and offers the STL. Only the values the user sets are passed, as -D, so every default
// comes from the .scad files themselves.

import { createViewer } from "./viewer.js";

const OPENSCAD = "https://cdn.jsdelivr.net/npm/openscad-playground@2.4.0/dist/wasm/";
const PENDING_CUE_MS = 400;   // a check that answers sooner shows no in-flight cue, so a fast answer doesn't strobe
const COUPON_SPACING = 5;     // mm between coupons on the plate, as tools/coupon_set.py lays them

// The steps, in the order a build takes them. Each draws one part; the values set are shared by all of them.
const STEPS = {
  coupons: {
    file: "frame", part: "coupon", params: "frame", label: "Coupon set", render: "Render coupon set",
    hide: ["CELL_COLUMNS", "CELL_ROWS", "FIT_OFFSET"],
    groups: ["Cell", "Block", "Grip"],
    intro: "Print this first. Each coupon is a 2 × 2 corner of the frame, with its fit offset printed on its tab. "
      + "Push four of your cells into each: the right one takes a firm push and doesn't wobble. "
      + "Enter its offset as Fit offset on the Frame step.",
  },
  frame: {
    file: "frame", part: "frame", params: "frame", label: "Frame", render: "Render frame", hide: [],
    intro: "The frame holds the block's edge cells and vents its walls. Choose the cell and the block, then shape the "
      + "vents: the wall map updates as you go. Render to see the frame in 3D and download it.",
  },
  spacer: {
    file: "spacer", params: "spacer", label: "Spacers", render: "Render spacer", hide: [],
    intro: "Loose spacers grip the cells inside the block, one in each diagonal gap where four cells meet, near each end.",
  },
};
const ADVANCED = ["Grip", "Vent limits", "Frame details"];
const SLIDERS = ["Vents"];

const RESULTS = {   // [section, key, label, format, explanation]
  FRAME: [
    ["Size", "footprint", "Footprint", (v) => `${fmt(v[0])} × ${fmt(v[1])} mm`, "Outside, at the bumps"],
    ["Size", "height", "Height", (v) => `${fmt(v)} mm`, "Along the cells, as printed"],
    ["Size", "pitch", "Pitch", (v) => `${fmt(v)} mm`, "Centre to centre of neighbouring cells"],
    ["Size", "cell_fit", "Cell, as the grip sees it", (v) => `${fmt(v)} mm`, "The diameter plus the fit offset"],
    ["Grip", "grip", "Grip", (v) => (v === "gap" ? "in the gaps between cells" : "on the wall"), "Where the bow springs sit"],
    ["Grip", "bow_span", "Bow span", (v) => `${fmt(v)} mm`, "8 mm is tested"],
    ["Grip", "bows_per_band", "Bows per band", (v) => v, "A band near each end"],
    ["Vents", "open_share", "Wall open", (v) => `${Math.round(v * 100)} %`, "Between the bands of bows"],
    ["Vents", "vent_tallest", "Tallest vent", (v) => `${fmt(v)} mm`, ""],
    ["Vents", "vent_widest", "Widest vent", (v) => `${fmt(v)} mm`, ""],
    ["Vents", "vent_bridge", "Widest vent top", (v) => `${fmt(v)} mm`, "1 mm below a vent's top: what the printer bridges"],
    ["Vents", "up_waves", "Waves up the frame", (v) => v, "Each crest is a line of contact on the cells"],
    ["Vents", "tie_shortest", "Shortest tie", (v) => `${fmt(v)} mm`, "Solid between two vents one above the other"],
    ["Vents", "column_narrowest", "Narrowest column", (v) => `${fmt(v)} mm`, "Solid between two vents side by side"],
    ["Vents", "steepest", "Steepest overhang", (v) => `${fmt(v)}°`, "Either face; 45° prints without support"],
  ],
  SPACER: [
    ["Size", "height", "Height", (v) => `${fmt(v)} mm`, ""],
    ["Size", "across_arms", "Across the arms", (v) => `${fmt(v)} mm`, ""],
    ["Size", "pitch", "Pitch", (v) => `${fmt(v)} mm`, ""],
    ["Grip", "bow_span", "Bow span", (v) => `${fmt(v)} mm`, "8 mm is tested"],
    ["Grip", "neck", "Thinnest neck", (v) => `${fmt(v)} mm`, ""],
    ["Grip", "tilt_deg_max", "Most it can tilt", (v) => `${fmt(v)}°`, ""],
  ],
};

// What to try when a design is refused: the assert's words, and the fields that change it.
const HINTS = [
  [/past 45/, "Lengthen the wave spacing, make the troughs shallower, lower Mirror, or use fewer waves per cell.",
    ["UP_WAVELENGTH", "TROUGH_DEPTH", "MIRROR", "WAVES_PER_CELL"]],
  [/shortest tie/, "Lengthen the wave spacing, or make the troughs shallower.", ["UP_WAVELENGTH", "TROUGH_DEPTH", "TIE_MIN"]],
  [/narrowest column/, "Raise Along share, or use fewer waves per cell.", ["ALONG_SHARE", "WAVES_PER_CELL", "COLUMN_MIN_SHARE"]],
  [/come apart/, "Raise Along share, or stagger the vents, so they don't join up round the frame.", ["ALONG_SHARE", "STAGGER"]],
  [/bridge it/, "Use 2 waves per cell with a lower Mirror, or a shorter wave spacing; or raise the limit if your printer bridges further.",
    ["WAVES_PER_CELL", "MIRROR", "UP_WAVELENGTH", "BRIDGE_MAX"]],
  [/of the wall opens|never pass the datum/, "Deepen the troughs, or raise Mirror. Short cells leave little room for vents.",
    ["TROUGH_DEPTH", "MIRROR", "OPEN_SHARE_MIN"]],
  [/too short for its vents/, "These cells are too short for vents between the bands.", ["BAND_H", "END_CLR"]],
  [/bigger than the printer/, "Use fewer cells, or set your printer's size.", ["CELL_COLUMNS", "CELL_ROWS", "PRINTER_SIZE"]],
  [/must be even/, "Use a stagger of 0 or 0.5, or a block whose columns and rows add up to an even number.",
    ["STAGGER", "CELL_COLUMNS", "CELL_ROWS"]],
  [/would overlap/, "Widen the gap between cells, or check the pitch and fit offset.", ["CELL_GAP", "PITCH", "FIT_OFFSET"]],
  [/gap between edge cells holds a bow/, "Use the wall grip, or widen the gap between cells.", ["GRIP", "CELL_GAP", "PITCH"]],
  [/diagonal gap holds a bow/, "Spacers need a wider gap between cells: widen it, or rely on the frame alone.", ["CELL_GAP", "PITCH"]],
  [/the bows are .* under BOW_SPAN_MIN/, "Lengthen the bows, or lower the shortest allowed.", ["BOW_SPAN", "BOW_SPAN_MIN"]],
  [/pockets reach within/, "Thicken the wall.", ["WALL_T"]],
  [/needs its (length|diameter)/, "Enter the cell's diameter and length.", ["CELL_D", "CELL_L"]],
];

const fmt = (x) => (Number.isInteger(x) ? String(x) : x.toFixed(2).replace(/\.?0+$/, ""));
const $ = (sel) => document.querySelector(sel);
const el = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) e.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat()) if (kid != null && kid !== false) e.append(kid);
  return e;
};
// A caption is "Label (unit) — explanation".
function caption(p) {
  const [label, ...rest] = p.caption.split(" — ");
  return rest.length ? { label, help: rest.join(" — ") } : { label: p.name, help: p.caption };
}

// ---- state: the step, the values set (as typed, shared by every step), the coupon set's spread. Kept in the URL.
const SPREAD = { centre: "", step: "0.2", count: "3" };
const state = { step: "coupons", set: {}, coupons: { ...SPREAD } };
function readHash() {
  const q = new URLSearchParams(location.hash.slice(1));
  if (STEPS[q.get("step")]) state.step = q.get("step");
  for (const [k, v] of q) {
    if (k === "step") continue;
    if (k.startsWith("coupons.")) state.coupons[k.slice(8)] = v;
    else state.set[k] = v;
  }
}
function writeHash() {
  const q = new URLSearchParams({ step: state.step, ...state.set });
  for (const [k, v] of Object.entries(state.coupons)) if (v !== SPREAD[k]) q.set("coupons." + k, v);
  history.replaceState(null, "", "#" + q);
}

let PARAMS, CELLS;
const paramsOf = (step) => PARAMS[STEPS[step].params];
const initial = (name) => PARAMS.frame.concat(PARAMS.spacer).find((p) => p.name === name)?.initial;
const valueOf = (name) => state.set[name] ?? initial(name);

// The -D values for a step: only what the user set and the step uses, numbers as typed, strings as OpenSCAD
// literals. A number that doesn't parse is left out, its field marked.
function defines(step, extra = {}) {
  const params = Object.fromEntries(paramsOf(step).map((p) => [p.name, p]));
  const out = STEPS[step].part ? { PART: JSON.stringify(STEPS[step].part) } : {};
  for (const [name, value] of Object.entries(state.set)) {
    const p = params[name];
    if (!p || value === "" || STEPS[step].hide.includes(name)) continue;
    if (p.type === "string") out[name] = JSON.stringify(String(value));
    else if (Number.isFinite(Number(value))) out[name] = String(Number(value));
  }
  for (const [name, value] of Object.entries(extra)) out[name] = value;
  return out;
}

// The coupon set's offsets: centre, step and count from the form.
function couponOffsets() {
  const centre = Number(state.coupons.centre || 0), step = Number(state.coupons.step || 0.2);
  const count = Math.max(1, Math.min(9, Math.round(Number(state.coupons.count || 3))));
  return Array.from({ length: count }, (_, k) => Math.round((centre + (k - (count - 1) / 2) * step) * 1e4) / 1e4);
}

// ---- the form
function buildForm() {
  const form = $("#form");
  const open = new Set([...form.querySelectorAll("details[open]")].map((d) => d.dataset.group));
  const keep = form.childElementCount > 0;
  form.replaceChildren();
  const step = STEPS[state.step];
  $("#intro").textContent = step.intro + (state.step === "spacer" ? spacerCount() : "");
  const groups = new Map();
  for (const p of paramsOf(state.step)) {
    if (step.hide.includes(p.name) || (step.groups && !step.groups.includes(p.group))) continue;
    if (!groups.has(p.group)) groups.set(p.group, []);
    groups.get(p.group).push(p);
  }
  if (state.step === "coupons") form.append(spreadSection());
  for (const [group, params] of groups) {
    const advanced = ADVANCED.includes(group);
    form.append(el("details", { class: "group" + (advanced ? " advanced" : ""), open: keep ? open.has(group) : !advanced, "data-group": group },
      el("summary", {}, group, advanced ? el("span", { class: "tag" }, "advanced") : null),
      ...params.map((p) => field(p, SLIDERS.includes(group)))));
  }
  form.append(el("button", { type: "button", class: "quiet", onclick: () => {
    state.set = {}; state.coupons = { ...SPREAD }; buildForm(); changed();
  } }, "Reset everything to the defaults"));
}

function spacerCount() {
  const columns = Number(valueOf("CELL_COLUMNS")), rows = Number(valueOf("CELL_ROWS"));
  return ` A ${columns} × ${rows} block needs ${2 * (columns - 1) * (rows - 1)}.`;
}

function spreadSection() {
  const num = (key, label, help, attrs) => el("label", { class: "field" },
    el("span", { class: "label" }, label),
    el("input", { type: "number", value: state.coupons[key], ...attrs, oninput: (e) => { state.coupons[key] = e.target.value; changed(); } }),
    el("span"),
    el("span", { class: "help" }, help));
  return el("details", { class: "group", open: true, "data-group": "Fit offsets" }, el("summary", {}, "Fit offsets to print"),
    num("centre", "Middle offset (mm)", "0 to start; to refine, the best coupon's offset", { step: 0.05, placeholder: "0" }),
    num("step", "Step (mm)", "between coupons: 0.2 to start, 0.05 to refine", { step: 0.05, min: 0.01 }),
    num("count", "Coupons", "on one plate", { step: 1, min: 1, max: 9 }));
}

function field(p, slider) {
  const { label, help } = caption(p);
  const value = state.set[p.name] ?? "";
  const set = (v) => {
    if (v === "" || v == null || v === String(p.initial)) delete state.set[p.name]; else state.set[p.name] = v;
    changed();
  };
  let input;
  let range = null;
  if (p.name === "CELL") {
    input = el("select", { "aria-label": label, onchange: (e) => { set(e.target.value); buildForm(); } },
      ...CELLS.map((c) => el("option", { value: c.name, selected: (value || String(p.initial)) === c.name }, c.name)),
      el("option", { value: "custom", selected: value === "custom" }, "custom"));
  } else if (p.options) {
    const opts = [...new Set(p.options.map((o) => String(o.value)))];
    input = el("select", { "aria-label": label, onchange: (e) => set(e.target.value) },
      ...opts.map((o) => el("option", { value: o, selected: (value || String(p.initial)) === o }, o)));
  } else if (p.type === "number") {
    const box = el("input", { type: "number", value, placeholder: placeholder(p), min: p.min, max: p.max, step: p.step,
      "aria-label": label, oninput: (e) => { set(e.target.value); if (range) range.value = e.target.value || p.initial; } });
    if (slider && p.min != null) {
      range = el("input", { type: "range", min: p.min, max: p.max, step: p.step, value: value || p.initial,
        "aria-hidden": "true", tabindex: -1, oninput: (e) => { box.value = e.target.value; set(e.target.value); } });
    }
    input = range ? el("span", { class: "pair" }, range, box) : box;
  } else {
    input = el("input", { type: "text", value, placeholder: String(p.initial), "aria-label": label, oninput: (e) => set(e.target.value) });
  }
  const reset = el("button", { type: "button", class: "reset", title: "Back to the default", "aria-label": `Reset ${label}`,
    onclick: () => { delete state.set[p.name]; buildForm(); changed(); } }, "↺");
  const row = el("div", { class: "field" + (value !== "" ? " set" : ""), id: "f-" + p.name, "data-name": p.name },
    el("span", { class: "label" }, label, el("code", { title: "Its name in the .scad file, for -D on the command line" }, p.name)),
    input, reset, el("span", { class: "help" }, help));
  if (p.name === "CELL") row.append(cellNote(value || String(p.initial)));
  return row;
}

function placeholder(p) {
  if (["CELL_D", "CELL_L"].includes(p.name)) return "preset";
  if (p.name === "PITCH") return "d + gap";
  return fmt(p.initial);
}

function cellNote(name) {
  const c = CELLS.find((x) => x.name === name);
  if (!c) return el("span", { class: "note" }, "Enter the cell's diameter and length below.");
  return el("span", { class: "note" }, el("strong", {}, `${fmt(c.diameter)} × ${fmt(c.length)} mm. `), `${c.basis}. `,
    c.datasheet ? el("a", { href: c.datasheet, target: "_blank", rel: "noopener" }, "Datasheet") : "No datasheet found",
    c.verified ? "." : ". Check it against your cells' own.");
}

function focusField(name) {
  const row = document.getElementById("f-" + name);
  if (!row) return;
  row.closest("details").open = true;
  row.scrollIntoView({ behavior: "smooth", block: "center" });
  row.classList.remove("flash");
  void row.offsetWidth;
  row.classList.add("flash");
  row.querySelector("input:not([type=range]), select")?.focus({ preventScroll: true });
}
function fieldLabel(name) {
  const p = paramsOf(state.step).find((x) => x.name === name);
  return p ? caption(p).label.replace(/\s*\([^)]*\)$/, "") : null;   // without its unit, to read inside a sentence
}

// ---- the page's files. Served, it fetches them; built into one file (tools/build_page.py), they are in VCF_EMBED.
const EMBED = globalThis.VCF_EMBED;
const SOURCES = ["frame.scad", "spacer.scad", "lib/grip.scad", "lib/cells.scad"];
async function loadFiles() {
  if (EMBED) {
    const font = Uint8Array.from(atob(EMBED.font), (c) => c.charCodeAt(0));
    return { params: EMBED.params, cells: EMBED.cells, sources: EMBED.sources, font };
  }
  const text = async (p) => [p, await (await fetch("../" + p, { cache: "no-cache" })).text()];
  const [params, cells, sources, font] = await Promise.all([
    fetch("params.json").then((r) => r.json()),
    fetch("../presets/cells.json").then((r) => r.json()),
    Promise.all(SOURCES.map(text)),
    fetch("fonts/NotoSans-Regular.ttf").then((r) => r.arrayBuffer()).then((b) => new Uint8Array(b)),
  ]);
  return { params, cells, sources, font };
}

// ---- OpenSCAD in workers: one for checks, one for renders. A newer check replaces an older one outright.
let wasm, wasmBytes, files, workerUrl;
// From a file the page's origin is opaque, and a compiled module can't cross to a worker: send the bytes instead.
const FROM_FILE = location.protocol === "file:";
function spawn() {
  workerUrl ??= EMBED ? URL.createObjectURL(new Blob([EMBED.worker], { type: "text/javascript" })) : new URL("./worker.js", import.meta.url);
  // a classic worker: a page opened from a file can start one from a blob, though not a module worker
  const w = new Worker(workerUrl);
  w.postMessage({ kind: "init", wasm: FROM_FILE ? wasmBytes.slice(0) : wasm, openscadUrl: OPENSCAD + "openscad.js",
    sources: files.sources, font: files.font });
  return w;
}
// One job on a worker. It settles with the worker's answer, or with an error if the worker fails or is stopped.
function job(worker, msg) {
  return new Promise((resolve) => {
    const id = crypto.randomUUID();
    const done = (result) => {
      worker.removeEventListener("message", onMessage);
      worker.removeEventListener("error", onError);
      worker.removeEventListener("messageerror", onError);
      worker.settle = null;
      resolve(result);
    };
    const onMessage = ({ data }) => { if (data.id === id) done(data); };
    const onError = (e) => done({ id, error: `OpenSCAD's worker failed: ${e.message || "no message"}` });
    worker.addEventListener("message", onMessage);
    worker.addEventListener("error", onError);
    worker.addEventListener("messageerror", onError);
    worker.settle = () => done({ id, error: "stopped" });
    worker.postMessage({ id, ...msg });
  });
}
function stop(worker) {
  if (!worker) return;
  worker.terminate();
  worker.settle?.();
}

function parseEcho(text, name) {
  const m = text.match(new RegExp(`^ECHO: ${name} = (.+)$`, "m"));
  if (!m) return null;
  try { return Object.fromEntries(JSON.parse(m[1].replace(/\bundef\b/g, "null"))); } catch { return null; }
}
function refusals(text) {
  const out = [];
  for (const m of text.matchAll(/^ERROR: Assertion .*? failed: "(.*)" in file/gm)) out.push(m[1]);
  for (const m of text.matchAll(/^(ERROR: (?!Assertion).*)$/gm)) out.push(m[1]);
  for (const m of text.matchAll(/^WARNING: (.*)$/gm)) out.push(m[1]);
  return [...new Set(out)];
}

// The check: the step's part, echo only. A coupon set checks each of its offsets, and reports the first refused.
let checker, checkSeq = 0;
async function check() {
  const seq = ++checkSeq;
  if (checker?.busy) { stop(checker); checker = null; }   // a check still running for older values: drop it
  checker ??= spawn();
  checker.busy = true;
  const cue = setTimeout(() => seq === checkSeq && setCheck("pending"), PENDING_CUE_MS);
  const step = state.step, name = step === "spacer" ? "SPACER" : "FRAME";
  const runs = step === "coupons" ? couponOffsets().map((o) => ({ FIT_OFFSET: String(o) })) : [{}];
  let values = null, map = null, bad = [], ms = 0, failure = null;
  const shown = Math.floor((runs.length - 1) / 2);   // the results shown are the middle coupon's
  for (const [n, extra] of runs.entries()) {
    const res = await job(checker, { kind: "check", part: STEPS[step].file, defines: defines(step, extra) });
    if (seq !== checkSeq) return;   // a newer change took over
    if (res.error) { failure = res.error; break; }
    ms += res.ms;
    const text = res.echo + "\n" + res.log.join("\n");
    bad = refusals(text);
    if (bad.length) {
      if (extra.FIT_OFFSET) bad = bad.map((m) => `at fit offset ${extra.FIT_OFFSET}: ${m}`);
      break;
    }
    if (!parseEcho(text, name)) { failure = "OpenSCAD gave no result"; break; }
    if (n === shown) {
      values = parseEcho(text, name);
      map = step === "frame" ? parseEcho(text, "WALL_MAP") : null;
    }
  }
  clearTimeout(cue);
  if (seq !== checkSeq) return;
  checker.busy = false;
  if (failure) { showResults(null); return setCheck("failed", [failure]); }
  if (bad.length) return setCheck("refused", bad);
  showResults(values, name, map);
  setCheck("ok", [], ms);
}

function setCheck(status, messages = [], ms) {
  const box = $("#check");
  box.dataset.status = status;
  const head = {
    pending: "Checking…",
    ok: `Printable: every check passes${ms >= 100 ? ` (checked in ${(ms / 1000).toFixed(1)} s)` : ""}`,
    refused: "Not printable as set",
    failed: "The check didn't run",
  }[status];
  box.classList.remove("stale");
  box.replaceChildren(el("strong", {}, head));
  if (messages.length) box.append(el("ul", {}, ...messages.map((m) => el("li", {}, linkify(m), hintFor(m)))));
  $("#results").classList.toggle("stale", status === "pending");
  if (status === "refused") $("#results").replaceChildren(el("p", { class: "muted" }, "Sizes and the wall map show once the design is printable."));
}

// Field names in a message become links to their fields, where the step shows them.
function linkify(text) {
  const names = [...document.querySelectorAll(".field[data-name]")].map((f) => f.dataset.name).sort((a, b) => b.length - a.length);
  if (!names.length) return [text];
  const parts = text.split(new RegExp(`\\b(${names.join("|")})\\b`));
  return parts.map((s, i) => (i % 2 ? fieldLink(s) : s));
}
function fieldLink(name) {
  return el("button", { type: "button", class: "link", onclick: () => focusField(name) }, fieldLabel(name) || name);
}
function hintFor(message) {
  const hit = HINTS.find(([re]) => re.test(message));
  if (!hit) return null;
  const fields = hit[2].filter((n) => document.getElementById("f-" + n));
  return el("div", { class: "hint" }, hit[1], fields.length ? " Go to: " : "",
    ...fields.flatMap((n, i) => [i ? ", " : "", fieldLink(n)]));
}

function showResults(values, name, map) {
  const box = $("#results");
  box.replaceChildren();
  if (!values) return;
  if ("steepest_inside_deg" in values) values.steepest = Math.max(values.steepest_inside_deg, values.steepest_outside_deg);
  const skip = values.part === "coupon" ? ["Vents"] : [];   // a coupon is one band deep: it has no vents
  const sections = new Map();
  for (const [section, key, label, f, why] of RESULTS[name]) {
    if (skip.includes(section) || !(key in values)) continue;
    if (!sections.has(section)) sections.set(section, []);
    sections.get(section).push(el("tr", { title: why }, el("th", {}, label), el("td", {}, f(values[key]))));
  }
  for (const [section, rows] of sections) {
    const block = el("section", { class: "result" }, el("h3", {}, section), el("table", {}, ...rows));
    if (section === "Vents" && map) block.append(wallMap(map));
    box.append(block);
  }
}

// The wall unrolled: along it across, up the frame upward, two repeats of its pattern. A value is the wall's thickness:
// 0 a vent, left empty; negative where the wall touches the cells. The wall is shaded darker where it is thicker.
function wallMap({ ds, dz, pitch, rows }) {
  const cols = rows[0].length, repeats = 2, tick = 3;   // mm of tick under the map
  const width = cols * ds * repeats, height = rows.length * dz;
  const scale = Math.min(300 / width, 300 / (height + tick));
  const ratio = window.devicePixelRatio || 1;
  const canvas = el("canvas", { role: "img", "aria-label": "The wall unrolled: vents and solid, two repeats of the pattern" });
  canvas.style.width = `${width * scale}px`;
  canvas.style.height = `${(height + tick) * scale}px`;
  canvas.width = Math.round(width * scale * ratio);
  canvas.height = Math.round((height + tick) * scale * ratio);
  const g = canvas.getContext("2d");
  g.setTransform(scale * ratio, 0, 0, -scale * ratio, 0, height * scale * ratio);   // mm, z up, the map above the ticks
  const css = getComputedStyle(document.documentElement);
  const wall = css.getPropertyValue("--accent").trim(), touch = css.getPropertyValue("--ink").trim();
  const thickest = Math.max(...rows.flat().map(Math.abs));
  for (let r = 0; r < rows.length; r++) for (let rep = 0; rep < repeats; rep++) for (let c = 0; c < cols; c++) {
    const v = rows[r][c];
    if (v === 0) continue;   // a vent: leave it empty
    g.fillStyle = v < 0 ? touch : wall;
    g.globalAlpha = v < 0 ? 0.85 : 0.3 + 0.65 * (v / thickest);
    g.fillRect((rep * cols + c) * ds, r * dz, ds + 0.05, dz + 0.05);
  }
  g.globalAlpha = 1;
  g.strokeStyle = touch;
  g.lineWidth = 1 / scale;
  for (let x = 0; x <= width + 1e-6; x += pitch) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, -tick); g.stroke(); }
  return el("figure", { class: "wallmap" }, canvas,
    el("figcaption", {}, "The wall unrolled, to scale, as printed: ",
      el("span", { class: "key wall" }), " wall, darker where thicker; ", el("span", { class: "key touch" }),
      " touches the cells; gaps are vents. Ticks under it mark each cell's middle."));
}

// ---- rendering. A render takes its settings and its file's name when it starts; changing the form meanwhile marks
// the view out of date but never mixes settings into it.
let renderer, viewer, rendering = null, lastStl = null, renderedFor = null, renderedName = "";
async function render() {
  if (rendering) { cancelRender("Cancelled"); return; }
  const step = state.step;
  const plan = {
    step, key: location.hash, name: fileName(step),
    jobs: step === "coupons"
      ? couponOffsets().map((o) => ({ offset: o, defines: defines(step, { FIT_OFFSET: String(o) }) }))
      : [{ defines: defines(step) }],
    plate: Number(valueOf("PRINTER_SIZE")),
    t0: performance.now(), progress: "Rendering…",
  };
  rendering = plan;
  renderer = spawn();
  $("#render").textContent = "Cancel";
  const tickStatus = () => setRender("pending", `${plan.progress} ${Math.round((performance.now() - plan.t0) / 1000)} s`);
  plan.timer = setInterval(tickStatus, 1000);
  tickStatus();
  try {
    const parts = [];
    for (const [k, j] of plan.jobs.entries()) {
      if (plan.jobs.length > 1) plan.progress = `Rendering coupon ${k + 1} of ${plan.jobs.length} (fit offset ${j.offset >= 0 ? "+" : ""}${j.offset})…`;
      tickStatus();
      const res = await job(renderer, { kind: "render", part: STEPS[step].file, defines: j.defines });
      if (rendering !== plan) return;   // cancelled
      if (res.error) throw new Error(res.error);
      if (!res.ok) throw new Error(refusals(res.log.join("\n")).join("; ") || "OpenSCAD drew nothing");
      parts.push(res.stl);
    }
    lastStl = parts.length > 1 ? mergeStl(parts, plan.plate) : parts[0];
    renderedFor = plan.key;
    renderedName = plan.name;
    viewer.show(lastStl);
    $("#empty").hidden = true;
    setRender("done", `Rendered in ${Math.round((performance.now() - plan.t0) / 1000)} s`);
  } catch (e) {
    if (rendering === plan) setRender("failed", String(e.message || e));
  } finally {
    if (rendering === plan) finishRender();
  }
}
function finishRender() {
  if (rendering) clearInterval(rendering.timer);
  rendering = null;
  stop(renderer);
  renderer = null;
  $("#render").textContent = STEPS[state.step].render;
  updateStale();
}
function cancelRender(text) {
  if (!rendering) return;
  finishRender();
  setRender("idle", text);
}

// Lay coupons out in rows no wider than the plate, as tools/coupon_set.py does, and join them into one binary STL.
function mergeStl(buffers, plate) {
  const meshes = buffers.map((b) => {
    const v = new DataView(b), n = v.getUint32(80, true);
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (let i = 0; i < n; i++) for (let j = 0; j < 3; j++) {
      const o = 84 + 50 * i + 12 + 12 * j, x = v.getFloat32(o, true), y = v.getFloat32(o + 4, true);
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    }
    return { v, n, x0, y0, w: x1 - x0, h: y1 - y0 };
  });
  let x = 0, y = 0, rowH = 0, width = 0;
  for (const m of meshes) {
    if (x > 0 && x + m.w > plate) { x = 0; y += rowH + COUPON_SPACING; rowH = 0; }
    m.dx = x - m.x0; m.dy = y - m.y0;
    x += m.w + COUPON_SPACING; rowH = Math.max(rowH, m.h); width = Math.max(width, x - COUPON_SPACING);
  }
  if (Math.max(width, y + rowH) > plate) throw new Error(`the set won't fit a ${plate} mm plate: print fewer coupons`);
  const total = meshes.reduce((s, m) => s + m.n, 0);
  const out = new DataView(new ArrayBuffer(84 + 50 * total));
  out.setUint32(80, total, true);
  let o = 84;
  for (const m of meshes) for (let i = 0; i < m.n; i++, o += 50) {
    const src = 84 + 50 * i;
    for (let k = 0; k < 12; k++) {
      let f = m.v.getFloat32(src + 4 * k, true);
      if (k >= 3) f += (k % 3 === 0 ? m.dx : k % 3 === 1 ? m.dy : 0);
      out.setFloat32(o + 4 * k, f, true);
    }
  }
  return out.buffer;
}

function fileName(step) {
  const cell = valueOf("CELL");
  if (step === "frame") return `frame-${cell}-${valueOf("CELL_COLUMNS")}x${valueOf("CELL_ROWS")}.stl`;
  return step === "coupons" ? `coupons-${cell}.stl` : `spacer-${cell}.stl`;
}
function setRender(status, text = "") {
  const box = $("#render-status");
  box.dataset.status = status;
  box.textContent = text;
  const dl = $("#download");
  dl.disabled = !lastStl;
  dl.textContent = lastStl ? `Download ${renderedName}` : "Download STL";
}
function updateStale() {
  const stale = Boolean(lastStl) && renderedFor !== location.hash;
  $("#viewer").classList.toggle("stale", stale);
  $("#stale-note").hidden = !stale;
}
function download() {
  if (!lastStl) return;
  const a = el("a", { href: URL.createObjectURL(new Blob([lastStl], { type: "model/stl" })), download: renderedName });
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}

// ---- wiring
let debounce;
function changed() {
  writeHash();
  updateStale();
  for (const f of document.querySelectorAll(".field[data-name]")) {
    const v = state.set[f.dataset.name];
    f.classList.toggle("set", v !== undefined);
    const p = paramsOf(state.step).find((x) => x.name === f.dataset.name);
    f.classList.toggle("invalid", p?.type === "number" && v !== undefined && v !== "" && !Number.isFinite(Number(v)));
  }
  if (state.step === "spacer") $("#intro").textContent = STEPS.spacer.intro + spacerCount();
  // what is shown no longer matches the form: dim it at once; the check's own cue follows if it takes a while
  checkSeq++;
  $("#check").classList.add("stale");
  $("#results").classList.add("stale");
  clearTimeout(debounce);
  debounce = setTimeout(check, 300);
}

function showStep(key) {
  if (rendering && rendering.step !== key) cancelRender("Cancelled: you changed step");
  state.step = key;
  for (const b of document.querySelectorAll("#steps button")) b.setAttribute("aria-current", String(b.dataset.step === key));
  $("#render").textContent = rendering ? "Cancel" : STEPS[key].render;
  buildForm();
  changed();
}

async function main() {
  readHash();
  const [loaded, wasmModule] = await Promise.all([
    loadFiles(),
    FROM_FILE
      ? fetch(OPENSCAD + "openscad.wasm").then((r) => r.arrayBuffer()).then((b) => { wasmBytes = b; return null; })
      : WebAssembly.compileStreaming(fetch(OPENSCAD + "openscad.wasm")).catch(async () =>
        WebAssembly.compile(await (await fetch(OPENSCAD + "openscad.wasm")).arrayBuffer())),
  ]);
  files = loaded;
  const { params, cells } = loaded;
  PARAMS = params;
  CELLS = cells.cells;
  for (const q of [...params.frame, ...params.spacer]) if (state.set[q.name] === String(q.initial)) delete state.set[q.name];
  wasm = wasmModule;
  viewer = createViewer($("#viewer"));
  Object.entries(STEPS).forEach(([key, s], i) => $("#steps").append(
    el("button", { type: "button", "data-step": key, onclick: () => showStep(key) }, el("span", { class: "num" }, String(i + 1)), s.label)));
  $("#render").addEventListener("click", render);
  $("#download").addEventListener("click", download);
  setRender("idle");
  showStep(state.step);
}

main().catch((e) => setCheck("failed", [String(e)]));
