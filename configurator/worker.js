// SPDX-License-Identifier: CERN-OHL-S-2.0
// Runs one OpenSCAD job in WebAssembly and posts back its echo, its log and any STL. OpenSCAD's main() runs once per
// instance, so every job gets a fresh instance of the compiled module the page hands over.
//
// in:  { kind: "init", wasm: WebAssembly.Module, openscadUrl }
//      { id, kind: "check" | "render", part, defines: { NAME: "literal" } }
// out: { id, ok, echo, log, stl?: ArrayBuffer, ms } or { id, error }

const SOURCES = ["frame.scad", "spacer.scad", "coupon.scad", "lib/grip.scad", "lib/cells.scad"];
const FONT = "NotoSans-Regular.ttf";
let setup;

async function load(wasm, openscadUrl) {
  const fetchText = async (p) => [p, await (await fetch(new URL("../" + p, import.meta.url), { cache: "no-cache" })).text()];
  const [{ default: OpenSCAD }, sources, font] = await Promise.all([
    import(openscadUrl),
    Promise.all(SOURCES.map(fetchText)),
    fetch(new URL("fonts/" + FONT, import.meta.url)).then((r) => r.arrayBuffer()),
  ]);
  return { OpenSCAD, wasm, sources, font: new Uint8Array(font) };
}

async function run({ kind, part, defines }) {
  const { OpenSCAD, wasm, sources, font } = await setup;
  const log = [];
  const inst = await OpenSCAD({
    noInitialRun: true,
    print: (t) => log.push(t),
    printErr: (t) => log.push(t),
    instantiateWasm: (imports, done) => {
      WebAssembly.instantiate(wasm, imports).then((i) => done(i));
      return {};
    },
  });
  const fs = inst.FS;
  fs.mkdir("/src");
  fs.mkdir("/src/lib");
  fs.mkdir("/fonts");
  for (const [path, text] of sources) fs.writeFile("/src/" + path, text);
  fs.writeFile("/fonts/" + FONT, font);
  fs.writeFile("/fonts/fonts.conf", '<?xml version="1.0"?><fontconfig><dir>/fonts</dir></fontconfig>');
  if (inst.ENV) inst.ENV.FONTCONFIG_FILE = "/fonts/fonts.conf";
  // The coupon's label needs a font; registering one with `use` leaves the parts themselves untouched.
  fs.writeFile("/src/run.scad", `use </fonts/${FONT}>\ninclude <${part}.scad>\n`);

  const out = kind === "check" ? "/out.echo" : "/out.stl";
  const args = kind === "check" ? ["-o", out, "-D", 'VIEW="none"'] : ["--backend=Manifold", "--export-format=binstl", "-o", out, "-D", 'VIEW="part"'];
  for (const [name, value] of Object.entries(defines)) args.push("-D", `${name}=${value}`);
  args.push("/src/run.scad");

  const t0 = performance.now();
  try {
    inst.callMain(args);
  } catch (e) {
    log.push("ERROR: OpenSCAD stopped: " + e);
  }
  const ms = performance.now() - t0;
  const read = (path, enc) => {
    try { return fs.readFile(path, enc ? { encoding: enc } : undefined); } catch { return null; }
  };
  const echo = kind === "check" ? read(out, "utf8") || "" : log.filter((l) => l.startsWith("ECHO:")).join("\n");
  const stl = kind === "render" ? read(out) : null;
  const text = echo + "\n" + log.join("\n");
  const ok = !/ERROR/.test(text) && (kind === "check" || (stl && stl.length > 84));
  return { ok, echo, log, ms, stl: stl ? stl.buffer.slice(stl.byteOffset, stl.byteOffset + stl.byteLength) : null };
}

self.onmessage = async ({ data }) => {
  if (data.kind === "init") {
    setup = load(data.wasm, data.openscadUrl);
    return;
  }
  try {
    const result = await run(data);
    self.postMessage({ id: data.id, ...result }, result.stl ? [result.stl] : []);
  } catch (e) {
    self.postMessage({ id: data.id, error: String(e) });
  }
};
