// SPDX-License-Identifier: CERN-OHL-S-2.0
// The configurator: a form built from the parts' Customizer sections (params.json) and the presets
// (presets/cells.json). Each change is checked in OpenSCAD (WebAssembly, in a worker) without drawing the part;
// Render draws it, shows it and offers the STL. Only the values the user sets are passed, as -D, so every default
// comes from the .scad files themselves.

import { createViewer } from "./viewer.js";

const OPENSCAD = "https://cdn.jsdelivr.net/npm/openscad-playground@2.4.0/dist/wasm/";
const PENDING_CUE_MS = 400;   // a check that answers sooner shows no in-flight cue, so a fast answer doesn't strobe

const PARTS = {
  frame: { file: "frame", params: "frame", label: "Frame", hide: [] },
  coupons: { file: "coupon", params: "frame", label: "Coupon set", hide: ["NC", "NR", "FIT_OFFSET"] },
  spacer: { file: "spacer", params: "spacer", label: "Spacer", hide: [] },
};
const SHOWN = {   // what the echo says, in order: [key, label, format]
  FRAME: [
    ["pitch", "Pitch", (v) => `${fmt(v)} mm`],
    ["cell_fit", "Cell as the grip sees it", (v) => `${fmt(v)} mm`],
    ["size", "Footprint", (v) => `${fmt(v[0])} × ${fmt(v[1])} mm`],
    ["length", "Height", (v) => `${fmt(v)} mm`],
    ["grip", "Grip", (v) => v],
    ["bow_span", "Bow span", (v) => `${fmt(v)} mm`],
    ["bows", "Bows", (v) => v],
    ["contacts", "Lines of contact per cell", (v) => v],
    ["open_fraction", "Wall open", (v) => `${Math.round(v * 100)} %`],
    ["steepest_deg", "Steepest face inside", (v) => `${fmt(v)}°`],
    ["steepest_out_deg", "Steepest face outside", (v) => `${fmt(v)}°`],
    ["vent_tallest", "Tallest vent", (v) => `${fmt(v)} mm`],
    ["vent_widest", "Widest vent", (v) => `${fmt(v)} mm`],
    ["tie_shortest", "Shortest tie", (v) => `${fmt(v)} mm`],
    ["column_narrowest", "Narrowest column", (v) => `${fmt(v)} mm`],
  ],
  SPACER: [
    ["pitch", "Pitch", (v) => `${fmt(v)} mm`],
    ["bow_span", "Bow span", (v) => `${fmt(v)} mm`],
    ["neck", "Narrowest neck", (v) => `${fmt(v)} mm`],
    ["across_arms", "Across the arms", (v) => `${fmt(v)} mm`],
    ["height", "Height", (v) => `${fmt(v)} mm`],
    ["tilt_deg_max", "Most it can tilt", (v) => `${fmt(v)}°`],
  ],
};
const fmt = (x) => (Number.isInteger(x) ? String(x) : x.toFixed(2).replace(/\.?0+$/, ""));
const $ = (sel) => document.querySelector(sel);
const el = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") e.className = v;
    else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) e.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat()) if (kid != null) e.append(kid);
  return e;
};

// ---- state: the part, the values the user set (as typed), the coupon set's spread. Kept in the URL's hash.
const state = { part: "frame", set: {}, spread: { centre: "", step: "0.2", count: "3" } };
function readHash() {
  const q = new URLSearchParams(location.hash.slice(1));
  if (PARTS[q.get("part")]) state.part = q.get("part");
  for (const [k, v] of q) {
    if (k === "part") continue;
    if (k.startsWith("set.")) state.spread[k.slice(4)] = v;
    else state.set[k] = v;
  }
}
function writeHash() {
  const q = new URLSearchParams({ part: state.part, ...state.set });
  if (state.part === "coupons") for (const [k, v] of Object.entries(state.spread)) if (v !== "") q.set("set." + k, v);
  history.replaceState(null, "", "#" + q);
}

let PARAMS, CELLS;

// The -D values for the current part: only what the user set, numbers as typed, strings as OpenSCAD literals.
function defines(extra = {}) {
  const params = Object.fromEntries(PARAMS[PARTS[state.part].params].map((p) => [p.name, p]));
  const out = {};
  for (const [name, value] of Object.entries({ ...state.set, ...extra })) {
    const p = params[name];
    if (!p || value === "" || PARTS[state.part].hide.includes(name) && !(name in extra)) continue;
    out[name] = p.type === "string" ? JSON.stringify(String(value)) : String(Number(value));
  }
  return out;
}

// ---- the form
function buildForm() {
  const form = $("#form");
  form.replaceChildren();
  const part = PARTS[state.part];
  const groups = new Map();
  for (const p of PARAMS[part.params]) {
    if (part.hide.includes(p.name)) continue;
    if (!groups.has(p.group)) groups.set(p.group, []);
    groups.get(p.group).push(p);
  }
  if (state.part === "coupons") form.append(spreadSection());
  let first = true;
  for (const [group, params] of groups) {
    const open = first || group === "Block" || group === "Vents";
    first = false;
    form.append(el("details", { class: "group", open }, el("summary", {}, group), ...params.map(field)));
  }
  form.append(el("button", { type: "button", id: "reset", onclick: () => { state.set = {}; buildForm(); changed(); } },
    "Reset to the defaults"));
}

function spreadSection() {
  const num = (key, label, help, attrs) => el("label", { class: "field" },
    el("span", { class: "name" }, label),
    el("input", { type: "number", value: state.spread[key], ...attrs, oninput: (e) => { state.spread[key] = e.target.value; changed(); } }),
    el("span", { class: "help" }, help));
  return el("details", { class: "group", open: true }, el("summary", {}, "Fit offsets to print"),
    num("centre", "Middle offset", "mm: 0 to start; then the best coupon's, to refine", { step: 0.05, placeholder: "0" }),
    num("step", "Step", "mm between coupons: 0.2 to start, 0.05 to refine", { step: 0.05, min: 0.01 }),
    num("count", "Coupons", "in the set, laid out on one plate", { step: 1, min: 1, max: 9 }));
}

function field(p) {
  const value = state.set[p.name] ?? "";
  const set = (v) => { if (v === "" || v == null) delete state.set[p.name]; else state.set[p.name] = v; changed(); };
  let input;
  if (p.name === "CELL") {
    input = el("select", { onchange: (e) => { set(e.target.value === String(p.initial) ? "" : e.target.value); buildForm(); } },
      ...CELLS.map((c) => el("option", { value: c.name, selected: (value || String(p.initial)) === c.name }, c.name)),
      el("option", { value: "custom", selected: value === "custom" }, "custom"));
  } else if (p.options) {
    const opts = [...new Set(p.options.map((o) => String(o.value)))];
    input = el("select", { onchange: (e) => set(e.target.value === String(p.initial) ? "" : e.target.value) },
      ...opts.map((o) => el("option", { value: o, selected: (value || String(p.initial)) === o }, o)));
  } else if (p.type === "number") {
    input = el("input", { type: "number", value, placeholder: placeholder(p), min: p.min, max: p.max, step: p.step,
      oninput: (e) => set(e.target.value) });
  } else {
    input = el("input", { type: "text", value, placeholder: String(p.initial), oninput: (e) => set(e.target.value) });
  }
  const label = el("label", { class: "field" + (value !== "" ? " set" : ""), "data-name": p.name },
    el("span", { class: "name" }, p.name), input, el("span", { class: "help" }, p.caption));
  if (p.name === "CELL") label.append(cellNote(value || String(p.initial)));
  return label;
}

function placeholder(p) {
  if (["CELL_D", "CELL_L"].includes(p.name)) return "preset";
  if (p.name === "PITCH") return "d + gap";
  return fmt(p.initial);
}

function cellNote(name) {
  const c = CELLS.find((x) => x.name === name);
  if (!c) return el("span", { class: "note" }, "Set CELL_D and CELL_L below.");
  return el("span", { class: "note" }, `${fmt(c.d)} × ${fmt(c.l)} mm${c.verify ? " (verify)" : ""}: ${c.basis}. `,
    c.source ? el("a", { href: c.source, target: "_blank", rel: "noopener" }, "Datasheet") : "No datasheet found.");
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
  try { return Object.fromEntries(JSON.parse(m[1].replace(/\bundef\b/g, "null"))); } catch { return null; }
}
function parseList(text, name) {
  const m = text.match(new RegExp(`^ECHO: ${name} = (.+)$`, "m"));
  try { return m ? JSON.parse(m[1]) : null; } catch { return null; }
}

// The wall unrolled: along it across, up the frame upward, two repeats of its pattern. Vents are holes; the wall is
// shaded by how far its inside stands in from the datum (darker, thicker); where it reaches the cells' land it touches.
function drawWallMap(map) {
  const box = $("#wallmap");
  box.hidden = !map;
  if (!map) return;
  const [ds, dz, contact, pitch, rows] = map;
  const cols = rows[0].length, repeats = 2;
  const width = cols * ds * repeats, height = (rows.length - 1) * dz;
  const canvas = box.querySelector("canvas");
  const scale = Math.min(300 / width, 340 / height);
  const ratio = window.devicePixelRatio || 1;
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
  const extra = state.part === "coupons" ? { FIT_OFFSET: state.spread.centre || "0" } : {};
  const res = await job(checker, { kind: "check", part: PARTS[state.part].file, defines: defines(extra) });
  clearTimeout(cue);
  if (seq !== checkSeq) return;   // a newer change took over
  checkBusy = false;
  if (res.error) return setCheck("failed", [res.error]);
  const text = res.echo + "\n" + res.log.join("\n");
  const name = state.part === "spacer" ? "SPACER" : "FRAME";
  showDerived(parseEcho(text, name), name);
  drawWallMap(state.part === "frame" ? parseList(text, "WALL_MAP") : null);
  const bad = refusals(text);
  setCheck(bad.length ? "refused" : "ok", bad, res.ms);
}

function setCheck(status, messages = [], ms) {
  const box = $("#check");
  box.dataset.status = status;
  const head = {
    pending: "Checking…",
    ok: `Printable: every check passes${ms ? ` (${(ms / 1000).toFixed(1)} s)` : ""}`,
    refused: "Refused: OpenSCAD won't draw this",
    failed: "The check didn't run",
  }[status];
  box.replaceChildren(el("strong", {}, head), messages.length ? el("ul", {}, ...messages.map((m) => el("li", {}, m))) : "");
  $("#derived").classList.toggle("stale", status === "pending");
  $("#wallmap").classList.toggle("stale", status === "pending");
}

const VENTS = ["contacts", "open_fraction", "steepest_deg", "steepest_out_deg", "tie_shortest", "column_narrowest",
  "vent_tallest", "vent_widest"];
function showDerived(values, name) {
  const table = $("#derived");
  if (!values) return table.replaceChildren();
  const skip = state.part === "coupons" ? VENTS : [];   // a coupon is one band deep: it has no wave
  table.replaceChildren(...SHOWN[name].filter(([k]) => k in values && !skip.includes(k)).map(([k, label, f]) =>
    el("tr", {}, el("th", {}, label), el("td", {}, f(values[k])))));
}

// ---- rendering
let renderer, viewer, lastStl = null, renderedFor = null, renderTimer;
async function render() {
  const btn = $("#render");
  if (renderer) { renderer.terminate(); renderer = null; btn.textContent = "Render STL"; setRender("idle"); return; }
  renderer = spawn();
  btn.textContent = "Cancel";
  const t0 = performance.now();
  const key = location.hash;
  setRender("pending", "Rendering…");
  renderTimer = setInterval(() => setRender("pending", `Rendering… ${Math.round((performance.now() - t0) / 1000)} s`), 1000);
  try {
    const stl = state.part === "coupons" ? await renderSet() : await renderOne(defines());
    lastStl = stl;
    renderedFor = key;
    viewer.show(stl);
    setRender("done", `Rendered in ${Math.round((performance.now() - t0) / 1000)} s`);
  } catch (e) {
    setRender("failed", String(e.message || e));
  } finally {
    clearInterval(renderTimer);
    renderer?.terminate();
    renderer = null;
    btn.textContent = "Render STL";
    updateStale();
  }
}
async function renderOne(defs, part = PARTS[state.part].file) {
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
    setRender("pending", `Rendering coupon ${k + 1} of ${count} (FIT_OFFSET ${off >= 0 ? "+" : ""}${off})…`);
    renderer.terminate();
    renderer = spawn();
    parts.push(await renderOne(defines({ FIT_OFFSET: String(off) })));
  }
  const plate = Number(state.set.PRINT_MAX || 270);
  return mergeStl(parts, plate);
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

function setRender(status, text = "") {
  const box = $("#render-status");
  box.dataset.status = status;
  box.textContent = text;
  $("#download").disabled = !lastStl;
}
function updateStale() {
  const stale = lastStl && renderedFor !== location.hash;
  $("#viewer").classList.toggle("stale", Boolean(stale));
  $("#stale-note").hidden = !stale;
}
function download() {
  if (!lastStl) return;
  const cell = state.set.CELL || PARAMS.frame.find((p) => p.name === "CELL").initial;
  const name = state.part === "frame" ? `frame-${cell}-${state.set.NC || 4}x${state.set.NR || 6}` : `${state.part}-${cell}`;
  const a = el("a", { href: URL.createObjectURL(new Blob([lastStl], { type: "model/stl" })), download: name + ".stl" });
  a.click();
  URL.revokeObjectURL(a.href);
}

// ---- wiring
let debounce;
function changed() {
  writeHash();
  updateStale();
  for (const f of document.querySelectorAll(".field[data-name]")) f.classList.toggle("set", f.dataset.name in state.set);
  clearTimeout(debounce);
  debounce = setTimeout(check, 300);
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
  wasm = wasmModule;
  checker = spawn();
  viewer = createViewer($("#viewer"));
  for (const [key, p] of Object.entries(PARTS)) {
    $("#parts").append(el("button", { type: "button", "aria-pressed": String(key === state.part), "data-part": key,
      onclick: () => {
        state.part = key;
        for (const b of document.querySelectorAll("#parts button")) b.setAttribute("aria-pressed", String(b.dataset.part === key));
        buildForm();
        changed();
      } }, p.label));
  }
  $("#render").addEventListener("click", render);
  $("#download").addEventListener("click", download);
  buildForm();
  setRender("idle");
  changed();
}

main().catch((e) => setCheck("failed", [String(e)]));
