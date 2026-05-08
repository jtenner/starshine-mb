import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import readline from "node:readline";

import { fail, resolveMoonBin, resolveRepoPath, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

type StarshineInvocation = {
  command: string;
  argsPrefix: string[];
};

type SelfOptimizeCompareOptions = {
  inputPath: string;
  outDir: string;
  moonBin: string;
  starshineBin: string | null;
  wasmOptBin: string;
  wasmToolsBin: string;
  binaryenNopRoundtrips: number;
  binaryenNopUntilStableMaxRoundtrips: number | null;
  requireBinaryenNopConverged: boolean;
  passFlags: string[];
};

type ComparisonSummary = {
  inputPath: string;
  effectiveInputPath: string;
  outDir: string;
  passFlags: string[];
  binaryenPassFlags: string[];
  binaryenNopRoundtrips: number;
  binaryenNopConverged: boolean | null;
  binaryenNopUntilStableMaxRoundtrips: number | null;
  starshineCommand: string[];
  binaryenCommand: string[];
  starshineSize: number;
  binaryenSize: number;
  wasmEqual: boolean;
  starshineElapsedMs: number;
  binaryenElapsedMs: number;
  starshineAtLeastAsFast: boolean;
  starshinePassElapsedMs: number;
  starshinePassSkippedRaw: boolean;
  binaryenPassElapsedMs: number;
  starshinePassAtLeastAsFast: boolean;
  normalizedWatTextEqual: boolean;
  canonicalFuncPrettyEqual: boolean | null;
  normalizedWatEqual: boolean;
  firstDifferingFuncDefinedIndex: number | null;
  firstDifferingFuncAbsIndex: number | null;
};

type DefinedFuncChunk = {
  definedIndex: number;
  text: string;
};

type SplitDefinedFuncs = {
  importFuncCount: number;
  funcs: DefinedFuncChunk[];
};

type CanonicalFuncCompareResult = {
  equal: boolean;
  firstDiffDefinedIndex: number | null;
  firstDiffAbsIndex: number | null;
  starshineFuncText: string | null;
  binaryenFuncText: string | null;
  starshinePretty: string | null;
  binaryenPretty: string | null;
};

const RESERVED_OPTIONS = new Set([
  "--out-dir",
  "--starshine-bin",
  "--wasm-opt-bin",
  "--wasm-tools-bin",
  "--moon",
  "--binaryen-nop-roundtrips",
  "--binaryen-nop-until-stable",
  "--require-binaryen-nop-converged",
]);

const BINARYEN_FLAG_ALIASES = new Map<string, string>([
  ["--dead-code-elimination", "--dce"],
  ["--dead-argument-elimination", "--dae"],
  ["--dead-argument-elimination-optimizing", "--dae-optimizing"],
  ["--global-struct-inference", "--gsi"],
  ["--redundant-set-elimination", "--rse"],
  ["--simplify-locals-no-structure", "--simplify-locals-nostructure"],
]);

const STARSHINE_FLAG_ALIASES = new Map<string, string>([
  ["--dae", "--dead-argument-elimination"],
  ["--dae-optimizing", "--dead-argument-elimination-optimizing"],
  ["--dce", "--dead-code-elimination"],
  ["--gsi", "--global-struct-inference"],
  ["--rse", "--redundant-set-elimination"],
  ["--simplify-locals-no-structure", "--simplify-locals-nostructure"],
]);

const UNSUPPORTED_PRESET_FLAGS = new Set(["--optimize", "--shrink"]);

// Build a deterministic temp directory name so multiple runs can run without
// clobbering each other (and still be easy to clean up).
function defaultOutDir(inputPath: string): string {
  const stem = path.basename(inputPath).replace(/\.[^.]+$/, "");
  return path.join(os.tmpdir(), `starshine-self-optimize-compare-${stem}-${process.pid}`);
}

function normalizeBinaryenPassFlag(flag: string): string {
  // Translate compatible Starshine-style flags to Binaryen CLI names; reject
  // preset-style options that would alter whole-tool behavior.
  if (UNSUPPORTED_PRESET_FLAGS.has(flag) || /^-O\d/.test(flag)) {
    fail(`unsupported preset flag for self-optimize compare: ${flag}`);
  }
  return BINARYEN_FLAG_ALIASES.get(flag) ?? flag;
}

function normalizeStarshinePassFlag(flag: string): string {
  if (UNSUPPORTED_PRESET_FLAGS.has(flag) || /^-O\d/.test(flag)) {
    fail(`unsupported preset flag for self-optimize compare: ${flag}`);
  }
  return STARSHINE_FLAG_ALIASES.get(flag) ?? flag;
}

function defaultBuiltStarshineBinPath(repoRoot: string): string {
  return path.join(repoRoot, "_build", "native", "release", "build", "cmd", "cmd.exe");
}

function resolveStarshineInvocation(
  repoRoot: string,
  starshineBin: string | null,
  moonBin: string,
): StarshineInvocation {
  if (starshineBin !== null) {
    return {
      command: resolveRepoPath(repoRoot, starshineBin),
      argsPrefix: [],
    };
  }
  const builtStarshineBin = defaultBuiltStarshineBinPath(repoRoot);
  if (fs.existsSync(builtStarshineBin)) {
    return {
      command: builtStarshineBin,
      argsPrefix: [],
    };
  }
  return {
    command: moonBin,
    argsPrefix: ["run", "--target", "native", "--release", "src/cmd", "--"],
  };
}

function ensureStarshineRawOutputExists(
  starshineRawOutputPath: string,
  starshineCommand: string[],
  stderr: string,
): void {
  if (fs.existsSync(starshineRawOutputPath)) {
    return;
  }
  const stderrNote = stderr.trim().length > 0
    ? `\nStderr:\n${stderr.trimEnd()}`
    : "";
  fail(
    `Starshine command reported success but did not create ${starshineRawOutputPath}\ncommand: ${starshineCommand.join(" ")}${stderrNote}`,
  );
}

function compileStarshineBeforeCompare(repoRoot: string, moonBin: string): void {
  runOrThrow(
    moonBin,
    ["build", "--target", "native", "--release", "--package", "jtenner/starshine/cmd"],
    { cwd: repoRoot, stdio: "pipe" },
  );
}

function printNormalizedWat(
  wasmOptBin: string,
  wasmPath: string,
  repoRoot: string,
  outPath: string,
): void {
  // Run wasm-opt in text mode and keep the canonicalized WAT on disk so very
  // large modules can be compared without forcing a full in-memory UTF-8 read.
  runOrThrow(
    wasmOptBin,
    [wasmPath, "--all-features", "--strip-debug", "-S", "-o", outPath],
    { cwd: repoRoot, stdio: "pipe" },
  );
}

function filesEqual(leftPath: string, rightPath: string): boolean {
  const leftSize = fs.statSync(leftPath).size;
  const rightSize = fs.statSync(rightPath).size;
  if (leftSize !== rightSize) {
    return false;
  }
  const chunkSize = 64 * 1024;
  const leftFd = fs.openSync(leftPath, "r");
  const rightFd = fs.openSync(rightPath, "r");
  const leftBuf = Buffer.allocUnsafe(chunkSize);
  const rightBuf = Buffer.allocUnsafe(chunkSize);
  try {
    let offset = 0;
    while (offset < leftSize) {
      const remaining = Math.min(chunkSize, leftSize - offset);
      const leftRead = fs.readSync(leftFd, leftBuf, 0, remaining, offset);
      const rightRead = fs.readSync(rightFd, rightBuf, 0, remaining, offset);
      if (leftRead !== rightRead) {
        return false;
      }
      if (!leftBuf.subarray(0, leftRead).equals(rightBuf.subarray(0, rightRead))) {
        return false;
      }
      offset += leftRead;
    }
    return true;
  } finally {
    fs.closeSync(leftFd);
    fs.closeSync(rightFd);
  }
}

function lineParenDelta(line: string): number {
  let delta = 0;
  let inString = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (inString) {
      if (ch === "\\") {
        i += 1;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }
    if (ch === ";" && line[i + 1] === ";") {
      break;
    }
    if (ch === "\"") {
      inString = true;
    } else if (ch === "(") {
      delta += 1;
    } else if (ch === ")") {
      delta -= 1;
    }
  }
  return delta;
}

async function splitDefinedFuncsFromFile(watPath: string): Promise<SplitDefinedFuncs> {
  const funcs: DefinedFuncChunk[] = [];
  let importFuncCount = 0;
  let depth = 0;
  let current: string[] | null = null;
  const stream = fs.createReadStream(watPath, { encoding: "utf8" });
  const lineReader = readline.createInterface({ input: stream, crlfDelay: Infinity });
  try {
    for await (const line of lineReader) {
      const atTopLevel = depth === 1;
      if (atTopLevel && line.startsWith(" (import ") && line.includes("(func ")) {
        importFuncCount += 1;
      }
      if (atTopLevel && line.startsWith(" (func ")) {
        current = [line];
      } else if (current !== null) {
        current.push(line);
      }
      depth += lineParenDelta(line);
      if (current !== null && depth === 1) {
        funcs.push({ definedIndex: funcs.length, text: current.join("\n") });
        current = null;
      }
    }
  } finally {
    lineReader.close();
    stream.close();
  }
  return { importFuncCount, funcs };
}

function canonicalizeBodyLocals(body: string): string {
  const localIds = new Map<number, number>();
  let nextLocal = 0;
  return body.replace(/\(Local (\d+)/g, (_match, rawId: string) => {
    const localId = Number(rawId);
    let canonical = localIds.get(localId);
    if (canonical === undefined) {
      canonical = nextLocal;
      nextLocal += 1;
      localIds.set(localId, canonical);
    }
    return `(Local ${canonical}`;
  });
}

function tokenLocalId(token: string): number | null {
  const match = token.match(/\(Local (\d+)/);
  return match ? Number(match[1]) : null;
}

function startsWithAt(text: string, start: number, prefix: string): boolean {
  return start >= 0 && text.slice(start, start + prefix.length) === prefix;
}

function reorderScalarLadders(body: string): string {
  const tokens: string[] = [];
  let i = 0;
  while (i < body.length) {
    const ch = body[i];
    if (ch === " " || ch === "\n" || ch === "\t") {
      i += 1;
      continue;
    }
    if (ch === "(") {
      const start = i;
      let depth = 0;
      while (i < body.length) {
        const inner = body[i];
        if (inner === "(") {
          depth += 1;
        } else if (inner === ")") {
          depth -= 1;
          if (depth === 0) {
            i += 1;
            break;
          }
        }
        i += 1;
      }
      tokens.push(body.slice(start, i));
      continue;
    }
    if (startsWithAt(body, i, "drop")) {
      tokens.push("drop");
      i += 4;
      continue;
    }
    i += 1;
  }

  let out = "";
  let tokenIdx = 0;
  while (tokenIdx < tokens.length) {
    if (
      tokenIdx + 8 < tokens.length &&
      tokens[tokenIdx].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 1].startsWith("(local.set (Local ") &&
      tokens[tokenIdx + 2].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 3].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 4].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 5].startsWith("(local.set (Local ") &&
      tokens[tokenIdx + 6].startsWith("(local.set (Local ") &&
      tokens[tokenIdx + 7].startsWith("(local.tee (Local ") &&
      tokens[tokenIdx + 8].startsWith("(local.set (Local ") &&
      tokenLocalId(tokens[tokenIdx + 1]) === tokenLocalId(tokens[tokenIdx + 3])
    ) {
      out += tokens[tokenIdx + 2];
      out += tokens[tokenIdx];
      out += tokens[tokenIdx + 4];
      out += tokens[tokenIdx + 5];
      out += tokens[tokenIdx + 6];
      out += tokens[tokenIdx + 7];
      out += tokens[tokenIdx + 8];
      tokenIdx += 9;
      continue;
    }
    if (
      tokenIdx + 6 < tokens.length &&
      tokens[tokenIdx].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 1].startsWith("(local.set (Local ") &&
      tokens[tokenIdx + 2].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 3].startsWith("(local.set (Local ") &&
      tokens[tokenIdx + 4].startsWith("(local.get (Local ") &&
      tokens[tokenIdx + 5].startsWith("(local.tee (Local ") &&
      tokens[tokenIdx + 6].startsWith("(local.set (Local ")
    ) {
      out += tokens[tokenIdx + 4];
      out += tokens[tokenIdx + 2];
      out += tokens[tokenIdx];
      out += tokens[tokenIdx + 1];
      out += tokens[tokenIdx + 3];
      out += tokens[tokenIdx + 5];
      out += tokens[tokenIdx + 6];
      tokenIdx += 7;
      continue;
    }
    out += tokens[tokenIdx];
    tokenIdx += 1;
  }
  return out;
}

function canonicalizeFuncPretty(pretty: string): string {
  const out: string[] = [];
  let inBody = false;
  for (const rawLine of pretty.replace(/\r\n/g, "\n").split("\n")) {
    const line = rawLine;
    const trimmedLine = line.trimStart();
    if (
      trimmedLine.startsWith("type_idx:") ||
      trimmedLine === "locals:" ||
      /^\[\d+\]/.test(trimmedLine)
    ) {
      continue;
    }
    let normalizedLine = line;
    if (line.startsWith("  body_raw:")) {
      inBody = true;
      normalizedLine =
        line.length === "  body_raw:".length
          ? line
          : "  body_raw:" +
            reorderScalarLadders(
              canonicalizeBodyLocals(line.slice("  body_raw:".length)),
            );
    } else if (inBody) {
      let indent = 0;
      while (indent < line.length && line[indent] === " ") {
        indent += 1;
      }
      normalizedLine =
        line.slice(0, indent) +
        reorderScalarLadders(canonicalizeBodyLocals(line.slice(indent)));
    }
    out.push(normalizedLine);
  }
  return out.join("\n");
}

function extractPrintedFuncPretty(stderr: string): string {
  const lines = stderr.replace(/\r\n/g, "\n").split("\n");
  if (lines.length >= 3 && lines[0].startsWith("Log: ")) {
    return lines.slice(2).join("\n").trimEnd();
  }
  return stderr.trimEnd();
}

function printCanonicalFuncPretty(
  starshineInvocation: StarshineInvocation,
  wasmPath: string,
  absFuncIndex: number,
  repoRoot: string,
): string {
  const printed = runOrThrow(
    starshineInvocation.command,
    [...starshineInvocation.argsPrefix, "--print-func", String(absFuncIndex), wasmPath],
    { cwd: repoRoot, stdio: "pipe" },
  );
  return canonicalizeFuncPretty(extractPrintedFuncPretty(printed.stderr));
}

async function compareNormalizedWatByCanonicalFuncs(
  starshineWatPath: string,
  binaryenWatPath: string,
  starshineInvocation: StarshineInvocation,
  starshineWasmPath: string,
  binaryenWasmPath: string,
  repoRoot: string,
): Promise<CanonicalFuncCompareResult> {
  const starshineSplit = await splitDefinedFuncsFromFile(starshineWatPath);
  const binaryenSplit = await splitDefinedFuncsFromFile(binaryenWatPath);
  if (starshineSplit.importFuncCount !== binaryenSplit.importFuncCount) {
    return {
      equal: false,
      firstDiffDefinedIndex: null,
      firstDiffAbsIndex: null,
      starshineFuncText: null,
      binaryenFuncText: null,
      starshinePretty: null,
      binaryenPretty: null,
    };
  }
  const maxFuncs = Math.max(starshineSplit.funcs.length, binaryenSplit.funcs.length);
  for (let definedIndex = 0; definedIndex < maxFuncs; definedIndex += 1) {
    const starshineFunc = starshineSplit.funcs[definedIndex];
    const binaryenFunc = binaryenSplit.funcs[definedIndex];
    if (!starshineFunc || !binaryenFunc) {
      return {
        equal: false,
        firstDiffDefinedIndex: definedIndex,
        firstDiffAbsIndex: starshineSplit.importFuncCount + definedIndex,
        starshineFuncText: starshineFunc?.text ?? null,
        binaryenFuncText: binaryenFunc?.text ?? null,
        starshinePretty: null,
        binaryenPretty: null,
      };
    }
    if (starshineFunc.text === binaryenFunc.text) {
      continue;
    }
    const absIndex = starshineSplit.importFuncCount + definedIndex;
    const starshinePretty = printCanonicalFuncPretty(
      starshineInvocation,
      starshineWasmPath,
      absIndex,
      repoRoot,
    );
    const binaryenPretty = printCanonicalFuncPretty(
      starshineInvocation,
      binaryenWasmPath,
      absIndex,
      repoRoot,
    );
    if (starshinePretty !== binaryenPretty) {
      return {
        equal: false,
        firstDiffDefinedIndex: definedIndex,
        firstDiffAbsIndex: absIndex,
        starshineFuncText: starshineFunc.text,
        binaryenFuncText: binaryenFunc.text,
        starshinePretty,
        binaryenPretty,
      };
    }
  }
  return {
    equal: true,
    firstDiffDefinedIndex: null,
    firstDiffAbsIndex: null,
    starshineFuncText: null,
    binaryenFuncText: null,
    starshinePretty: null,
    binaryenPretty: null,
  };
}

function canonicalizeWasm(
  wasmOptBin: string,
  inputPath: string,
  outputPath: string,
  repoRoot: string,
): void {
  // Canonicalize both outputs through the same strip-debug writer so raw
  // compare noise from names or non-canonical section ordering does not mask
  // actual pass correctness parity.
  runOrThrow(
    wasmOptBin,
    [inputPath, "--all-features", "--strip-debug", "-o", outputPath],
    { cwd: repoRoot, stdio: "pipe" },
  );
}

function runTimedOrThrow(
  command: string,
  args: string[],
  options: Parameters<typeof runOrThrow>[2],
): { stdout: string; stderr: string; elapsedMs: number } {
  const start = process.hrtime.bigint();
  const result = runOrThrow(command, args, options);
  const elapsedMs = Number(process.hrtime.bigint() - start) / 1_000_000;
  return { ...result, elapsedMs };
}

function parseStarshinePassElapsedMs(stderr: string): number {
  const matches = Array.from(stderr.matchAll(/perf:timer name=pass:[^\s]+ elapsed_us=(\d+)/g));
  if (matches.length !== 0) {
    return matches.reduce((sum, match) => sum + Number(match[1]), 0) / 1000;
  }
  if (starshinePassSkippedRaw(stderr)) {
    return 0;
  }
  fail("failed to parse Starshine pass timing from traced stderr");
}

function starshinePassSkippedRaw(stderr: string): boolean {
  return /pass\[[^\]]+\]:skip-raw\b/.test(stderr);
}

function parseBinaryenPassElapsedMs(stdout: string, stderr: string): number {
  const combined = `${stdout}\n${stderr}`;
  const matches = Array.from(combined.matchAll(/passes took ([0-9.eE+-]+) seconds\./g));
  const last = matches.at(-1);
  if (!last) {
    fail("failed to parse Binaryen pass timing from --debug output");
  }
  return Number(last[1]) * 1000;
}

function validateInputBaseline(
  wasmToolsBin: string,
  wasmOptBin: string,
  inputPath: string,
  acceptancePath: string,
  repoRoot: string,
): void {
  // Prefer Binaryen as the acceptance oracle for compare viability. Some
  // checked-in artifacts are rejected by wasm-tools validation but still round-
  // trip through wasm-opt, and those are still meaningful compare inputs for
  // this harness.
  try {
    runOrThrow(wasmToolsBin, ["validate", inputPath], {
      cwd: repoRoot,
      stdio: "pipe",
    });
    return;
  } catch (wasmToolsError) {
    try {
      runOrThrow(wasmOptBin, [inputPath, "--all-features", "-o", acceptancePath], {
        cwd: repoRoot,
        stdio: "pipe",
      });
      return;
    } catch (binaryenError) {
      const wasmToolsMessage = wasmToolsError instanceof Error
        ? wasmToolsError.message
        : String(wasmToolsError);
      const binaryenMessage = binaryenError instanceof Error
        ? binaryenError.message
        : String(binaryenError);
      fail(
        `input baseline is invalid and cannot be compared: ${inputPath}\n` +
        `wasm-tools rejected the baseline:\n${wasmToolsMessage}\n` +
        `Binaryen also rejected the baseline:\n${binaryenMessage}`,
      );
    }
  }
}

function parseNonNegativeIntegerOption(flag: string, raw: string | undefined): number {
  if (raw === undefined) {
    fail(`missing value for ${flag}`);
  }
  if (!/^\d+$/.test(raw)) {
    fail(`expected non-negative integer for ${flag}, got: ${raw}`);
  }
  return Number(raw);
}

function applyBinaryenNoPassRoundtrips(
  wasmOptBin: string,
  inputPath: string,
  outDir: string,
  roundtrips: number,
  repoRoot: string,
): {
  effectiveInputPath: string;
  commands: string[][];
  roundtripsApplied: number;
  converged: boolean | null;
  untilStableMaxRoundtrips: number | null;
} {
  if (roundtrips === 0) {
    return {
      effectiveInputPath: inputPath,
      commands: [],
      roundtripsApplied: 0,
      converged: null,
      untilStableMaxRoundtrips: null,
    };
  }
  let current = inputPath;
  const commands: string[][] = [];
  for (let round = 1; round <= roundtrips; round += 1) {
    const next = path.join(outDir, `binaryen.nop${round}.wasm`);
    const args = [current, "--all-features", "-o", next];
    runOrThrow(wasmOptBin, args, { cwd: repoRoot, stdio: "pipe" });
    commands.push([wasmOptBin, ...args]);
    current = next;
  }
  return {
    effectiveInputPath: current,
    commands,
    roundtripsApplied: roundtrips,
    converged: null,
    untilStableMaxRoundtrips: null,
  };
}

function applyBinaryenNoPassUntilStable(
  wasmOptBin: string,
  inputPath: string,
  outDir: string,
  maxRoundtrips: number,
  repoRoot: string,
): {
  effectiveInputPath: string;
  commands: string[][];
  roundtripsApplied: number;
  converged: boolean;
  untilStableMaxRoundtrips: number;
} {
  if (maxRoundtrips === 0) {
    return {
      effectiveInputPath: inputPath,
      commands: [],
      roundtripsApplied: 0,
      converged: true,
      untilStableMaxRoundtrips: 0,
    };
  }
  let current = inputPath;
  const commands: string[][] = [];
  for (let round = 1; round <= maxRoundtrips; round += 1) {
    const next = path.join(outDir, `binaryen.nop${round}.wasm`);
    const args = [current, "--all-features", "-o", next];
    runOrThrow(wasmOptBin, args, { cwd: repoRoot, stdio: "pipe" });
    commands.push([wasmOptBin, ...args]);
    const converged = fs.readFileSync(current).equals(fs.readFileSync(next));
    current = next;
    if (converged) {
      return {
        effectiveInputPath: current,
        commands,
        roundtripsApplied: round,
        converged: true,
        untilStableMaxRoundtrips: maxRoundtrips,
      };
    }
  }
  return {
    effectiveInputPath: current,
    commands,
    roundtripsApplied: maxRoundtrips,
    converged: false,
    untilStableMaxRoundtrips: maxRoundtrips,
  };
}

export function parseSelfOptimizeCompareArgs(argv: string[]): SelfOptimizeCompareOptions {
  let inputPath: string | null = null;
  let outDir: string | null = null;
  let moonBin = resolveMoonBin();
  let starshineBin: string | null = null;
  let wasmOptBin = process.env.WASM_OPT_BIN || "wasm-opt";
  let wasmToolsBin = process.env.WASM_TOOLS_BIN || "wasm-tools";
  let binaryenNopRoundtrips = 0;
  let binaryenNopUntilStableMaxRoundtrips: number | null = null;
  let requireBinaryenNopConverged = false;
  const passFlags: string[] = [];

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--out-dir":
        outDir = argv[i + 1] ?? fail("missing value for --out-dir");
        i += 2;
        break;
      case "--starshine-bin":
        starshineBin = argv[i + 1] ?? fail("missing value for --starshine-bin");
        i += 2;
        break;
      case "--wasm-opt-bin":
        wasmOptBin = argv[i + 1] ?? fail("missing value for --wasm-opt-bin");
        i += 2;
        break;
      case "--moon":
        moonBin = argv[i + 1] ?? fail("missing value for --moon");
        i += 2;
        break;
      case "--wasm-tools-bin":
        wasmToolsBin = argv[i + 1] ?? fail("missing value for --wasm-tools-bin");
        i += 2;
        break;
      case "--binaryen-nop-roundtrips":
        binaryenNopRoundtrips = parseNonNegativeIntegerOption(token, argv[i + 1]);
        i += 2;
        break;
      case "--binaryen-nop-until-stable":
        binaryenNopUntilStableMaxRoundtrips = parseNonNegativeIntegerOption(token, argv[i + 1]);
        i += 2;
        break;
      case "--require-binaryen-nop-converged":
        requireBinaryenNopConverged = true;
        i += 1;
        break;
      default:
        if (RESERVED_OPTIONS.has(token)) {
          fail(`missing value for ${token}`);
        }
        if (token.startsWith("--")) {
          passFlags.push(token);
          i += 1;
          break;
        }
        if (inputPath === null) {
          inputPath = token;
          i += 1;
          break;
        }
        fail(`unexpected positional argument: ${token}`);
    }
  }

  if (inputPath === null) {
    fail("usage: bun scripts/self-optimize-compare.ts <input.wasm> [options] [--pass ...]");
  }
  if (passFlags.length === 0) {
    fail("expected at least one pass flag to compare");
  }
  if (binaryenNopRoundtrips !== 0 && binaryenNopUntilStableMaxRoundtrips !== null) {
    fail("choose at most one of --binaryen-nop-roundtrips and --binaryen-nop-until-stable");
  }
  if (requireBinaryenNopConverged && binaryenNopUntilStableMaxRoundtrips === null) {
    fail("--require-binaryen-nop-converged requires --binaryen-nop-until-stable");
  }

  return {
    inputPath,
    outDir: outDir ?? defaultOutDir(inputPath),
    moonBin,
    starshineBin,
    wasmOptBin,
    wasmToolsBin,
    binaryenNopRoundtrips,
    binaryenNopUntilStableMaxRoundtrips,
    requireBinaryenNopConverged,
    passFlags,
  };
}

// Run Starshine and Binaryen side-by-side, normalize both outputs to WAT, and
// persist an explicit command/size summary for reproducibility.
export async function runSelfOptimizeCompare(argv: string[]): Promise<void> {
  const repoRoot = resolveWorkspaceRoot();
  const options = parseSelfOptimizeCompareArgs(argv);
  const inputPath = resolveRepoPath(repoRoot, options.inputPath);
  const outDir = resolveRepoPath(repoRoot, options.outDir);
  const starshineRawOutputPath = path.join(outDir, "starshine.raw.wasm");
  const binaryenRawOutputPath = path.join(outDir, "binaryen.raw.wasm");
  const starshineOutputPath = path.join(outDir, "starshine.wasm");
  const binaryenOutputPath = path.join(outDir, "binaryen.wasm");
  const starshineWatPath = path.join(outDir, "starshine.print.wat");
  const binaryenWatPath = path.join(outDir, "binaryen.print.wat");
  const summaryPath = path.join(outDir, "result.json");
  const commandsPath = path.join(outDir, "commands.txt");

  compileStarshineBeforeCompare(repoRoot, options.moonBin);

  if (!fs.existsSync(inputPath)) {
    fail(`input file not found: ${inputPath}`);
  }

  fs.mkdirSync(outDir, { recursive: true });
  validateInputBaseline(
    options.wasmToolsBin,
    options.wasmOptBin,
    inputPath,
    path.join(outDir, "binaryen.acceptance.wasm"),
    repoRoot,
  );
  const binaryenNopPrep = options.binaryenNopUntilStableMaxRoundtrips !== null
    ? applyBinaryenNoPassUntilStable(
        options.wasmOptBin,
        inputPath,
        outDir,
        options.binaryenNopUntilStableMaxRoundtrips,
        repoRoot,
      )
    : applyBinaryenNoPassRoundtrips(
        options.wasmOptBin,
        inputPath,
        outDir,
        options.binaryenNopRoundtrips,
        repoRoot,
      );
  const { effectiveInputPath, commands: binaryenNopCommands } = binaryenNopPrep;
  validateInputBaseline(
    options.wasmToolsBin,
    options.wasmOptBin,
    effectiveInputPath,
    path.join(outDir, "binaryen.acceptance.effective.wasm"),
    repoRoot,
  );
  if (options.requireBinaryenNopConverged && binaryenNopPrep.converged === false) {
    fail(
      `Binaryen no-pass writeback did not converge within ${binaryenNopPrep.untilStableMaxRoundtrips} roundtrips: ${effectiveInputPath}`,
    );
  }

  const binaryenPassFlags = options.passFlags.map(normalizeBinaryenPassFlag);
  const starshinePassFlags = options.passFlags.map(normalizeStarshinePassFlag);
  const starshineInvocation = resolveStarshineInvocation(
    repoRoot,
    options.starshineBin,
    options.moonBin,
  );
  const starshineArgs = [
    ...starshineInvocation.argsPrefix,
    ...starshinePassFlags,
    "--out",
    starshineRawOutputPath,
    effectiveInputPath,
  ];
  const binaryenArgs = [
    effectiveInputPath,
    "--all-features",
    ...binaryenPassFlags,
    "--debug",
    "-o",
    binaryenRawOutputPath,
  ];

  const starshineRun = runTimedOrThrow(starshineInvocation.command, starshineArgs, {
    cwd: repoRoot,
    env: {
      ...process.env,
      STARSHINE_TRACING: "pass",
    },
    stdio: "pipe",
  });
  const binaryenRun = runTimedOrThrow(options.wasmOptBin, binaryenArgs, {
    cwd: repoRoot,
    stdio: "pipe",
  });
  const starshinePassElapsedMs = parseStarshinePassElapsedMs(starshineRun.stderr);
  const starshinePassSkipped = starshinePassSkippedRaw(starshineRun.stderr);
  const binaryenPassElapsedMs = parseBinaryenPassElapsedMs(
    binaryenRun.stdout,
    binaryenRun.stderr,
  );

  ensureStarshineRawOutputExists(
    starshineRawOutputPath,
    [starshineInvocation.command, ...starshineArgs],
    starshineRun.stderr,
  );
  canonicalizeWasm(options.wasmOptBin, starshineRawOutputPath, starshineOutputPath, repoRoot);
  // Binaryen's direct output is the reference artifact we want to match; keep
  // it verbatim so the published compare pair answers "did Starshine reach the
  // Binaryen bytes?" instead of "did both survive another rewrite step?".
  fs.copyFileSync(binaryenRawOutputPath, binaryenOutputPath);

  printNormalizedWat(options.wasmOptBin, starshineOutputPath, repoRoot, starshineWatPath);
  printNormalizedWat(options.wasmOptBin, binaryenOutputPath, repoRoot, binaryenWatPath);
  const wasmEqual =
    fs.readFileSync(starshineOutputPath).equals(fs.readFileSync(binaryenOutputPath));
  const normalizedWatTextEqual = filesEqual(starshineWatPath, binaryenWatPath);
  const canonicalFuncCompare = normalizedWatTextEqual
    ? null
    : await compareNormalizedWatByCanonicalFuncs(
        starshineWatPath,
        binaryenWatPath,
        starshineInvocation,
        starshineOutputPath,
        binaryenOutputPath,
        repoRoot,
      );
  const normalizedWatEqual =
    normalizedWatTextEqual || canonicalFuncCompare?.equal === true;
  if (canonicalFuncCompare && !canonicalFuncCompare.equal) {
    const definedIndex = canonicalFuncCompare.firstDiffDefinedIndex;
    const absIndex = canonicalFuncCompare.firstDiffAbsIndex;
    if (definedIndex !== null && absIndex !== null) {
      const stem = `func-defined${definedIndex}-abs${absIndex}`;
      if (canonicalFuncCompare.starshineFuncText !== null) {
        fs.writeFileSync(
          path.join(outDir, `${stem}.starshine.wat`),
          canonicalFuncCompare.starshineFuncText + "\n",
        );
      }
      if (canonicalFuncCompare.binaryenFuncText !== null) {
        fs.writeFileSync(
          path.join(outDir, `${stem}.binaryen.wat`),
          canonicalFuncCompare.binaryenFuncText + "\n",
        );
      }
      if (canonicalFuncCompare.starshinePretty !== null) {
        fs.writeFileSync(
          path.join(outDir, `${stem}.starshine.pretty.txt`),
          canonicalFuncCompare.starshinePretty + "\n",
        );
      }
      if (canonicalFuncCompare.binaryenPretty !== null) {
        fs.writeFileSync(
          path.join(outDir, `${stem}.binaryen.pretty.txt`),
          canonicalFuncCompare.binaryenPretty + "\n",
        );
      }
    }
  }

  const summary: ComparisonSummary = {
    inputPath,
    effectiveInputPath,
    outDir,
    passFlags: options.passFlags,
    binaryenPassFlags,
    binaryenNopRoundtrips: binaryenNopPrep.roundtripsApplied,
    binaryenNopConverged: binaryenNopPrep.converged,
    binaryenNopUntilStableMaxRoundtrips: binaryenNopPrep.untilStableMaxRoundtrips,
    starshineCommand: [starshineInvocation.command, ...starshineArgs],
    binaryenCommand: [options.wasmOptBin, ...binaryenArgs],
    starshineSize: fs.statSync(starshineOutputPath).size,
    binaryenSize: fs.statSync(binaryenOutputPath).size,
    wasmEqual,
    starshineElapsedMs: starshineRun.elapsedMs,
    binaryenElapsedMs: binaryenRun.elapsedMs,
    starshineAtLeastAsFast: starshineRun.elapsedMs <= binaryenRun.elapsedMs,
    starshinePassElapsedMs,
    starshinePassSkippedRaw: starshinePassSkipped,
    binaryenPassElapsedMs,
    starshinePassAtLeastAsFast: starshinePassElapsedMs <= binaryenPassElapsedMs,
    normalizedWatTextEqual,
    canonicalFuncPrettyEqual: canonicalFuncCompare?.equal ?? null,
    normalizedWatEqual,
    firstDifferingFuncDefinedIndex: canonicalFuncCompare?.firstDiffDefinedIndex ?? null,
    firstDifferingFuncAbsIndex: canonicalFuncCompare?.firstDiffAbsIndex ?? null,
  };

  fs.writeFileSync(
    commandsPath,
    [
      ...binaryenNopCommands.map((command, index) => `binaryen-nop-${index + 1}: ${command.join(" ")}`),
      `starshine: ${summary.starshineCommand.join(" ")}`,
      `binaryen: ${summary.binaryenCommand.join(" ")}`,
    ].join("\n") + "\n",
  );
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2) + "\n");

  process.stdout.write(`Wrote comparison artifacts to ${outDir}\n`);
  process.stdout.write(`Starshine raw wasm: ${starshineRawOutputPath}\n`);
  process.stdout.write(`Binaryen raw wasm: ${binaryenRawOutputPath}\n`);
  process.stdout.write(`Starshine wasm: ${starshineOutputPath}\n`);
  process.stdout.write(`Binaryen wasm: ${binaryenOutputPath}\n`);
  process.stdout.write(`Binaryen no-pass roundtrips: ${summary.binaryenNopRoundtrips}\n`);
  if (summary.binaryenNopConverged !== null) {
    process.stdout.write(`Binaryen no-pass converged: ${summary.binaryenNopConverged ? "yes" : "no"}\n`);
  }
  if (summary.binaryenNopUntilStableMaxRoundtrips !== null) {
    process.stdout.write(
      `Binaryen no-pass until-stable max roundtrips: ${summary.binaryenNopUntilStableMaxRoundtrips}\n`,
    );
  }
  process.stdout.write(`Effective input wasm: ${summary.effectiveInputPath}\n`);
  process.stdout.write(`Starshine normalized WAT: ${starshineWatPath}\n`);
  process.stdout.write(`Binaryen normalized WAT: ${binaryenWatPath}\n`);
  process.stdout.write(`Canonical wasm equal: ${summary.wasmEqual ? "yes" : "no"}\n`);
  process.stdout.write(`Starshine runtime (ms): ${summary.starshineElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Binaryen runtime (ms): ${summary.binaryenElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Starshine at least as fast: ${summary.starshineAtLeastAsFast ? "yes" : "no"}\n`);
  process.stdout.write(`Starshine pass runtime (ms): ${summary.starshinePassElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Starshine pass skipped raw: ${summary.starshinePassSkippedRaw ? "yes" : "no"}\n`);
  process.stdout.write(`Binaryen pass runtime (ms): ${summary.binaryenPassElapsedMs.toFixed(3)}\n`);
  process.stdout.write(`Starshine pass at least as fast: ${summary.starshinePassAtLeastAsFast ? "yes" : "no"}\n`);
  process.stdout.write(`Normalized WAT text equal: ${summary.normalizedWatTextEqual ? "yes" : "no"}\n`);
  process.stdout.write(`Normalized WAT equal: ${summary.normalizedWatEqual ? "yes" : "no"}\n`);
  if (summary.canonicalFuncPrettyEqual !== null) {
    process.stdout.write(
      `Canonical function compare equal: ${summary.canonicalFuncPrettyEqual ? "yes" : "no"}\n`,
    );
  }
  if (summary.firstDifferingFuncDefinedIndex !== null && summary.firstDifferingFuncAbsIndex !== null) {
    process.stdout.write(
      `First differing function: defined=${summary.firstDifferingFuncDefinedIndex} abs=${summary.firstDifferingFuncAbsIndex}\n`,
    );
  }
}

export async function main(argv: string[]): Promise<void> {
  await runSelfOptimizeCompare(argv);
}
