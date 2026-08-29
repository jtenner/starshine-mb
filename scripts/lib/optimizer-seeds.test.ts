import { describe, expect, test } from "bun:test";
import path from "node:path";

import { loadOptimizerSeedCorpus, parseOptimizerSeedRunArgs } from "./optimizer-seeds";

describe("optimizer seed corpus", () => {
  test("loads unique small checked-in seed entries", () => {
    const root = path.resolve(import.meta.dir, "..", "..", "tests", "optimizer", "seeds");
    const corpus = loadOptimizerSeedCorpus(root);
    expect(corpus.schema).toBe("starshine.optimizer-seed-corpus.v1");
    expect(corpus.seeds.length).toBeGreaterThanOrEqual(9);
    expect(new Set(corpus.seeds.map((seed) => seed.id)).size).toBe(corpus.seeds.length);
    expect(corpus.seeds.every((seed) => seed.surfaces.length > 0)).toBe(true);
    const surfaces = new Set(corpus.seeds.flatMap((seed) => seed.surfaces));
    for (const required of [
      "import-event",
      "start-function",
      "trap-frontier",
      "memory-beyond-64k",
      "imported-global",
      "imported-memory",
      "imported-table",
    ]) {
      expect(surfaces.has(required)).toBe(true);
    }
  });

  test("parses direct replay options with stable pass order", () => {
    expect(
      parseOptimizerSeedRunArgs([
        "--pass",
        "vacuum",
        "--pass",
        "merge-blocks",
        "--self-semantic",
        "--semantic-oracle", "node-v2",
        "--observation-mode", "stateful",
        "--debug-serial-passes",
      ]),
    ).toMatchObject({
      passFlags: ["--vacuum", "--merge-blocks"],
      selfSemantic: true,
      semanticOracle: "node-v2",
      observationMode: "stateful",
      serialPasses: true,
    });
  });
});
