import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { classifyValidationRun, qualifyValidationPremise, validatePremiseCatalog, type PremiseCatalog, type ValidationObservation } from "../lib/validator-premise-qualification";

function resolveCommand(command: string) {
  const candidates = command.includes("/") ? [path.resolve(command)] : (process.env.PATH ?? "").split(path.delimiter).map((dir) => path.resolve(dir, command));
  for (const candidate of candidates) { try { fs.accessSync(candidate, fs.constants.X_OK); if (fs.statSync(candidate).isFile()) return fs.realpathSync(candidate); } catch {} }
  throw new Error(`command not found: ${command}`);
}
const hash = (filename: string) => createHash("sha256").update(fs.readFileSync(filename)).digest("hex");
function run(command: string, args: string[]) {
  const start = performance.now();
  const result = spawnSync(command, args, { encoding: "utf8", timeout: 5000, killSignal: "SIGKILL", maxBuffer: 1024 * 1024 });
  return { elapsedMs: performance.now() - start, exit: result.status, error: result.error?.message ?? null, errorCode: (result.error as NodeJS.ErrnoException | undefined)?.code ?? null, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

export function runValidatorPremiseMatrix(options: { starshineBin: string; wasmOptBin: string; wasmToolsBin: string; outDir: string }) {
  options = { ...options, starshineBin: resolveCommand(options.starshineBin), wasmOptBin: resolveCommand(options.wasmOptBin), wasmToolsBin: resolveCommand(options.wasmToolsBin) };
  const repo = path.resolve(import.meta.dir, "../..");
  const catalogPath = path.join(repo, "tests/validator-premises/catalog.json");
  const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8")) as PremiseCatalog;
  const errors = validatePremiseCatalog(catalog);
  if (errors.length) throw new Error(errors.join("; "));
  if (fs.existsSync(options.outDir)) throw new Error("premise matrix output directory must be fresh");
  const version = run(options.wasmOptBin, ["--version"]);
  if (version.exit !== 0 || version.stdout.trim() !== "wasm-opt version 133 (version_133)") throw new Error("premise matrix requires Binaryen v133");
  fs.mkdirSync(options.outDir, { recursive: true });
  const results = [];
  for (const premise of catalog.cases) {
    if (!/^[a-z0-9-]+$/.test(premise.id) || Buffer.byteLength(premise.wat) > 8192) throw new Error("unsafe or over-budget premise fixture");
    const base = path.join(options.outDir, premise.id); fs.mkdirSync(base);
    const wat = path.join(base, "input.wat"), input = path.join(base, "input.wasm");
    fs.writeFileSync(wat, premise.wat);
    const parse = run(options.wasmToolsBin, ["parse", wat, "-o", input]);
    if (parse.exit !== 0) throw new Error(`fixture text did not compile: ${premise.id}: ${parse.stderr}`);
    const inputHash = hash(input);
    const print = run(options.wasmToolsBin, ["print", input, "-o", path.join(base, "decoded.wat")]);
    const nativeDecode = run(options.starshineBin, ["--emit-runtime-interface-json", input]);
    const encoding = print.exit === 0 && nativeDecode.exit === 0 ? "well-formed" as const : "unknown" as const;
    const runs = {
      starshine: run(options.starshineBin, ["--validate", input, "--out", path.join(base, "starshine-validated.wasm")]),
      "wasm-tools": run(options.wasmToolsBin, ["validate", "--features", "all", input]),
      "binaryen-133": run(options.wasmOptBin, [input, "--all-features", "-o", path.join(base, "binaryen-output.wasm")]),
    };
    const observations: ValidationObservation[] = Object.entries(runs).map(([tool, result]) => ({
      tool, encoding,
      disposition: classifyValidationRun(tool, encoding, result),
      diagnostic: result.stderr,
      rejectionStage: tool === "binaryen-133" && /\[parse exception:/.test(result.stderr) ? "typed-ir-read" : "validator",
    }));
    if (hash(input) !== inputHash) throw new Error("premise input changed during validation");
    results.push({ id: premise.id, family: premise.family, expected: premise.expected, inputHash, inputBytes: fs.statSync(input).size, encodingChecks: { wasmToolsPrint: print, starshineDecode: nativeDecode }, observations, runs, qualification: qualifyValidationPremise(premise, observations), guestExecution: "not performed" });
  }
  // A truncated version header is a byte-decoding control, never a typing fixture.
  const malformed = path.join(options.outDir, "truncated-header.wasm");
  fs.writeFileSync(malformed, Buffer.from([0, 97, 115, 109, 1, 0, 0]));
  const malformedHash = hash(malformed);
  const malformedDecode = { native: run(options.starshineBin, ["--emit-runtime-interface-json", malformed]), wasmTools: run(options.wasmToolsBin, ["print", malformed]) };
  const malformedEncoding = classifyValidationRun("starshine", "malformed", malformedDecode.native) === "malformed" && classifyValidationRun("wasm-tools", "malformed", malformedDecode.wasmTools) === "malformed" ? "malformed" as const : "unknown" as const;
  const malformedRuns = {
    starshine: run(options.starshineBin, ["--validate", malformed, "--out", path.join(options.outDir, "malformed-output.wasm")]),
    "wasm-tools": run(options.wasmToolsBin, ["validate", "--features", "all", malformed]),
    "binaryen-133": run(options.wasmOptBin, [malformed, "--all-features", "-o", path.join(options.outDir, "malformed-binaryen.wasm")]),
  };
  const malformedObservations = Object.entries(malformedRuns).map(([tool, result]) => ({ tool, encoding: malformedEncoding, disposition: classifyValidationRun(tool, malformedEncoding, result), diagnostic: result.stderr }));
  const featureInput = path.join(options.outDir, "local-initialization-valid", "input.wasm");
  const featureHash = hash(featureInput);
  const enabled = run(options.wasmToolsBin, ["validate", "--features=all", featureInput]);
  const disabled = run(options.wasmToolsBin, ["validate", "--features=all,-function-references,-gc", featureInput]);
  const unsupported = classifyValidationRun("wasm-tools", "well-formed", disabled);
  const phaseControls = {
    malformed: { inputHash: malformedHash, decode: malformedDecode, runs: malformedRuns, observations: malformedObservations, passed: malformedObservations.every((result) => result.disposition === "malformed") && hash(malformed) === malformedHash },
    featureDisabled: { inputHash: featureHash, enabled, disabled, disposition: unsupported, passed: enabled.exit === 0 && unsupported === "unsupported" && hash(featureInput) === featureHash },
  };
  const report = { schema: "starshine.validator-premise-matrix.v1", specification: catalog.specification, featurePolicy: catalog.featurePolicy, catalogHash: hash(catalogPath), modelHash: hash(path.join(repo, "scripts/lib/validator-premise-qualification.ts")), runnerHash: hash(import.meta.filename), tools: { starshine: { command: options.starshineBin, hash: hash(options.starshineBin) }, binaryen: { command: options.wasmOptBin, hash: hash(options.wasmOptBin), version: version.stdout.trim() }, wasmTools: { command: options.wasmToolsBin, hash: hash(options.wasmToolsBin), version: run(options.wasmToolsBin, ["--version"]).stdout.trim() } }, phaseControls, results };
  fs.writeFileSync(path.join(options.outDir, "result.json"), JSON.stringify(report, null, 2) + "\n");
  return report;
}

if (import.meta.main) {
  const [starshineBin, wasmOptBin, outDir, wasmToolsBin = "wasm-tools"] = process.argv.slice(2);
  if (!starshineBin || !wasmOptBin || !outDir) throw new Error("usage: bun scripts/test/validator-premise-matrix.ts <native-starshine> <v133-wasm-opt> <fresh-out-dir> [wasm-tools]");
  const report = runValidatorPremiseMatrix({ starshineBin, wasmOptBin, outDir, wasmToolsBin });
  process.stdout.write(JSON.stringify(report.results.map((result) => ({ id: result.id, ...result.qualification })), null, 2) + "\n");
  if (!Object.values(report.phaseControls).every((control) => control.passed) || report.results.some((result) => result.qualification.status === "blocked" || result.qualification.status === "failed")) process.exitCode = 1;
}
