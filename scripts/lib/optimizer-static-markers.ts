import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

type Node = string | Node[];
export type StaticMarker = { id: number; parent: number | null; kind: string; function: string };
const namespace = '"starshine.static-marker"';
const maxBytes = 16 * 1024 * 1024;

// Accept the canonical, flat, named output of wasm-tools print. Preserve strings
// as tokens and remove both nested block comments and line comments.
function parse(text: string): Node[] {
  if (Buffer.byteLength(text) > maxBytes) throw new Error("WAT exceeds static marker byte budget");
  const root: Node[] = [], stack = [root];
  for (let i = 0; i < text.length;) {
    if (/\s/.test(text[i])) { i++; continue; }
    if (text.startsWith(";;", i)) { const end = text.indexOf("\n", i); i = end < 0 ? text.length : end + 1; continue; }
    if (text.startsWith("(;", i)) {
      let depth = 1; i += 2;
      while (i < text.length && depth) {
        if (text.startsWith("(;", i)) { depth++; i += 2; }
        else if (text.startsWith(";)", i)) { depth--; i += 2; }
        else i++;
      }
      if (depth) throw new Error("unclosed WAT comment");
      continue;
    }
    if (text[i] === "(") {
      if (stack.length > 2048) throw new Error("WAT exceeds static marker depth budget");
      const child: Node[] = []; stack.at(-1)!.push(child); stack.push(child); i++; continue;
    }
    if (text[i] === ")") {
      if (stack.length === 1) throw new Error("unexpected WAT close");
      stack.pop(); i++; continue;
    }
    const start = i;
    if (text[i] === '"') {
      i++;
      while (i < text.length && text[i] !== '"') { if (text[i] === "\\") i++; i++; }
      if (i === text.length) throw new Error("unclosed WAT string");
      i++;
    } else {
      while (i < text.length && !/[\s()]/.test(text[i])) i++;
    }
    stack.at(-1)!.push(text.slice(start, i));
  }
  if (stack.length !== 1) throw new Error("unclosed WAT list");
  if (root.length !== 1 || !Array.isArray(root[0]) || root[0][0] !== "module") throw new Error("expected one core Wasm module");
  return root[0];
}
function emit(node: Node): string {
  return typeof node === "string" ? node : `(${node.map(emit).join(" ")})`;
}
const header = new Set(["type", "param", "result", "local"]);
const unsupported = /^(try|try_table|catch|catch_all|catch_ref|catch_all_ref|delegate|throw|throw_ref|rethrow|resume|resume_throw|resume_throw_ref|suspend|switch|cont\.|return_call|return_call_ref|return_call_indirect|br_on_)/;

export function instrumentNamedWat(text: string): { wat: string; markers: StaticMarker[] } {
  const mod = parse(text), markers: StaticMarker[] = [];
  if (mod.some(n => Array.isArray(n) && n[0] === "@custom" && typeof n[1] === "string" && /compiler\.facts|metadata\.code/.test(n[1]))) {
    throw new Error("unsupported function-index metadata for static markers");
  }
  if (mod.some(n => Array.isArray(n) && n[0] === "import" && n[1] === namespace)) throw new Error("reserved marker namespace already present");
  const names = new Set(text.match(/\$[^\s()]+/g) ?? []);
  const markerNames: string[] = [];
  for (const field of mod) {
    if (!Array.isArray(field) || field[0] !== "func") continue;
    const functionName = field[1];
    if (typeof functionName !== "string" || !functionName.startsWith("$")) throw new Error("defined functions must have names; use wasm-tools print --name-unnamed");
    let first = 2;
    while (Array.isArray(field[first]) && header.has((field[first] as Node[])[0] as string)) first++;
    const output: Node[] = field.slice(0, first);
    const regions: Array<{ marker: number; parent: number | null; kind: string }> = [];
    const mark = (kind: string, parent: number | null): number => {
      if (markers.length >= 10000) throw new Error("static marker count budget exceeded");
      const id = markers.length;
      let name = `$_starshine_marker_${id}`;
      while (names.has(name)) name += "_";
      names.add(name); markerNames.push(name);
      markers.push({ id, parent, kind, function: functionName });
      output.push("call", name);
      return id;
    };
    regions.push({ marker: mark("function", null), parent: null, kind: "function" });
    for (let i = first; i < field.length; i++) {
      const op = field[i];
      if (typeof op !== "string") {
        if (["type", "param", "result", "table", "ref", "shared"].includes(op[0] as string)) { output.push(op); continue; }
        throw new Error("expected flat instructions from wasm-tools print");
      }
      if (unsupported.test(op)) throw new Error(`unsupported control for static markers: ${op}`);
      output.push(op);
      if (["block", "loop", "if"].includes(op)) {
        if (typeof field[i + 1] === "string" && (field[i + 1] as string).startsWith("$")) output.push(field[++i]);
        while (Array.isArray(field[i + 1]) && header.has((field[i + 1] as Node[])[0] as string)) output.push(field[++i]);
        const parent = regions.at(-1)!.marker;
        const kind = op === "if" ? "then" : op;
        regions.push({ marker: mark(kind, parent), parent, kind });
      } else if (op === "else") {
        const region = regions.at(-1)!;
        if (region.kind !== "then") throw new Error("unexpected else");
        if (typeof field[i + 1] === "string" && (field[i + 1] as string).startsWith("$")) output.push(field[++i]);
        regions[regions.length - 1] = { marker: mark("else", region.parent), parent: region.parent, kind: "else" };
      } else if (op === "end") {
        if (regions.length === 1) throw new Error("unexpected end");
        regions.pop();
        if (typeof field[i + 1] === "string" && (field[i + 1] as string).startsWith("$")) output.push(field[++i]);
        regions.at(-1)!.marker = mark("after-end", regions.at(-1)!.marker);
      } else if (["br", "br_if", "br_table", "return", "unreachable"].includes(op)) {
        if (op === "br" || op === "br_if" || op === "br_table") {
          let count = 0;
          while (typeof field[i + 1] === "string" && /^(\$|\d+$)/.test(field[i + 1] as string)) { output.push(field[++i]); count++; if (op !== "br_table") break; }
          if (!count) throw new Error(`missing ${op} label`);
        }
        regions.at(-1)!.marker = mark(`after-${op}`, regions.at(-1)!.marker);
      } else if (["call", "ref.func"].includes(op) && /^\d+$/.test(String(field[i + 1]))) {
        throw new Error("function references must have names; use wasm-tools print --name-unnamed");
      }
    }
    if (regions.length !== 1) throw new Error("unclosed control region");
    field.splice(0, field.length, ...output);
  }
  const imports: Node[] = markerNames.map((name, id) => ["import", namespace, `"${id}"`, ["func", name]]);
  const insertion = typeof mod[1] === "string" && mod[1].startsWith("$") ? 2 : 1;
  mod.splice(insertion, 0, ...imports);
  return { wat: emit(mod), markers };
}

export function survivingMarkers(text: string): number[] {
  const mod = parse(text), lookup = new Map<string, number>();
  let functionIndex = 0;
  for (const field of mod) {
    if (!Array.isArray(field) || field[0] !== "import") continue;
    const func = field[3];
    if (!Array.isArray(func) || func[0] !== "func") continue;
    if (field[1] === namespace) {
      if (typeof field[2] !== "string" || !/^"\d+"$/.test(field[2])) throw new Error("invalid marker import identity");
      const id = Number(field[2].slice(1, -1));
      if (!Number.isSafeInteger(id)) throw new Error("invalid marker import identity");
      lookup.set(String(functionIndex), id);
      if (typeof func[1] === "string" && func[1].startsWith("$")) lookup.set(func[1], id);
    }
    functionIndex++;
  }
  const found = new Set<number>();
  const pending: Node[][] = [mod];
  while (pending.length) {
    const list = pending.pop()!;
    for (let i = 0; i < list.length; i++) {
      if (Array.isArray(list[i])) pending.push(list[i] as Node[]);
      else if (["call", "return_call"].includes(list[i] as string)) {
        const id = lookup.get(String(list[i + 1]));
        if (id !== undefined) found.add(id);
      } else if (list[i] === "ref.func" && lookup.has(String(list[i + 1]))) {
        throw new Error("indirect marker reference makes survival inconclusive");
      }
    }
  }
  return [...found].sort((a, b) => a - b);
}

export function compareMarkerSets(markers: StaticMarker[], weaker: number[], stronger: number[]) {
  const low = new Set(weaker), high = new Set(stronger);
  const candidates = stronger.filter(id => !low.has(id)).sort((a, b) => a - b);
  const candidateSet = new Set(candidates), byId = new Map(markers.map(m => [m.id, m]));
  for (const id of [...weaker, ...stronger]) if (!byId.has(id)) throw new Error(`unknown surviving marker ${id}`);
  const primaryCandidates = candidates.filter(id => {
    let parent = byId.get(id)!.parent;
    while (parent !== null) {
      if (candidateSet.has(parent)) return false;
      parent = byId.get(parent)!.parent;
    }
    return true;
  });
  return { candidates, primaryCandidates, reverseDifferences: weaker.filter(id => !high.has(id)).sort((a, b) => a - b) };
}

function command(bin: string, args: string[]): string {
  const result = spawnSync(bin, args, { encoding: "utf8", timeout: 60000, maxBuffer: maxBytes });
  if (result.error || result.status !== 0) throw new Error(`${path.basename(bin)} failed: ${result.error?.message ?? result.stderr}`);
  return result.stdout;
}
function hash(file: string) { return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex"); }

// This diagnostic extends the fuzz entrypoint. Production measurements must use
// the retained original module: opaque marker calls can change pass decisions.
export function runStaticMarkerComparison(argv: string[]) {
  const options = new Map<string, string>();
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i], value = argv[i + 1];
    if (!["--input", "--out-dir", "--starshine-bin", "--weaker-bin", "--stronger-bin", "--weaker", "--stronger"].includes(key) || !value || value.startsWith("--") || options.has(key)) throw new Error(`invalid static marker option ${key}`);
    options.set(key, value);
  }
  const required = (key: string) => { const value = options.get(key); if (!value) throw new Error(`missing ${key}`); return value; };
  const input = path.resolve(required("--input")), out = path.resolve(required("--out-dir")), bin = path.resolve(required("--starshine-bin"));
  const bins = [path.resolve(options.get("--weaker-bin") ?? bin), path.resolve(options.get("--stronger-bin") ?? bin)];
  const sequences = [required("--weaker"), required("--stronger")].map(sequence => sequence.split(","));
  for (const passes of sequences) if (!passes.length || passes.length > 8 || passes.some(p => !/^[a-z][a-z0-9-]*$/.test(p))) throw new Error("expected one to eight canonical pass names");
  if (fs.existsSync(out)) throw new Error("static marker output directory must be new");
  command("wasm-tools", ["validate", "--features", "all", input]);
  const instrumented = instrumentNamedWat(command("wasm-tools", ["print", "--name-unnamed", input]));
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.mkdirSync(out);
  fs.copyFileSync(input, path.join(out, "original.wasm"));
  const wat = path.join(out, "instrumented.wat"), wasm = path.join(out, "instrumented.wasm");
  fs.writeFileSync(wat, instrumented.wat);
  command("wasm-tools", ["parse", wat, "-o", wasm]);
  command("wasm-tools", ["validate", "--features", "all", wasm]);
  const survivors = sequences.map((passes, i) => {
    const output = path.join(out, `${i === 0 ? "weaker" : "stronger"}.wasm`);
    command(bins[i], [wasm, ...passes.map(p => `--${p}`), "-o", output]);
    command("wasm-tools", ["validate", "--features", "all", output]);
    return survivingMarkers(command("wasm-tools", ["print", "--name-unnamed", output]));
  });
  const report = {
    schema: "starshine.static-missed-optimization.v1", detector: "pre-pass-static-markers",
    classification: "candidate-only", inputHash: hash(input), optimizerHash: hash(bin), optimizerHashes: bins.map(hash),
    wasmToolsVersion: command("wasm-tools", ["--version"]).trim(),
    sequences, markers: instrumented.markers, survivors,
    ...compareMarkerSets(instrumented.markers, survivors[0], survivors[1]),
    note: "Pass sequences need not be monotonic. Reduce candidates with a marker-set predicate and confirm effects, traps, size and runtime on original.wasm before accepting a change.",
  };
  fs.writeFileSync(path.join(out, "report.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report));
  return report;
}
