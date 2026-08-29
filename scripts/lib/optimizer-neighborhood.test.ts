import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { exploreOptimizerNeighborhood, exploreOptimizerWasmNeighborhood } from "./optimizer-neighborhood";

describe("reducer-guided neighborhood exploration", () => {
  test("emits deterministic valid typed variants and clusters fingerprints", async () => {
    const report = await exploreOptimizerNeighborhood({
      parentId: "failure-1", seed: 3n, budget: 4,
      base: { type: "i32" as const, op: "add", constant: 0, consumed: true, aliases: 0 },
      validate: async (variant) => variant.type === "i32",
      evaluate: async (variant) => ({ family: variant.constant === 0 ? "zero" : "boundary", exact: `${variant.op}:${variant.constant}:${variant.consumed}:${variant.aliases}` }),
      hash: (variant) => JSON.stringify(variant),
    });
    expect(report.schema).toBe("starshine.optimizer-neighborhood-family.v1");
    expect(report.variants.length).toBe(4);
    expect(report.variants.every((v) => v.validationStatus === "valid")).toBe(true);
    expect(report.clusters.length).toBeGreaterThan(1);
    expect(report.variants.map((v) => v.mutationId)).toEqual(expect.arrayContaining(["constant-boundary-neighbor", "toggle-consumed", "add-local-alias"]));
  });

  test("mutates whole Wasm modules with validation and exact-family replay clustering", async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "optimizer-neighborhood-test-"));
    const inputPath = path.join(root, "input.wasm");
    const outDir = path.join(root, "out");
    fs.writeFileSync(inputPath, Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]));
    const replayed: Array<[string, string]> = [];
    const report = await exploreOptimizerWasmNeighborhood({
      source: root,
      inputPath,
      outDir,
      seed: 9n,
      budget: 2,
      command: (_command, args) => {
        if (args[0] === "mutate") {
          const output = args[args.indexOf("--output") + 1];
          fs.writeFileSync(output, Buffer.from([0, 97, 115, 109, 1, 0, 0, Number(args[3]) & 0xff]));
        }
        return { ok: true, detail: "ok" };
      },
      replay: async (candidate, level) => {
        replayed.push([path.basename(candidate), level]);
        return { reproduced: level === "family" || candidate.endsWith("000001.wasm"), detail: level };
      },
    });
    expect(report.mutationEngine).toBe("wasm-tools-preserve-semantics");
    expect(report.variants.map((entry) => entry.fingerprintMatch)).toEqual(["exact", "family"]);
    expect(report.variants.every((entry) => entry.validationStatus === "valid")).toBe(true);
    expect(replayed).toEqual([
      ["neighbor-000001.wasm", "exact"],
      ["neighbor-000002.wasm", "exact"],
      ["neighbor-000002.wasm", "family"],
    ]);
    expect(fs.existsSync(path.join(outDir, "neighborhood.json"))).toBe(true);
  });
});
