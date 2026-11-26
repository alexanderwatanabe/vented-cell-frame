// SPDX-License-Identifier: CERN-OHL-S-2.0
// The configurator: a form built from the parts' Customizer sections (params.json) and the presets
// (presets/cells.json). Each change is checked in OpenSCAD (WebAssembly, in a worker) without drawing the part;
// Render draws it, shows it and offers the STL. Only the values the user sets are passed, as -D, so every default
// comes from the .scad files themselves.

import { createViewer } from "./viewer.js";

const OPENSCAD = "https://cdn.jsdelivr.net/npm/openscad-playground@2.4.0/dist/wasm/";
const PENDING_CUE_MS = 400;   // a check that answers sooner shows no in-flight cue, so a fast answer doesn't strobe

// The steps, in the order a build takes them. Each is a part with its own inputs; the values set are shared.
const STEPS = {
  coupons: {
    file: "coupon", params: "frame", label: "Coupon set", render: "Render coupon set",
    hide: ["NC", "NR", "FIT_OFFSET", "PRINT_MAX"],
    groups: ["Cell", "Grip"],
    intro: "Print this first. Each coupon is a 2 × 2 corner of the frame, with its fit offset printed on its tab. "
      + "Push four of your cells into each: the right one takes a firm push and doesn't wobble. "
      + "Enter its offset as Fit offset on the Frame step.",
  },
  frame: {
    file: "frame", params: "frame", label: "Frame", render: "Render frame", hide: [],
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
    ["Size", "size", "Footprint", (v) => `${fmt(v[0])} × ${fmt(v[1])} mm`, "Outside, at the bumps"],
    ["Size", "length", "Height", (v) => `${fmt(v)} mm`, "Along the cells, as printed"],
    ["Size", "pitch", "Pitch", (v) => `${fmt(v)} mm`, "Centre to centre of neighbouring cells"],
    ["Size", "cell_fit", "Cell, as the grip sees it", (v) => `${fmt(v)} mm`, "The diameter plus the fit offset"],
    ["Grip", "grip", "Grip", (v) => (v === "gap" ? "in the gaps between cells" : "on the wall"), "Where the bow springs sit"],
    ["Grip", "bow_span", "Bow length", (v) => `${fmt(v)} mm`, "8 mm is tested"],
    ["Grip", "bows", "Bows", (v) => v, ""],
    ["Vents", "open_fraction", "Wall open", (v) => `${Math.round(v * 100)} %`, "Between the bands of bows"],
    ["Vents", "vent_tallest", "Tallest vent", (v) => `${fmt(v)} mm`, ""],
    ["Vents", "vent_widest", "Widest vent", (v) => `${fmt(v)} mm`, ""],
    ["Vents", "contacts", "Contact lines per cell", (v) => v, "Where the wall touches each edge cell"],
    ["Vents", "tie_shortest", "Shortest tie", (v) => `${fmt(v)} mm`, "Solid between two vents one above the other"],
    ["Vents", "column_narrowest", "Narrowest column", (v) => `${fmt(v)} mm`, "Solid between two vents side by side"],
    ["Vents", "steepest_out_deg", "Steepest overhang", (v) => `${fmt(v)}°`, "45° prints without support"],
  ],
  SPACER: [
    ["Size", "height", "Height", (v) => `${fmt(v)} mm`, ""],
    ["Size", "across_arms", "Across the arms", (v) => `${fmt(v)} mm`, ""],
    ["Size", "pitch", "Pitch", (v) => `${fmt(v)} mm`, ""],
    ["Grip", "bow_span", "Bow length", (v) => `${fmt(v)} mm`, "8 mm is tested"],
    ["Grip", "neck", "Narrowest neck", (v) => `${fmt(v)} mm`, ""],
    ["Grip", "tilt_deg_max", "Most it can tilt", (v) => `${fmt(v)}°`, ""],
  ],
};
const NO_VENTS = ["Vents"];   // a coupon is one band deep: it has no wave

// What to try when a design is refused: the assert's words, and the fields that change it.
const HINTS = [
  [/past 45/, "Lengthen Wave height, make the troughs shallower, or lower Mirror.", ["UP_WAVELENGTH", "CHANNEL", "MIRROR"]],
  [/shortest tie/, "Lengthen Wave height or make the troughs shallower.", ["UP_WAVELENGTH", "CHANNEL", "TIE_MIN"]],
  [/narrowest column/, "Raise Vent shape, or use fewer waves per cell.", ["ALONG_SHARE", "WAVES_PER_CELL", "COLUMN_SHARE"]],
  [/of the wall opens|never passes the datum/, "Deepen the troughs, or raise Mirror. Short cells leave little room for vents.", ["CHANNEL", "MIRROR", "OPEN_MIN"]],
  [/too short for its wave/, "These cells are too short for vents between the bands.", ["BAND_H", "END_CLR"]],
  [/bigger than the printer/, "Use fewer cells, or set your printer's size.", ["NC", "NR", "PRINT_MAX"]],
  [/gap between edge cells holds a bow/, "Use the wall grip, or widen the gap between cells.", ["GRIP", "CELL_GAP", "PITCH"]],
  [/diagonal gap holds a bow/, "Spacers need a wider gap between cells: widen it, or rely on the frame alone.", ["CELL_GAP", "PITCH"]],
  [/custom cell needs/, "Enter the cell's diameter and length.", ["CELL_D", "CELL_L"]],
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

// ---- state: the step, the values set (as typed, shared by every step), the coupon spread. Kept in the URL's hash.
const state = { step: "coupons", set: {}, spread: { centre: "", step: "0.2", count: "3" } };
function readHash() {
  const q = new URLSearchParams(location.hash.slice(1));
  if (STEPS[q.get("step")]) state.step = q.get("step");
  for (const [k, v] of q) {
    if (k === "step") continue;
    if (k.startsWith("set.")) state.spread[k.slice(4)] = v;
    else state.set[k] = v;
  }
}
function writeHash() {
  const q = new URLSearchParams({ step: state.step, ...state.set });
  for (const [k, v] of Object.entries(state.spread)) if (v !== "" && !(k === "step" && v === "0.2") && !(k === "count" && v === "3")) q.set("set." + k, v);
  history.replaceState(null, "", "#" + q);
}

let PARAMS, CELLS;
const paramsOf = (step) => PARAMS[STEPS[step].params];

// The -D values for a step: only what the user set and the step uses, numbers as typed, strings as OpenSCAD literals.
function defines(step, extra = {}) {
  const params = Object.fromEntries(paramsOf(step).map((p) => [p.name, p]));
  const out = {};
  for (const [name, value] of Object.entries(state.set)) {
    const p = params[name];
    if (!p || value === "" || STEPS[step].hide.includes(name)) continue;
    out[name] = p.type === "string" ? JSON.stringify(String(value)) : String(Number(value));
  }
  for (const [name, value] of Object.entries(extra)) out[name] = value;
  return out;
}

// ---- the form
function buildForm() {
  const form = $("#form");
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
    form.append(el("details", { class: "group" + (advanced ? " advanced" : ""), open: !advanced, "data-group": group },
      el("summary", {}, group, advanced ? el("span", { class: "tag" }, "advanced") : null),
      ...params.map((p) => field(p, SLIDERS.includes(group)))));
  }
  form.append(el("button", { type: "button", class: "quiet", onclick: () => { state.set = {}; buildForm(); changed(); } },
    "Reset everything to the defaults"));
}

function spacerCount() {
  const nc = Number(state.set.NC || 4), nr = Number(state.set.NR || 6);
  return ` A ${nc} × ${nr} block needs ${2 * (nc - 1) * (nr - 1)}.`;
}

function spreadSection() {
  const num = (key, label, help, attrs) => el("label", { class: "field" },
    el("span", { class: "label" }, label),
    el("input", { type: "number", value: state.spread[key], ...attrs, oninput: (e) => { state.spread[key] = e.target.value; changed(); } }),
    el("span"),
    el("span", { class: "help" }, help));
  return el("details", { class: "group", open: true }, el("summary", {}, "Fit offsets to print"),
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
  return el("span", { class: "note" }, el("strong", {}, `${fmt(c.d)} × ${fmt(c.l)} mm. `), `${c.basis}. `,
    c.source ? el("a", { href: c.source, target: "_blank", rel: "noopener" }, "Datasheet") : "No datasheet found",
    c.verify ? ". Check it against your cells' own." : ".");
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

// ---- OpenSCAD in workers: one for checks, one for renders. A newer check replaces an older one outright.
let wasm;
function spawn() {
  const w = new Worker(new URL("./worker.js", import.meta.url), { type: "module" });
  w.postMessage({ kind: "init", wasm, openscadUrl: OPENSCAD + "openscad.js" });
  return w;
}
function job(worker, msg) {
  return new Promise((resolve) => {
    const id = crypto.randomUUID();
    const on = ({ data }) => { if (data.id === id) { worker.removeEventListener("message", on); resolve(data); } };
    worker.addEventListener("message", on);
    worker.postMessage({ id, ...msg });
  });
}

function parseEcho(text, name) {
  const m = text.match(new RegExp(`^ECHO: ${name} = (.+)$`, "m"));
  if (!m) return null;
  try { return JSON.parse(m[1].replace(/\bundef\b/g, "null")); } catch { return null; }
}
function refusals(text) {
  const out = [];
  for (const m of text.matchAll(/^ERROR: Assertion .*? failed: "(.*)" in file/gm)) out.push(m[1]);
  for (const m of text.matchAll(/^(ERROR: (?!Assertion).*)$/gm)) out.push(m[1]);
  for (const m of text.matchAll(/^WARNING: (.*)$/gm)) out.push(m[1]);
  return [...new Set(out)];
}

let checker, checkSeq = 0, checkBusy = false;
async function check() {
  const seq = ++checkSeq;
  if (checkBusy) { checker.terminate(); checker = spawn(); }
  checkBusy = true;
  const cue = setTimeout(() => seq === checkSeq && setCheck("pending"), PENDING_CUE_MS);
  const extra = state.step === "coupons" ? { FIT_OFFSET: String(Number(state.spread.centre || 0)) } : {};
  const res = await job(checker, { kind: "check", part: STEPS[state.step].file, defines: defines(state.step, extra) });
  clearTimeout(cue);
  if (seq !== checkSeq) return;   // a newer change took over
  checkBusy = false;
  if (res.error) return setCheck("failed", [res.error]);
  const text = res.echo + "\n" + res.log.join("\n");
  const name = state.step === "spacer" ? "SPACER" : "FRAME";
  const values = parseEcho(text, name);
  showResults(values ? Object.fromEntries(values) : null, name, state.step === "frame" ? parseEcho(text, "WALL_MAP") : null);
  const bad = refusals(text);
  setCheck(bad.length ? "refused" : "ok", bad, res.ms);
}

function setCheck(status, messages = [], ms) {
  const box = $("#check");
  box.dataset.status = status;
  const head = {
    pending: "Checking…",
    ok: `Printable: every check passes${ms ? ` (checked in ${(ms / 1000).toFixed(1)} s)` : ""}`,
    refused: "Not printable as set",
    failed: "The check didn't run",
  }[status];
  box.replaceChildren(el("strong", {}, head));
  if (messages.length) box.append(el("ul", {}, ...messages.map((m) => el("li", {}, linkify(m), hintFor(m)))));
  $("#results").classList.toggle("stale", status === "pending");
  if (status === "refused") $("#results").replaceChildren(el("p", { class: "muted" }, "Sizes and the wall map show once the design is printable."));
}

// Field names in a message become links to their fields.
function linkify(text) {
  const names = paramsOf(state.step).map((p) => p.name).sort((a, b) => b.length - a.length);
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
  const skip = state.step === "coupons" ? NO_VENTS : [];
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

// The wall unrolled: along it across, up the frame upward, two repeats of its pattern. Vents are holes; the wall is
// shaded by how far its inside stands in from the datum (darker, thicker); where it reaches the cells' land it touches.
function wallMap([ds, dz, contact, pitch, rows]) {
  const cols = rows[0].length, repeats = 2;
  const width = cols * ds * repeats, height = (rows.length - 1) * dz;
  const scale = Math.min(300 / width, 300 / height);
  const ratio = window.devicePixelRatio || 1;
  const canvas = el("canvas", { role: "img", "aria-label": "The wall unrolled: vents and solid, two repeats of the pattern" });
  canvas.style.width = `${width * scale}px`;
  canvas.style.height = `${height * scale}px`;
  canvas.width = Math.round(width * scale * ratio);
  canvas.height = Math.round(height * scale * ratio);
  const g = canvas.getContext("2d");
  g.setTransform(scale * ratio, 0, 0, -scale * ratio, 0, height * scale * ratio);   // mm, z up
  const css = getComputedStyle(document.documentElement);
  const wall = css.getPropertyValue("--accent").trim(), touch = css.getPropertyValue("--ink").trim();
  const deepest = Math.min(...rows.flat());
  for (let r = 0; r < rows.length; r++) for (let rep = 0; rep < repeats; rep++) for (let c = 0; c < cols; c++) {
    const v = rows[r][c];
    if (v > 0) continue;   // a vent: leave it empty
    g.fillStyle = v <= contact ? touch : wall;
    g.globalAlpha = v <= contact ? 0.85 : 0.35 + 0.6 * (v / deepest);
    g.fillRect((rep * cols + c) * ds, (r - 0.5) * dz, ds + 0.05, dz + 0.05);
  }
  g.globalAlpha = 1;
  g.strokeStyle = touch;
  g.lineWidth = 0.6 / scale;
  for (let x = 0; x <= width + 1e-6; x += pitch) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, -3 / scale); g.stroke(); }
  return el("figure", { class: "wallmap" }, canvas,
    el("figcaption", {}, "The wall unrolled, to scale, as printed: ",
      el("span", { class: "key wall" }), " wall, darker where thicker; ", el("span", { class: "key touch" }),
      " touches the cells; gaps are vents. Ticks mark each cell's middle."));
}

// ---- rendering
let renderer, viewer, lastStl = null, renderedFor = null, renderedName = "", renderTimer;
async function render() {
  if (renderer) { renderer.terminate(); renderer = null; finishRender(); setRender("idle", "Cancelled"); return; }
  renderer = spawn();
  $("#render").textContent = "Cancel";
  const t0 = performance.now();
  const key = location.hash, step = state.step;
  setRender("pending", "Rendering…");
  renderTimer = setInterval(() => setRender("pending", `Rendering… ${Math.round((performance.now() - t0) / 1000)} s`), 1000);
  try {
    const stl = step === "coupons" ? await renderSet() : await renderOne(defines(step), STEPS[step].file);
    if (!renderer) return;   // cancelled
    lastStl = stl;
    renderedFor = key;
    renderedName = fileName(step);
    viewer.show(stl);
    $("#empty").hidden = true;
    setRender("done", `Rendered in ${Math.round((performance.now() - t0) / 1000)} s`);
  } catch (e) {
    if (renderer) setRender("failed", String(e.message || e));
  } finally {
    finishRender();
  }
}
function finishRender() {
  clearInterval(renderTimer);
  renderer?.terminate();
  renderer = null;
  $("#render").textContent = STEPS[state.step].render;
  updateStale();
}
async function renderOne(defs, part) {
  const res = await job(renderer, { kind: "render", part, defines: defs });
  if (res.error) throw new Error(res.error);
  if (!res.ok) throw new Error(refusals(res.log.join("\n")).join("; ") || "OpenSCAD drew nothing");
  return res.stl;
}
async function renderSet() {
  const centre = Number(state.spread.centre || 0), step = Number(state.spread.step || 0.2);
  const count = Math.max(1, Math.min(9, Math.round(Number(state.spread.count || 3))));
  const offsets = Array.from({ length: count }, (_, k) => Math.round((centre + (k - (count - 1) / 2) * step) * 1e4) / 1e4);
  const parts = [];
  for (const [k, off] of offsets.entries()) {
    setRender("pending", `Rendering coupon ${k + 1} of ${count} (fit offset ${off >= 0 ? "+" : ""}${off})…`);
    renderer.terminate();
    renderer = spawn();
    parts.push(await renderOne(defines("coupons", { FIT_OFFSET: String(off) }), "coupon"));
  }
  return mergeStl(parts, Number(state.set.PRINT_MAX || 270));
}

// Lay coupons out in rows no wider than the plate, as tools/coupon_set.py does, and join them into one binary STL.
const GAP = 5;
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
    if (x > 0 && x + m.w > plate) { x = 0; y += rowH + GAP; rowH = 0; }
    m.dx = x - m.x0; m.dy = y - m.y0;
    x += m.w + GAP; rowH = Math.max(rowH, m.h); width = Math.max(width, x - GAP);
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
  const cell = state.set.CELL || PARAMS.frame.find((p) => p.name === "CELL").initial;
  if (step === "frame") return `frame-${cell}-${state.set.NC || 4}x${state.set.NR || 6}.stl`;
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
  URL.revokeObjectURL(a.href);
}

// ---- wiring
let debounce;
function changed() {
  writeHash();
  updateStale();
  for (const f of document.querySelectorAll(".field[data-name]")) f.classList.toggle("set", f.dataset.name in state.set);
  if (state.step === "spacer") $("#intro").textContent = STEPS.spacer.intro + spacerCount();
  clearTimeout(debounce);
  debounce = setTimeout(check, 300);
}

function showStep(key) {
  state.step = key;
  for (const b of document.querySelectorAll("#steps button")) b.setAttribute("aria-current", String(b.dataset.step === key));
  $("#render").textContent = STEPS[key].render;
  buildForm();
  changed();
}

async function main() {
  readHash();
  const [params, cells, wasmModule] = await Promise.all([
    fetch("params.json").then((r) => r.json()),
    fetch("../presets/cells.json").then((r) => r.json()),
    WebAssembly.compileStreaming(fetch(OPENSCAD + "openscad.wasm")).catch(async () =>
      WebAssembly.compile(await (await fetch(OPENSCAD + "openscad.wasm")).arrayBuffer())),
  ]);
  PARAMS = params;
  CELLS = cells.cells;
  for (const q of [...params.frame, ...params.spacer]) if (state.set[q.name] === String(q.initial)) delete state.set[q.name];
  wasm = wasmModule;
  checker = spawn();
  viewer = createViewer($("#viewer"));
  Object.entries(STEPS).forEach(([key, s], i) => $("#steps").append(
    el("button", { type: "button", "data-step": key, onclick: () => showStep(key) }, el("span", { class: "num" }, String(i + 1)), s.label)));
  $("#render").addEventListener("click", render);
  $("#download").addEventListener("click", download);
  setRender("idle");
  showStep(state.step);
}

main().catch((e) => setCheck("failed", [String(e)]));
