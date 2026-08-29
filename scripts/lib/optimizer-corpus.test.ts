import { describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  promoteOptimizerFailure,
  stableOptimizerCaseJson,
  type OptimizerFailureReplayResult,
} from "./optimizer-corpus";

function fixture(options: {
  withReduced?: boolean;
  missingReduced?: boolean;
  failureClass?: string;
} = {}): { root: string; failureDir: string; corpusRoot: string } {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-optimizer-corpus-"));
  const failureDir = path.join(root, "failure");
  const corpusRoot = path.join(root, "tests", "optimizer", "regressions");
  fs.mkdirSync(failureDir, { recursive: true });
  fs.writeFileSync(path.join(failureDir, "input.wasm"), Uint8Array.from([0, 97, 115, 109, 1, 0, 0, 0]));
  if (options.withReduced && !options.missingReduced) {
    fs.writeFileSync(path.join(failureDir, "reduced-input.wasm"), Uint8Array.from([0, 97, 115, 109]));
  }
  fs.writeFileSync(
    path.join(failureDir, "failure-metadata.json"),
    JSON.stringify({
      caseIndex: 7,
      generator: "gen-valid",
      status: "property-failure",
      detail: "semantic:self mismatch",
      propertyFailureClass: options.failureClass ?? "semantic-self",
      genValidManifestEntry: {
        seed: "0x5eed",
        config_label: "pass-fuzz-stress",
        attempts: 2,
        feature_facts: { has_v128: false, has_gc: true },
      },
      reduction: options.withReduced
        ? { reducedWasm: "reduced-input.wasm", predicateEvaluations: 9, steps: [{ kind: "delete-byte-slice" }] }
        : null,
      replay: { input: "input.wasm", passFlags: ["--vacuum"] },
      propertyEvidence: {
        semanticPolicy: "trap-aware",
        serialPasses: true,
        observationMode: "stateful",
        observationMemoryCapBytes: 1048576,
        observationTableEntryCap: 1024,
        runtimeTimeoutMs: 1000,
        selfSemantic: {
          plan: { schema: "starshine.invocation-plan.v1", seed: "0x5eed", runtime: "node", steps: [] },
          before: { schema: "starshine.runtime-observation.v1" },
          after: { schema: "starshine.runtime-observation.v1" },
        },
        semanticV2: options.failureClass === "semantic-self-v2"
          ? {
              report: {
                schema: "starshine.optimizer-three-way-runtime-report.v1",
                runtimeInterface: { schema: "starshine.optimizer-runtime-interface.v1", interfaceHash: "iface" },
                plan: { schema: "starshine.optimizer-invocation-plan.v2", hash: "plan" },
                original: { schema: "starshine.optimizer-runtime-observation.v2" },
                starshine: { schema: "starshine.optimizer-runtime-observation.v2" },
                binaryen: { schema: "starshine.optimizer-runtime-observation.v2" },
                originalVsStarshine: { schema: "starshine.optimizer-semantic-comparison.v2", classification: "semantic-mismatch" },
                originalVsBinaryen: { schema: "starshine.optimizer-semantic-comparison.v2", classification: "semantic-match" },
                starshineVsBinaryen: { schema: "starshine.optimizer-semantic-comparison.v2", classification: "semantic-mismatch" },
                classification: { primary: "starshine-semantic-mismatch", pattern: "only-starshine-differs" },
              },
              fingerprint: {
                fingerprint: { schema: "starshine.optimizer-semantic-fingerprint.v1", propertyKind: "semantic-self-v2" },
                hash: "sha256:fingerprint",
              },
            }
          : null,
      },
    }, null, 2) + "\n",
  );
  return { root, failureDir, corpusRoot };
}

const verifiesSemanticSelf = async (): Promise<OptimizerFailureReplayResult> => ({
  reproduced: true,
  failureClass: "semantic-self",
  detail: "semantic mismatch reproduced",
});

describe("optimizer regression corpus promotion", () => {
  test("promotes a replayed reduced failure and writes deterministic manifest/index files", async () => {
    const { failureDir, corpusRoot } = fixture({ withReduced: true });

    const result = await promoteOptimizerFailure({ failureDir, corpusRoot, verifyFailure: verifiesSemanticSelf });

    expect(result.duplicate).toBe(false);
    expect(result.usedReducedArtifact).toBe(true);
    expect(fs.existsSync(path.join(result.casePath, "input.wasm"))).toBe(true);
    const manifest = JSON.parse(fs.readFileSync(path.join(result.casePath, "manifest.json"), "utf8"));
    expect(manifest.schema).toBe("starshine.optimizer-case.v1");
    expect(manifest.property.kind).toBe("semantic-self");
    expect(manifest.pipeline.passes).toEqual(["vacuum"]);
    expect(manifest.origin.profile).toBe("pass-fuzz-stress");
    expect(manifest.invocationPlan).toMatchObject({ schema: "starshine.invocation-plan.v1" });
    expect(JSON.parse(fs.readFileSync(path.join(corpusRoot, "index.json"), "utf8")).cases).toEqual([manifest.id]);
  });

  test("writes additive corpus v2 evidence for semantic-self-v2 failures", async () => {
    const { failureDir, corpusRoot } = fixture({ failureClass: "semantic-self-v2" });

    const result = await promoteOptimizerFailure({
      failureDir,
      corpusRoot,
      verifyFailure: async () => ({ reproduced: true, failureClass: "semantic-self-v2", detail: "v2 mismatch reproduced" }),
    });

    const manifest = JSON.parse(fs.readFileSync(path.join(result.casePath, "manifest.json"), "utf8"));
    expect(manifest.schema).toBe("starshine.optimizer-case.v2");
    expect(manifest.runtimeInterface).toMatchObject({ schema: "starshine.optimizer-runtime-interface.v1" });
    expect(manifest.invocationPlan).toMatchObject({ schema: "starshine.optimizer-invocation-plan.v2" });
    expect(manifest.observations.original).toMatchObject({ schema: "starshine.optimizer-runtime-observation.v2" });
    expect(manifest.observations.starshine).toMatchObject({ schema: "starshine.optimizer-runtime-observation.v2" });
    expect(manifest.semanticComparisons.originalVsStarshine).toMatchObject({ classification: "semantic-mismatch" });
    expect(manifest.fingerprint.hash).toBe("sha256:fingerprint");
    expect(manifest.property.observationMode).toBe("stateful");
  });

  test("duplicate promotion returns the existing case without creating a second entry", async () => {
    const { failureDir, corpusRoot } = fixture({ withReduced: true });
    const first = await promoteOptimizerFailure({ failureDir, corpusRoot, verifyFailure: verifiesSemanticSelf });
    const second = await promoteOptimizerFailure({ failureDir, corpusRoot, verifyFailure: verifiesSemanticSelf });

    expect(second.duplicate).toBe(true);
    expect(second.casePath).toBe(first.casePath);
    expect(fs.readdirSync(corpusRoot).filter((entry) => entry !== "index.json")).toHaveLength(1);
  });

  test("rejects malformed metadata", async () => {
    const { failureDir, corpusRoot } = fixture();
    fs.writeFileSync(path.join(failureDir, "failure-metadata.json"), "{}\n");

    await expect(promoteOptimizerFailure({ failureDir, corpusRoot, verifyFailure: verifiesSemanticSelf })).rejects.toThrow(
      "missing propertyFailureClass",
    );
  });

  test("rejects a replay that reproduces the wrong failure predicate", async () => {
    const { failureDir, corpusRoot } = fixture();

    await expect(
      promoteOptimizerFailure({
        failureDir,
        corpusRoot,
        verifyFailure: async () => ({ reproduced: true, failureClass: "validation-failure", detail: "became invalid" }),
      }),
    ).rejects.toThrow("wrong failure predicate");
  });

  test("falls back to the original artifact when reduced metadata points at a missing file", async () => {
    const { failureDir, corpusRoot } = fixture({ withReduced: true, missingReduced: true });

    const result = await promoteOptimizerFailure({ failureDir, corpusRoot, verifyFailure: verifiesSemanticSelf });

    expect(result.usedReducedArtifact).toBe(false);
    expect(fs.readFileSync(path.join(result.casePath, "input.wasm"))).toEqual(
      fs.readFileSync(path.join(failureDir, "input.wasm")),
    );
  });

  test("stable case serialization is independent of object insertion order", () => {
    const left = stableOptimizerCaseJson({ b: 2, a: { d: 4, c: 3 } });
    const right = stableOptimizerCaseJson({ a: { c: 3, d: 4 }, b: 2 });
    expect(left).toBe(right);
    expect(left).toBe('{"a":{"c":3,"d":4},"b":2}\n');
  });
});
