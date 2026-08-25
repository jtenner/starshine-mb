import { describe, expect, test } from "bun:test";
import path from "node:path";

import { loadOptimizerSeedCorpus, parseOptimizerSeedRunArgs } from "./optimizer-seeds";

describe("optimizer seed corpus", () => {
  test("loads unique small checked-in seed entries", () => {
    const root = path.resolve(import.meta.dir, "..", "..", "tests", "optimizer", "seeds");
    const corpus = loadOptimizerSeedCorpus(root);
    expect(corpus.schema).toBe("starshine.optimizer-seed-corpus.v1");
    expect(corpus.seeds.length).toBeGreaterThanOrEqual(7);
    expect(new Set(corpus.seeds.map((seed) => seed.id)).size).toBe(corpus.seeds.length);
    expect(corpus.seeds.every((seed) => seed.surfaces.length > 0)).toBe(true);
  });

  test("parses direct replay options with stable pass order", () => {
    expect(
      parseOptimizerSeedRunArgs([
        "--pass",
        "vacuum",
        "--pass",
        "merge-blocks",
        "--self-semantic",
        "--debug-serial-passes",
      ]),
    ).toMatchObject({
      passFlags: ["--vacuum", "--merge-blocks"],
      selfSemantic: true,
      serialPasses: true,
    });
  });
});
