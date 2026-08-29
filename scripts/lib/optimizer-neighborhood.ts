import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { replayOptimizerFailure } from "./optimizer-replay";

export type NeighborhoodExpression = { type: "i32" | "i64"; op: string; constant: number; consumed: boolean; aliases: number };
export type NeighborhoodVariant<Fingerprint> = { mutationId: string; mutationPath: string[]; moduleHash: string; validationStatus: "valid" | "invalid"; fingerprint: Fingerprint | null; newFamily: boolean };

function deterministicMutations(base: NeighborhoodExpression): Array<{ id: string; value: NeighborhoodExpression }> {
  const nearbyOp = base.op === "add" ? "sub" : "add";
  return [
    { id: "constant-boundary-neighbor", value: { ...base, constant: base.constant === 0 ? 1 : base.constant - 1 } },
    { id: "toggle-consumed", value: { ...base, consumed: !base.consumed } },
    { id: "add-local-alias", value: { ...base, aliases: base.aliases + 1 } },
    { id: "nearby-same-stack-opcode", value: { ...base, op: nearbyOp } },
    { id: "replace-runtime-operand", value: { ...base, constant: 0x7fffffff } },
  ];
}

export async function exploreOptimizerNeighborhood<Fingerprint extends { family: string; exact: string }>(options: { parentId: string; seed: bigint; budget: number; base: NeighborhoodExpression; validate(variant: NeighborhoodExpression): Promise<boolean>; evaluate(variant: NeighborhoodExpression): Promise<Fingerprint>; hash(variant: NeighborhoodExpression): string }) {
  const mutations = deterministicMutations(options.base);
  const start = Number(options.seed % BigInt(Math.max(1, mutations.length)));
  const ordered = mutations.slice(start).concat(mutations.slice(0, start));
  // Keep core high-value families represented even under small budgets.
  const selected = [...mutations.slice(0, Math.min(3, options.budget)), ...ordered.filter((entry) => !mutations.slice(0, 3).some((core) => core.id === entry.id))].slice(0, options.budget);
  const seenFamilies = new Set<string>();
  const variants: NeighborhoodVariant<Fingerprint>[] = [];
  for (const mutation of selected) {
    const valid = await options.validate(mutation.value);
    const fingerprint = valid ? await options.evaluate(mutation.value) : null;
    const family = fingerprint?.family ?? "invalid";
    const newFamily = valid && !seenFamilies.has(family);
    if (valid) seenFamilies.add(family);
    variants.push({ mutationId: mutation.id, mutationPath: [mutation.id], moduleHash: options.hash(mutation.value), validationStatus: valid ? "valid" : "invalid", fingerprint, newFamily });
  }
  const clusters = Array.from(seenFamilies).sort().map((family) => ({ family, variantIndexes: variants.map((entry, index) => entry.fingerprint?.family === family ? index : -1).filter((index) => index >= 0) }));
  return { schema: "starshine.optimizer-neighborhood-family.v1" as const, parentFailure: options.parentId, seed: `0x${options.seed.toString(16)}`, variants, clusters };
}

export type WasmNeighborhoodVariant = {
  mutationId: string;
  mutationPath: string[];
  moduleHash: string | null;
  outputPath: string;
  validationStatus: "valid" | "invalid" | "blocked";
  fingerprintMatch: "exact" | "family" | "none" | "blocked";
  detail: string;
  newFamily: boolean;
};

export type WasmNeighborhoodReport = {
  schema: "starshine.optimizer-neighborhood-family.v1";
  mutationEngine: "wasm-tools-preserve-semantics";
  parentFailure: string;
  seed: string;
  budget: number;
  variants: WasmNeighborhoodVariant[];
  clusters: Array<{ family: WasmNeighborhoodVariant["fingerprintMatch"]; variantIndexes: number[] }>;
};

type CommandResult = { ok: boolean; detail: string };

function defaultCommand(command: string, args: string[]): CommandResult {
  const result = spawnSync(command, args, { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (result.error) return { ok: false, detail: result.error.message };
  return {
    ok: result.status === 0,
    detail: result.stderr || result.stdout || `exit ${String(result.status)}`,
  };
}

function wasmHash(filePath: string): string | null {
  if (!fs.existsSync(filePath)) return null;
  return `sha256:${crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex")}`;
}

export async function exploreOptimizerWasmNeighborhood(options: {
  source: string;
  inputPath: string;
  outDir: string;
  seed: bigint;
  budget: number;
  wasmToolsBin?: string;
  starshineBin?: string;
  moonBin?: string;
  command?: (command: string, args: string[]) => CommandResult;
  replay?: (inputPath: string, level: "exact" | "family") => Promise<{ reproduced: boolean; detail: string }>;
}): Promise<WasmNeighborhoodReport> {
  if (!Number.isInteger(options.budget) || options.budget < 0) throw new Error("neighborhood budget must be non-negative");
  const inputPath = path.resolve(options.inputPath);
  if (!fs.existsSync(inputPath)) throw new Error(`missing optimizer neighborhood input ${inputPath}`);
  const outDir = path.resolve(options.outDir);
  fs.mkdirSync(outDir, { recursive: true });
  const wasmToolsBin = options.wasmToolsBin ?? process.env.WASM_TOOLS_BIN ?? "wasm-tools";
  const command = options.command ?? defaultCommand;
  const replay = options.replay ?? (async (candidatePath, level) => {
    const result = await replayOptimizerFailure({
      source: options.source,
      inputOverride: candidatePath,
      starshineBin: options.starshineBin,
      moonBin: options.moonBin,
      wasmToolsBin,
      fingerprintLevel: level,
    });
    return { reproduced: result.reproduced, detail: result.detail };
  });
  const variants: WasmNeighborhoodVariant[] = [];
  const seen = new Set<string>();
  for (let index = 0; index < options.budget; index += 1) {
    const mutationSeed = options.seed + BigInt(index);
    const outputPath = path.join(outDir, `neighbor-${String(index + 1).padStart(6, "0")}.wasm`);
    const mutationId = `wasm-tools-preserve-semantics:${mutationSeed.toString()}`;
    const mutated = command(wasmToolsBin, [
      "mutate",
      inputPath,
      "--seed",
      mutationSeed.toString(),
      "--preserve-semantics",
      "--output",
      outputPath,
    ]);
    if (!mutated.ok || !fs.existsSync(outputPath)) {
      variants.push({
        mutationId,
        mutationPath: ["module", "wasm-tools:preserve-semantics"],
        moduleHash: null,
        outputPath,
        validationStatus: "blocked",
        fingerprintMatch: "blocked",
        detail: mutated.detail,
        newFamily: !seen.has("blocked"),
      });
      seen.add("blocked");
      continue;
    }
    const validation = command(wasmToolsBin, ["validate", "--features", "all", outputPath]);
    if (!validation.ok) {
      variants.push({
        mutationId,
        mutationPath: ["module", "wasm-tools:preserve-semantics"],
        moduleHash: wasmHash(outputPath),
        outputPath,
        validationStatus: "invalid",
        fingerprintMatch: "none",
        detail: validation.detail,
        newFamily: !seen.has("invalid"),
      });
      seen.add("invalid");
      continue;
    }
    const exact = await replay(outputPath, "exact");
    let fingerprintMatch: WasmNeighborhoodVariant["fingerprintMatch"] = "none";
    let detail = exact.detail;
    if (exact.reproduced) {
      fingerprintMatch = "exact";
    } else {
      const family = await replay(outputPath, "family");
      detail = `${exact.detail}; family=${family.detail}`;
      if (family.reproduced) fingerprintMatch = "family";
    }
    const newFamily = !seen.has(fingerprintMatch);
    seen.add(fingerprintMatch);
    variants.push({
      mutationId,
      mutationPath: ["module", "wasm-tools:preserve-semantics"],
      moduleHash: wasmHash(outputPath),
      outputPath,
      validationStatus: "valid",
      fingerprintMatch,
      detail,
      newFamily,
    });
  }
  const clusterKinds: WasmNeighborhoodVariant["fingerprintMatch"][] = ["exact", "family", "none", "blocked"];
  const clusters = clusterKinds
    .map((family) => ({
      family,
      variantIndexes: variants.map((entry, index) => entry.fingerprintMatch === family ? index : -1).filter((index) => index >= 0),
    }))
    .filter((entry) => entry.variantIndexes.length > 0);
  const report: WasmNeighborhoodReport = {
    schema: "starshine.optimizer-neighborhood-family.v1",
    mutationEngine: "wasm-tools-preserve-semantics",
    parentFailure: path.resolve(options.source),
    seed: `0x${options.seed.toString(16)}`,
    budget: options.budget,
    variants,
    clusters,
  };
  fs.writeFileSync(path.join(outDir, "neighborhood.json"), JSON.stringify(report, null, 2) + "\n");
  return report;
}
